#!/usr/bin/env python3
"""
Generate bundled wallpaper images for DuoWall.
Creates 30 unique wallpaper images (10 free + 20 premium) at 2670x1878 pixels.
Outputs PNG files that can be converted to HEIC on macOS.
"""

from PIL import Image, ImageDraw
import os
import math
import colorsys

# Inner display dimensions
INNER_WIDTH = 2670
INNER_HEIGHT = 1878

OUTPUT_DIR = "/workspace/App/Resources/Packs/main"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def hsv_to_rgb(h, s, v):
    """Convert HSV to RGB (0-255 range)."""
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255))

def draw_gradient(img, color1, color2, vertical=True):
    """Draw a gradient on the image."""
    draw = ImageDraw.Draw(img)
    w, h = img.size
    
    if vertical:
        for y in range(h):
            progress = y / max(1, h - 1)
            r = int(color1[0] + (color2[0] - color1[0]) * progress)
            g = int(color1[1] + (color2[1] - color1[1]) * progress)
            b = int(color1[2] + (color2[2] - color1[2]) * progress)
            draw.line([(0, y), (w, y)], fill=(r, g, b))
    else:
        for x in range(w):
            progress = x / max(1, w - 1)
            r = int(color1[0] + (color2[0] - color1[0]) * progress)
            g = int(color1[1] + (color2[1] - color1[1]) * progress)
            b = int(color1[2] + (color2[2] - color1[2]) * progress)
            draw.line([(x, 0), (x, h)], fill=(r, g, b))
    
    return img

