#!/usr/bin/env python3
"""
Generate iPhone Duo UI mockups for DuoWall app.
Creates PNG mockups for: inner unfolded, half-folded, and outer cover displays.
"""

from PIL import Image, ImageDraw, ImageFont
import os

INNER_WIDTH = 2670
INNER_HEIGHT = 1878

OUTER_WIDTH = 1398
OUTER_HEIGHT = 2034

CREASE_X = 0.5
CREASE_WIDTH_RATIO = 0.02

OUTER_CROP_WIDTH_RATIO = 0.4854
OUTER_CROP_X = 0.2573

BG_DARK = (26, 26, 46)
ACCENT_COLOR = (255, 153, 102)
GRID_COLOR = (60, 60, 80)
TEXT_COLOR = (255, 255, 255)
OVERLAY_COLOR = (100, 100, 120, 180)
CREASE_COLOR = (200, 200, 200, 100)
OUTER_FRAME_COLOR = (255, 153, 102)


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_grid(draw, width, height, spacing=100):
    for x in range(0, width, spacing):
        draw.line([(x, 0), (x, height)], fill=GRID_COLOR, width=1)
    for y in range(0, height, spacing):
        draw.line([(0, y), (width, y)], fill=GRID_COLOR, width=1)


def draw_safe_areas(draw, width, height, is_outer=False):
    if is_outer:
        clock_area = (int(width * 0.05), int(height * 0.08), 
                      int(width * 0.55), int(height * 0.23))
        draw_rounded_rect(draw, clock_area, radius=10, outline=(255, 255, 255, 100), width=2)
        draw.text((clock_area[0] + 10, clock_area[1] + 10), "Clock", fill=TEXT_COLOR)
        
        dock_area = (int(width * 0.85), int(height * 0.3),
                     int(width * 0.97), int(height * 0.7))
        draw_rounded_rect(draw, dock_area, radius=20, outline=(255, 255, 255, 100), width=2)
        draw.text((dock_area[0] + 5, dock_area[1] + 10), "Dock", fill=TEXT_COLOR)
        
        di_area = (int(width * 0.88), int(height * 0.02),
                   int(width * 0.96), int(height * 0.14))
        draw_rounded_rect(draw, di_area, radius=15, outline=(255, 255, 255, 100), width=2)
    else:
        camera_area = (int(width * 0.485), int(height * 0.02),
                       int(width * 0.515), int(height * 0.07))
        draw_rounded_rect(draw, camera_area, radius=10, outline=(0, 200, 255, 150), width=2)


