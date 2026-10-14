import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import DisplaySpecKit

/// A reversible editing command for undo/redo support.
///
/// Commands capture both the action to perform and the inverse action
/// to undo it. This enables a robust undo stack.
public protocol EditorCommand: Sendable {
    /// Human-readable description for the undo menu
    var description: String { get }
    
    /// Apply the command to a document, returning the modified document
    func apply(to doc: LayerDoc) -> LayerDoc
    
    /// Create the inverse command (for undo)
    func inverse(for doc: LayerDoc) -> any EditorCommand
}

// MARK: - Layer Commands

/// Add a layer to the document
public struct AddLayerCommand: EditorCommand {
    public let layer: Layer
    public let atIndex: Int?
    
    public var description: String { "Add \(layer.typeName)" }
    
    public init(layer: Layer, atIndex: Int? = nil) {
        self.layer = layer
        self.atIndex = atIndex
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        if let index = atIndex, index <= newDoc.layers.count {
            newDoc.layers.insert(layer, at: index)
        } else {
            newDoc.layers.append(layer)
        }
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        RemoveLayerCommand(layerId: layer.id)
    }
}

/// Remove a layer from the document
public struct RemoveLayerCommand: EditorCommand {
    public let layerId: UUID
    
    public var description: String { "Remove Layer" }
    
    public init(layerId: UUID) {
        self.layerId = layerId
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        newDoc.layers.removeAll { $0.id == layerId }
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        guard let layer = doc.layer(withId: layerId),
              let index = doc.layerIndex(withId: layerId) else {
            return NoOpCommand()
        }
        return AddLayerCommand(layer: layer, atIndex: index)
    }
}

/// Reorder a layer in the stack
public struct ReorderLayerCommand: EditorCommand {
    public let layerId: UUID
    public let toIndex: Int
    
    public var description: String { "Reorder Layer" }
    
    public init(layerId: UUID, toIndex: Int) {
        self.layerId = layerId
        self.toIndex = toIndex
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        guard let fromIndex = newDoc.layerIndex(withId: layerId) else {
            return doc
        }
        let layer = newDoc.layers.remove(at: fromIndex)
        let targetIndex = min(toIndex, newDoc.layers.count)
        newDoc.layers.insert(layer, at: targetIndex)
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        guard let originalIndex = doc.layerIndex(withId: layerId) else {
            return NoOpCommand()
        }
        return ReorderLayerCommand(layerId: layerId, toIndex: originalIndex)
    }
}

/// Update a layer's properties
public struct UpdateLayerCommand: EditorCommand {
    public let layerId: UUID
    public let newLayer: Layer
    
    public var description: String { "Update \(newLayer.typeName)" }
    
    public init(layerId: UUID, newLayer: Layer) {
        self.layerId = layerId
        self.newLayer = newLayer
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        guard let index = newDoc.layerIndex(withId: layerId) else {
            return doc
        }
        newDoc.layers[index] = newLayer
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        guard let originalLayer = doc.layer(withId: layerId) else {
            return NoOpCommand()
        }
        return UpdateLayerCommand(layerId: layerId, newLayer: originalLayer)
    }
}

// MARK: - Transform Commands

/// Transform a photo layer
public struct TransformLayerCommand: EditorCommand {
    public let layerId: UUID
    public let newTransform: LayerTransform
    
    public var description: String { "Transform Layer" }
    
    public init(layerId: UUID, newTransform: LayerTransform) {
        self.layerId = layerId
        self.newTransform = newTransform
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        guard let index = newDoc.layerIndex(withId: layerId) else {
            return doc
        }
        
        switch newDoc.layers[index] {
        case .photo(var photo):
            photo.transform = newTransform
            newDoc.layers[index] = .photo(photo)
        case .text(var text):
            text.transform = newTransform
            newDoc.layers[index] = .text(text)
        default:
            return doc
        }
        
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        guard let layer = doc.layer(withId: layerId) else {
            return NoOpCommand()
        }
        
        let oldTransform: LayerTransform
        switch layer {
        case .photo(let photo):
            oldTransform = photo.transform
        case .text(let text):
            oldTransform = text.transform
        default:
            return NoOpCommand()
        }
        
        return TransformLayerCommand(layerId: layerId, newTransform: oldTransform)
    }
}

// MARK: - Document Commands

/// Change the template
public struct ChangeTemplateCommand: EditorCommand {
    public let newTemplate: TemplateKind
    
    public var description: String { "Change Template" }
    
    public init(newTemplate: TemplateKind) {
        self.newTemplate = newTemplate
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        newDoc.template = newTemplate
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        ChangeTemplateCommand(newTemplate: doc.template)
    }
}

/// Set custom outer crop
public struct SetOuterCropCommand: EditorCommand {
    public let newCrop: NormalizedRect?
    
    public var description: String { "Set Outer Crop" }
    
    public init(newCrop: NormalizedRect?) {
        self.newCrop = newCrop
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var newDoc = doc
        newDoc.outerCrop = newCrop
        newDoc.modifiedAt = .now
        return newDoc
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        SetOuterCropCommand(newCrop: doc.outerCrop)
    }
}

// MARK: - Compound Commands

/// A command that groups multiple commands
public struct CompoundCommand: EditorCommand {
    public let commands: [any EditorCommand]
    public let description: String
    
    public init(description: String, commands: [any EditorCommand]) {
        self.description = description
        self.commands = commands
    }
    
    public func apply(to doc: LayerDoc) -> LayerDoc {
        var result = doc
        for command in commands {
            result = command.apply(to: result)
        }
        return result
    }
    
    public func inverse(for doc: LayerDoc) -> any EditorCommand {
        var inverses: [any EditorCommand] = []
        var currentDoc = doc
        
        for command in commands {
            inverses.insert(command.inverse(for: currentDoc), at: 0)
            currentDoc = command.apply(to: currentDoc)
        }
        
        return CompoundCommand(description: "Undo \(description)", commands: inverses)
    }
}

/// A no-op command (for edge cases)
public struct NoOpCommand: EditorCommand {
    public var description: String { "No Change" }
    
    public init() {}
    
    public func apply(to doc: LayerDoc) -> LayerDoc { doc }
    public func inverse(for doc: LayerDoc) -> any EditorCommand { NoOpCommand() }
}