def create_aurora_wallpaper():
    """Aurora borealis style wallpaper."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT), (26, 26, 46))
    draw = ImageDraw.Draw(img)
    
    # Dark to medium blue gradient base
    draw_gradient(img, (15, 20, 45), (25, 35, 65))
    
    # Aurora waves
    for i in range(8):
        wave_y = INNER_HEIGHT * (0.2 + i * 0.08)
        color = (
            40 + i * 25,
            120 + i * 15,
            80 + i * 20
        )
        for x in range(0, INNER_WIDTH, 3):
            offset = int(math.sin(x * 0.003 + i * 0.5) * 80 + math.sin(x * 0.007) * 40)
            thickness = 15 + i * 3
            alpha_factor = 0.3 + 0.1 * i
            for t in range(thickness):
                y = int(wave_y + offset + t)
                if 0 <= y < INNER_HEIGHT:
                    draw.point((x, y), fill=color)
    
    # Mountain silhouettes
    for y in range(int(INNER_HEIGHT * 0.7), INNER_HEIGHT):
        darkness = 1 - (y - INNER_HEIGHT * 0.7) / (INNER_HEIGHT * 0.3)
        color = (int(20 * darkness), int(25 * darkness), int(40 * darkness))
        for x in range(INNER_WIDTH):
            peak_height = INNER_HEIGHT * 0.7 + abs(math.sin(x * 0.002) * 150 + math.sin(x * 0.005) * 100)
            if y > peak_height:
                draw.point((x, y), fill=color)
    
    return img

def create_ocean_depths_wallpaper():
    """Deep ocean style wallpaper."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT), (10, 22, 40))
    draw_gradient(img, (10, 22, 40), (42, 97, 135))
    draw = ImageDraw.Draw(img)
    
    # Light rays from above
    for i in range(10):
        ray_x = INNER_WIDTH * (0.1 + i * 0.08)
        ray_width = 40 + i * 10
        for y in range(int(INNER_HEIGHT * 0.8)):
            alpha = (1 - y / (INNER_HEIGHT * 0.8)) * 0.15
            spread = y * 0.15
            for dx in range(int(-ray_width - spread), int(ray_width + spread)):
                x = int(ray_x + dx)
                if 0 <= x < INNER_WIDTH:
                    brightness = int(255 * alpha * (1 - abs(dx) / (ray_width + spread)))
                    if brightness > 0:
                        orig = img.getpixel((x, y))
                        new_color = (
                            min(255, orig[0] + brightness // 4),
                            min(255, orig[1] + brightness // 3),
                            min(255, orig[2] + brightness // 2)
                        )
                        draw.point((x, y), fill=new_color)
    
    return img

def create_sunset_gradient_wallpaper():
    """Warm sunset gradient."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT))
    draw = ImageDraw.Draw(img)
    
    colors = [
        (255, 89, 94),    # Coral red
        (255, 146, 76),   # Orange
        (255, 195, 113),  # Golden
        (255, 221, 161),  # Light gold
        (255, 248, 230),  # Cream
    ]
    
    segment_height = INNER_HEIGHT / (len(colors) - 1)
    
    for y in range(INNER_HEIGHT):
        segment = min(int(y / segment_height), len(colors) - 2)
        progress = (y - segment * segment_height) / segment_height
        c1, c2 = colors[segment], colors[segment + 1]
        r = int(c1[0] + (c2[0] - c1[0]) * progress)
        g = int(c1[1] + (c2[1] - c1[1]) * progress)
        b = int(c1[2] + (c2[2] - c1[2]) * progress)
        draw.line([(0, y), (INNER_WIDTH, y)], fill=(r, g, b))
    
    return img

def create_minimal_geo_wallpaper():
    """Minimal geometric pattern."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT), (248, 249, 250))
    draw = ImageDraw.Draw(img)
    
    # Subtle geometric shapes
    colors = [(52, 58, 64), (108, 117, 125), (173, 181, 189)]
    
    for i in range(15):
        x = (i * 200 + 100) % INNER_WIDTH
        y = (i * 150 + 50) % INNER_HEIGHT
        size = 80 + (i * 17) % 120
        color = colors[i % len(colors)]
        
        if i % 3 == 0:
            draw.rectangle([x, y, x + size, y + size], outline=color, width=3)
        elif i % 3 == 1:
            draw.ellipse([x, y, x + size, y + size], outline=color, width=3)
        else:
            points = [(x + size//2, y), (x + size, y + size), (x, y + size)]
            draw.polygon(points, outline=color, width=3)
    
    return img

def create_forest_mist_wallpaper():
    """Misty forest layers."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT))
    draw_gradient(img, (45, 74, 62), (149, 196, 168))
    draw = ImageDraw.Draw(img)
    
    # Layered tree silhouettes
    layers = [
        (0.9, (30, 50, 40)),
        (0.75, (40, 65, 52)),
        (0.6, (55, 85, 68)),
        (0.45, (75, 110, 88)),
    ]
    
    for start_y_frac, color in layers:
        start_y = int(INNER_HEIGHT * start_y_frac)
        for x in range(0, INNER_WIDTH, 2):
            tree_top = start_y - int(abs(math.sin(x * 0.01) * 100 + math.sin(x * 0.003) * 150))
            for y in range(tree_top, INNER_HEIGHT):
                if y >= 0:
                    draw.point((x, y), fill=color)
                    if x + 1 < INNER_WIDTH:
                        draw.point((x + 1, y), fill=color)
    
    return img

def create_night_city_wallpaper():
    """City skyline at night (panorama style)."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT))
    draw_gradient(img, (13, 27, 42), (65, 90, 119))
    draw = ImageDraw.Draw(img)
    
    # Skyline
    building_heights = []
    x = 0
    while x < INNER_WIDTH:
        width = 40 + (hash(str(x)) % 80)
        height = 200 + (hash(str(x * 7)) % 400)
        building_heights.append((x, width, height))
        x += width + 5
    
    for bx, bw, bh in building_heights:
        by = INNER_HEIGHT - bh
        draw.rectangle([bx, by, bx + bw, INNER_HEIGHT], fill=(27, 38, 59))
        
        # Windows
        for wy in range(by + 10, INNER_HEIGHT - 10, 25):
            for wx in range(bx + 5, bx + bw - 5, 15):
                if hash(f"{wx}{wy}") % 3 != 0:
                    brightness = 150 + hash(f"{wx}{wy}") % 105
                    draw.rectangle([wx, wy, wx + 8, wy + 15], 
                                   fill=(brightness, brightness - 30, brightness - 60))
    
    return img

def create_desert_dunes_wallpaper():
    """Golden desert dunes."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT))
    draw_gradient(img, (212, 165, 116), (139, 99, 57))
    draw = ImageDraw.Draw(img)
    
    # Dune waves
    for layer in range(5):
        start_y = INNER_HEIGHT * (0.3 + layer * 0.15)
        shade = 0.9 - layer * 0.1
        color = (
            int(196 * shade),
            int(149 * shade),
            int(82 * shade)
        )
        
        for x in range(INNER_WIDTH):
            dune_y = start_y + math.sin(x * 0.003 + layer) * 80 + math.sin(x * 0.008) * 40
            for y in range(int(dune_y), INNER_HEIGHT):
                if 0 <= y < INNER_HEIGHT:
                    draw.point((x, y), fill=color)
    
    return img

def create_space_nebula_wallpaper():
    """Colorful space nebula."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT), (26, 26, 46))
    draw = ImageDraw.Draw(img)
    
    # Nebula clouds
    for i in range(500):
        cx = hash(f"x{i}") % INNER_WIDTH
        cy = hash(f"y{i}") % INNER_HEIGHT
        radius = 50 + hash(f"r{i}") % 200
        
        hue = (hash(f"h{i}") % 100) / 100 * 0.2 + 0.75  # Purple-blue range
        
        for r in range(radius, 0, -5):
            alpha = (1 - r / radius) * 0.05
            color = hsv_to_rgb(hue, 0.7, 0.3 + alpha)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    
    # Stars
    for i in range(200):
        sx = hash(f"sx{i}") % INNER_WIDTH
        sy = hash(f"sy{i}") % INNER_HEIGHT
        brightness = 150 + hash(f"sb{i}") % 105
        draw.point((sx, sy), fill=(brightness, brightness, brightness))
    
    return img

def create_cherry_blossom_wallpaper():
    """Cherry blossom branches."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT))
    draw_gradient(img, (255, 202, 212), (109, 104, 117))
    draw = ImageDraw.Draw(img)
    
    # Branches
    branch_color = (77, 63, 63)
    for i in range(5):
        bx = INNER_WIDTH * (0.1 + i * 0.2)
        by = INNER_HEIGHT * 0.9
        for seg in range(20):
            angle = -1.2 + math.sin(seg * 0.3) * 0.4
            length = 60 - seg * 2
            ex = bx + math.cos(angle) * length
            ey = by + math.sin(angle) * length
            draw.line([(bx, by), (ex, ey)], fill=branch_color, width=max(1, 8 - seg // 3))
            bx, by = ex, ey
    
    # Blossoms
    petal_colors = [(255, 183, 197), (255, 192, 203), (255, 209, 220)]
    for i in range(150):
        px = hash(f"px{i}") % INNER_WIDTH
        py = hash(f"py{i}") % (INNER_HEIGHT - 200) + 100
        size = 10 + hash(f"ps{i}") % 20
        color = petal_colors[i % len(petal_colors)]
        draw.ellipse([px - size, py - size, px + size, py + size], fill=color)
    
    return img

def create_abstract_waves_wallpaper():
    """Abstract wave pattern."""
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT), (43, 45, 66))
    draw = ImageDraw.Draw(img)
    
    colors = [(141, 153, 174), (237, 242, 244), (239, 35, 60)]
    
    for wave_idx, color in enumerate(colors):
        base_y = INNER_HEIGHT * (0.4 + wave_idx * 0.15)
        for x in range(INNER_WIDTH):
            y = base_y + math.sin(x * 0.005 + wave_idx) * 100 + math.sin(x * 0.012) * 50
            thickness = 30 - wave_idx * 5
            for t in range(-thickness, thickness):
                py = int(y + t)
                if 0 <= py < INNER_HEIGHT:
                    draw.point((x, py), fill=color)
    
    return img

def create_premium_wallpaper(index):
    """Create a unique premium wallpaper based on index."""
    hue_base = (index * 37) % 360 / 360
    
    img = Image.new('RGB', (INNER_WIDTH, INNER_HEIGHT))
    
    # Create unique gradient based on index
    color1 = hsv_to_rgb(hue_base, 0.7, 0.3)
    color2 = hsv_to_rgb((hue_base + 0.1) % 1, 0.5, 0.5)
    draw_gradient(img, color1, color2)
    
    draw = ImageDraw.Draw(img)
    
    # Add unique patterns based on index
    pattern_type = index % 4
    
    if pattern_type == 0:  # Circles
        for i in range(20):
            cx = (index * 137 + i * 200) % INNER_WIDTH
            cy = (index * 89 + i * 150) % INNER_HEIGHT
            r = 50 + (index * 17 + i * 23) % 150
            color = hsv_to_rgb((hue_base + 0.3) % 1, 0.6, 0.7)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=3)
    
    elif pattern_type == 1:  # Lines
        for i in range(15):
            x1 = (index * 97 + i * 180) % INNER_WIDTH
            y1 = 0
            x2 = (x1 + 200) % INNER_WIDTH
            y2 = INNER_HEIGHT
            color = hsv_to_rgb((hue_base + 0.2) % 1, 0.5, 0.8)
            draw.line([(x1, y1), (x2, y2)], fill=color, width=5)
    
    elif pattern_type == 2:  # Rectangles
        for i in range(12):
            x = (index * 113 + i * 220) % INNER_WIDTH
            y = (index * 71 + i * 160) % INNER_HEIGHT
            w = 100 + (index * 19 + i * 31) % 200
            h = 80 + (index * 23 + i * 29) % 150
            color = hsv_to_rgb((hue_base + 0.4) % 1, 0.4, 0.6)
            draw.rectangle([x, y, x + w, y + h], outline=color, width=4)
    
    else:  # Triangles
        for i in range(10):
            cx = (index * 127 + i * 260) % INNER_WIDTH
            cy = (index * 83 + i * 190) % INNER_HEIGHT
            size = 80 + (index * 29 + i * 37) % 120
            points = [
                (cx, cy - size),
                (cx + size * 0.866, cy + size * 0.5),
                (cx - size * 0.866, cy + size * 0.5)
            ]
            color = hsv_to_rgb((hue_base + 0.25) % 1, 0.55, 0.75)
            draw.polygon(points, outline=color, width=3)
    
    return img

# Generate all wallpapers
free_wallpapers = {
    "aurora": create_aurora_wallpaper,
    "ocean-depths": create_ocean_depths_wallpaper,
    "sunset-gradient": create_sunset_gradient_wallpaper,
    "minimal-geo": create_minimal_geo_wallpaper,
    "forest-mist": create_forest_mist_wallpaper,
    "night-city": create_night_city_wallpaper,
    "desert-dunes": create_desert_dunes_wallpaper,
    "space-nebula": create_space_nebula_wallpaper,
    "cherry-blossom": create_cherry_blossom_wallpaper,
    "abstract-waves": create_abstract_waves_wallpaper,
}

print("Generating DuoWall bundled wallpapers...")
print(f"Output directory: {OUTPUT_DIR}")
print(f"Image size: {INNER_WIDTH}x{INNER_HEIGHT}")
print()

# Generate free wallpapers
print("Free wallpapers (10):")
for name, generator in free_wallpapers.items():
    img = generator()
    # Save as PNG (can be converted to HEIC on macOS)
    filename = f"{name}.png"
    filepath = os.path.join(OUTPUT_DIR, filename)
    img.save(filepath, 'PNG')
    print(f"  ✓ {filename}")

print()

# Generate premium wallpapers
print("Premium wallpapers (20):")
for i in range(1, 21):
    img = create_premium_wallpaper(i)
    filename = f"premium-{i}.png"
    filepath = os.path.join(OUTPUT_DIR, filename)
    img.save(filepath, 'PNG')
    print(f"  ✓ {filename}")

print()
print(f"Generated 30 wallpapers in {OUTPUT_DIR}")
print()
print("NOTE: These are PNG files. On macOS, convert to HEIC with:")
print("  for f in *.png; do sips -s format heic \"$f\" --out \"${f%.png}.heic\"; done")