def create_inner_unfolded_mockup():
    """Create mockup of the inner (unfolded) display showing the full editor."""
    img = Image.new('RGBA', (INNER_WIDTH, INNER_HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(img)
    
    draw_grid(draw, INNER_WIDTH, INNER_HEIGHT, spacing=150)
    
    crease_x = int(INNER_WIDTH * CREASE_X)
    crease_width = int(INNER_WIDTH * CREASE_WIDTH_RATIO)
    draw.rectangle([crease_x - crease_width//2, 0, crease_x + crease_width//2, INNER_HEIGHT],
                   fill=(80, 80, 100, 60))
    draw.line([(crease_x, 0), (crease_x, INNER_HEIGHT)], fill=(200, 200, 200), width=3)
    
    outer_crop_x = int(INNER_WIDTH * OUTER_CROP_X)
    outer_crop_width = int(INNER_WIDTH * OUTER_CROP_WIDTH_RATIO)
    draw_rounded_rect(draw, 
                      (outer_crop_x, 50, outer_crop_x + outer_crop_width, INNER_HEIGHT - 50),
                      radius=20, outline=OUTER_FRAME_COLOR, width=4)
    draw.text((outer_crop_x + 20, 70), "OUTER SCREEN AREA", fill=OUTER_FRAME_COLOR)
    
    gradient_rect = (200, 300, 1100, 1578)
    for y in range(gradient_rect[1], gradient_rect[3], 3):
        progress = (y - gradient_rect[1]) / (gradient_rect[3] - gradient_rect[1])
        r = int(100 + 100 * progress)
        g = int(50 + 100 * (1 - progress))
        b = int(150 - 50 * progress)
        draw.line([(gradient_rect[0], y), (gradient_rect[2], y)], fill=(r, g, b))
    
    draw.rectangle([200, 300, 1100, 1578], outline=(255, 255, 255, 100), width=2)
    draw.text((550, 900), "PHOTO", fill=TEXT_COLOR, anchor="mm")
    
    panel_x = INNER_WIDTH - 500
    draw.rectangle([panel_x, 100, INNER_WIDTH - 50, INNER_HEIGHT - 100], 
                   fill=(40, 40, 60))
    draw.text((panel_x + 20, 120), "TOOL PANEL", fill=TEXT_COLOR)
    
    draw.text((panel_x + 20, 200), "Overlays", fill=TEXT_COLOR)
    draw.rectangle([panel_x + 20, 240, panel_x + 180, 280], outline=ACCENT_COLOR, width=2)
    draw.text((panel_x + 30, 250), "Outer Frame", fill=TEXT_COLOR)
    draw.rectangle([panel_x + 20, 300, panel_x + 180, 340], outline=ACCENT_COLOR, width=2)
    draw.text((panel_x + 30, 310), "Safe Areas", fill=TEXT_COLOR)
    
    draw.text((panel_x + 20, 400), "Template", fill=TEXT_COLOR)
    for i, template in enumerate(["Reveal", "Panorama", "Split"]):
        btn_y = 450 + i * 60
        fill_color = ACCENT_COLOR if i == 0 else (60, 60, 80)
        draw.rounded_rectangle([panel_x + 20, btn_y, panel_x + 180, btn_y + 50],
                               radius=8, fill=fill_color)
        draw.text((panel_x + 100, btn_y + 25), template, fill=TEXT_COLOR, anchor="mm")
    
    draw.text((panel_x + 20, 680), "Layers", fill=TEXT_COLOR)
    for i, layer in enumerate(["Fill", "Photo"]):
        layer_y = 720 + i * 50
        draw.rectangle([panel_x + 20, layer_y, panel_x + 400, layer_y + 40],
                       fill=(50, 50, 70))
        draw.text((panel_x + 30, layer_y + 10), layer, fill=TEXT_COLOR)
    
    draw_safe_areas(draw, INNER_WIDTH, INNER_HEIGHT, is_outer=False)
    
    draw.rectangle([0, 0, INNER_WIDTH, 80], fill=(30, 30, 50))
    draw.text((100, 40), "Editor", fill=TEXT_COLOR, anchor="lm")
    draw.text((INNER_WIDTH - 100, 40), "Export", fill=ACCENT_COLOR, anchor="rm")
    
    draw.rectangle([50, INNER_HEIGHT - 60, 150, INNER_HEIGHT - 20], 
                   outline=TEXT_COLOR, width=2)
    draw.text((100, INNER_HEIGHT - 40), "Undo", fill=TEXT_COLOR, anchor="mm")
    draw.rectangle([170, INNER_HEIGHT - 60, 270, INNER_HEIGHT - 20], 
                   outline=TEXT_COLOR, width=2)
    draw.text((220, INNER_HEIGHT - 40), "Redo", fill=TEXT_COLOR, anchor="mm")
    
    return img


def create_half_folded_mockup():
    """Create mockup of half-folded state (laptop/tent posture)."""
    fold_angle = 120
    top_height = int(INNER_HEIGHT * 0.55)
    bottom_height = INNER_HEIGHT - top_height
    
    canvas_width = INNER_WIDTH
    canvas_height = int(INNER_HEIGHT * 1.3)
    
    img = Image.new('RGBA', (canvas_width, canvas_height), (20, 20, 30))
    draw = ImageDraw.Draw(img)
    
    top_panel = Image.new('RGBA', (INNER_WIDTH, top_height), BG_DARK)
    top_draw = ImageDraw.Draw(top_panel)
    draw_grid(top_draw, INNER_WIDTH, top_height, spacing=120)
    
    outer_crop_x = int(INNER_WIDTH * OUTER_CROP_X)
    outer_crop_width = int(INNER_WIDTH * OUTER_CROP_WIDTH_RATIO)
    draw_rounded_rect(top_draw,
                      (outer_crop_x, 30, outer_crop_x + outer_crop_width, top_height - 30),
                      radius=15, outline=OUTER_FRAME_COLOR, width=3)
    
    gradient_rect = (int(INNER_WIDTH * 0.1), int(top_height * 0.15),
                     int(INNER_WIDTH * 0.5), int(top_height * 0.85))
    for y in range(gradient_rect[1], gradient_rect[3], 3):
        progress = (y - gradient_rect[1]) / (gradient_rect[3] - gradient_rect[1])
        r = int(80 + 80 * progress)
        g = int(40 + 80 * (1 - progress))
        b = int(120 - 40 * progress)
        top_draw.line([(gradient_rect[0], y), (gradient_rect[2], y)], fill=(r, g, b))
    
    img.paste(top_panel, (0, 100))
    
    hinge_y = 100 + top_height
    draw.rectangle([0, hinge_y - 5, INNER_WIDTH, hinge_y + 5], fill=(100, 100, 120))
    draw.text((INNER_WIDTH // 2, hinge_y), "─── HINGE ───", fill=(150, 150, 170), anchor="mm")
    
    bottom_panel = Image.new('RGBA', (INNER_WIDTH, bottom_height), (35, 35, 55))
    bottom_draw = ImageDraw.Draw(bottom_panel)
    
    bottom_draw.text((50, 30), "TOOL PANEL (Bottom)", fill=TEXT_COLOR)
    
    for i, section in enumerate(["Overlays", "Template", "Layers"]):
        section_x = 50 + i * 400
        bottom_draw.text((section_x, 100), section, fill=TEXT_COLOR)
        bottom_draw.rectangle([section_x, 140, section_x + 350, 300],
                              fill=(45, 45, 65), outline=(70, 70, 90), width=2)
    
    img.paste(bottom_panel, (0, hinge_y + 10))
    
    draw.text((20, 20), "HALF-FOLDED (Laptop Mode)", fill=ACCENT_COLOR)
    draw.text((20, 50), f"Hinge Angle: ~{fold_angle}°", fill=(150, 150, 170))
    
    return img


def create_outer_cover_mockup():
    """Create mockup of the outer (cover) display."""
    img = Image.new('RGBA', (OUTER_WIDTH, OUTER_HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(img)
    
    draw_grid(draw, OUTER_WIDTH, OUTER_HEIGHT, spacing=100)
    
    gradient_rect = (100, 300, OUTER_WIDTH - 100, OUTER_HEIGHT - 300)
    for y in range(gradient_rect[1], gradient_rect[3], 3):
        progress = (y - gradient_rect[1]) / (gradient_rect[3] - gradient_rect[1])
        r = int(100 + 100 * progress)
        g = int(50 + 100 * (1 - progress))
        b = int(150 - 50 * progress)
        draw.line([(gradient_rect[0], y), (gradient_rect[2], y)], fill=(r, g, b))
    draw.rectangle(gradient_rect, outline=(255, 255, 255, 80), width=2)
    draw.text(((gradient_rect[0] + gradient_rect[2]) // 2, 
               (gradient_rect[1] + gradient_rect[3]) // 2),
              "WALLPAPER\n(Outer Crop)", fill=TEXT_COLOR, anchor="mm")
    
    draw_safe_areas(draw, OUTER_WIDTH, OUTER_HEIGHT, is_outer=True)
    
    draw.rounded_rectangle([OUTER_WIDTH - 60, 50, OUTER_WIDTH - 20, 250],
                           radius=15, outline=(200, 200, 200), width=2)
    draw.text((OUTER_WIDTH - 40, 150), "DI", fill=(150, 150, 170), anchor="mm")
    
    draw.text((50, OUTER_HEIGHT - 100), "CLOSED STATE", fill=ACCENT_COLOR)
    draw.text((50, OUTER_HEIGHT - 60), "Open phone to reveal full wallpaper", 
              fill=(150, 150, 170))
    
    return img


def create_gallery_mockup():
    """Create mockup of the gallery view."""
    img = Image.new('RGBA', (INNER_WIDTH, INNER_HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(img)
    
    draw.rectangle([0, 0, INNER_WIDTH, 100], fill=(30, 30, 50))
    draw.text((INNER_WIDTH // 2, 50), "DuoWall", fill=TEXT_COLOR, anchor="mm")
    draw.text((INNER_WIDTH - 80, 50), "⚙", fill=TEXT_COLOR, anchor="mm")
    
    card_width = 580
    card_height = 400
    padding = 40
    start_x = 100
    start_y = 150
    
    colors = [
        ((30, 100, 150), (100, 200, 255)),
        ((150, 50, 100), (255, 150, 200)),
        ((50, 150, 100), (150, 255, 200)),
        ((100, 80, 150), (200, 180, 255)),
        ((150, 100, 50), (255, 200, 150)),
        ((80, 80, 120), (180, 180, 220)),
        ((120, 50, 80), (220, 150, 180)),
        ((50, 120, 80), (150, 220, 180)),
    ]
    
    for i in range(8):
        col = i % 4
        row = i // 4
        x = start_x + col * (card_width + padding)
        y = start_y + row * (card_height + padding)
        
        c1, c2 = colors[i]
        for dy in range(card_height):
            progress = dy / card_height
            r = int(c1[0] + (c2[0] - c1[0]) * progress)
            g = int(c1[1] + (c2[1] - c1[1]) * progress)
            b = int(c1[2] + (c2[2] - c1[2]) * progress)
            draw.line([(x, y + dy), (x + card_width, y + dy)], fill=(r, g, b))
        
        draw.rounded_rectangle([x, y, x + card_width, y + card_height],
                               radius=20, outline=(255, 255, 255, 50), width=2)
        
        titles = ["Aurora", "Ocean", "Sunset", "Minimal", "Forest", "Night", "Desert", "Space"]
        draw.text((x + card_width // 2, y + card_height - 30), 
                  titles[i], fill=TEXT_COLOR, anchor="mm")
        
        if i >= 6:
            draw.rectangle([x + card_width - 80, y + 10, x + card_width - 10, y + 40],
                           fill=(0, 0, 0, 150))
            draw.text((x + card_width - 45, y + 25), "PRO", fill=ACCENT_COLOR, anchor="mm")
    
    draw.text((start_x, start_y - 30), "Free Collection", fill=TEXT_COLOR)
    draw.text((start_x, start_y + card_height + padding - 30), "Pro Collection", fill=TEXT_COLOR)
    
    crease_x = INNER_WIDTH // 2
    draw.line([(crease_x, 100), (crease_x, INNER_HEIGHT)], fill=(100, 100, 120, 80), width=2)
    
    return img


def main():
    output_dirs = [
        "/workspace/docs/ui/png",
        "/opt/cursor/artifacts"
    ]
    
    for dir_path in output_dirs:
        os.makedirs(dir_path, exist_ok=True)
    
    mockups = {
        "duowall-inner-unfolded.png": create_inner_unfolded_mockup(),
        "duowall-half-folded.png": create_half_folded_mockup(),
        "duowall-outer-cover.png": create_outer_cover_mockup(),
        "duowall-gallery.png": create_gallery_mockup(),
    }
    
    for filename, img in mockups.items():
        for dir_path in output_dirs:
            filepath = os.path.join(dir_path, filename)
            rgb_img = Image.new('RGB', img.size, (26, 26, 46))
            rgb_img.paste(img, mask=img.split()[3] if img.mode == 'RGBA' else None)
            rgb_img.save(filepath, 'PNG')
            print(f"Saved: {filepath}")
    
    print(f"\nGenerated {len(mockups)} mockups to {len(output_dirs)} locations")


if __name__ == "__main__":
    main()
