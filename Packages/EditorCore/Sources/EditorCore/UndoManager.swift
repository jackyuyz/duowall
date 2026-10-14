import Foundation

/// Manages undo/redo history for editor commands.
///
/// Maintains two stacks: undo and redo. When a command is executed,
/// its inverse is pushed to the undo stack and the redo stack is cleared.
public final class EditorUndoManager: @unchecked Sendable {
    /// Maximum number of undo steps to retain
    public let maxHistorySize: Int
    
    /// Undo stack (most recent at end)
    private var undoStack: [(command: any EditorCommand, inverse: any EditorCommand)] = []
    
    /// Redo stack (most recent at end)
    private var redoStack: [(command: any EditorCommand, inverse: any EditorCommand)] = []
    
    private let lock = NSLock()
    
    public init(maxHistorySize: Int = 50) {
        self.maxHistorySize = maxHistorySize
    }
    
    /// Whether undo is available
    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !undoStack.isEmpty
    }
    
    /// Whether redo is available
    public var canRedo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !redoStack.isEmpty
    }
    
    /// Description of the next undo action
    public var undoDescription: String? {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.last?.command.description
    }
    
    /// Description of the next redo action
    public var redoDescription: String? {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.last?.command.description
    }
    
    /// Number of available undo steps
    public var undoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return undoStack.count
    }
    
    /// Number of available redo steps
    public var redoCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return redoStack.count
    }
    
    /// Execute a command and record it for undo.
    ///
    /// - Parameters:
    ///   - command: The command to execute
    ///   - doc: The current document state
    /// - Returns: The new document state after applying the command
    public func execute(_ command: any EditorCommand, on doc: LayerDoc) -> LayerDoc {
        lock.lock()
        defer { lock.unlock() }
        
        let inverse = command.inverse(for: doc)
        let newDoc = command.apply(to: doc)
        
        undoStack.append((command: command, inverse: inverse))
        
        while undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        redoStack.removeAll()
        
        return newDoc
    }
    
    /// Undo the last command.
    ///
    /// - Parameter doc: The current document state
    /// - Returns: The document state after undoing, or nil if nothing to undo
    public func undo(on doc: LayerDoc) -> LayerDoc? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = undoStack.popLast() else {
            return nil
        }
        
        let newDoc = entry.inverse.apply(to: doc)
        
        let redoInverse = entry.inverse.inverse(for: doc)
        redoStack.append((command: entry.inverse, inverse: redoInverse))
        
        return newDoc
    }
    
    /// Redo the last undone command.
    ///
    /// - Parameter doc: The current document state
    /// - Returns: The document state after redoing, or nil if nothing to redo
    public func redo(on doc: LayerDoc) -> LayerDoc? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = redoStack.popLast() else {
            return nil
        }
        
        let newDoc = entry.inverse.apply(to: doc)
        
        let undoInverse = entry.inverse.inverse(for: doc)
        undoStack.append((command: entry.inverse, inverse: undoInverse))
        
        return newDoc
    }
    
    /// Clear all history
    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    /// Mark the current state as a save point.
    /// (For future use: track if document has unsaved changes)
    private var savePointIndex: Int?
    
    public func markSavePoint() {
        lock.lock()
        defer { lock.unlock() }
        savePointIndex = undoStack.count
    }
    
    /// Whether the document has changes since the last save point
    public var hasUnsavedChanges: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let savePoint = savePointIndex else {
            return !undoStack.isEmpty
        }
        return undoStack.count != savePoint
    }
}
