#!/usr/bin/env python3
"""
Generate polished iPhone Duo UI mockups for DuoWall app.
Renders at 2x resolution with realistic device frames and UI.
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

SCALE = 2

INNER_WIDTH = 2670 * SCALE // 4
INNER_HEIGHT = 1878 * SCALE // 4

OUTER_WIDTH = 1398 * SCALE // 4
OUTER_HEIGHT = 2034 * SCALE // 4

DEVICE_CORNER_RADIUS = 60 * SCALE // 2
BEZEL = 12 * SCALE // 2

BG_DARK = (18, 18, 24)
BG_CARD = (28, 28, 36)
BG_PANEL = (22, 22, 30)
ACCENT = (255, 159, 67)
TEXT_PRIMARY = (255, 255, 255)
TEXT_SECONDARY = (140, 140, 160)
TEXT_TERTIARY = (90, 90, 110)
BORDER_SUBTLE = (50, 50, 65)
CREASE_COLOR = (60, 60, 75)
DEVICE_FRAME = (45, 45, 55)
DEVICE_SIDE = (35, 35, 45)


def get_font(size, bold=False):
    """Get a system font at the specified size."""
    try:
        if bold:
            return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
    except:
        return ImageFont.load_default()


def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    x1, y1, x2, y2 = xy
    if fill:
        draw.rounded_rectangle(xy, radius=radius, fill=fill)
    if outline:
        draw.rounded_rectangle(xy, radius=radius, outline=outline, width=width)


def draw_gradient_rect(draw, xy, color1, color2, vertical=True):
    """Draw a gradient-filled rectangle."""
    x1, y1, x2, y2 = xy
    if vertical:
        for y in range(int(y1), int(y2)):
            progress = (y - y1) / max(1, (y2 - y1))
            r = int(color1[0] + (color2[0] - color1[0]) * progress)
            g = int(color1[1] + (color2[1] - color1[1]) * progress)
            b = int(color1[2] + (color2[2] - color1[2]) * progress)
            draw.line([(x1, y), (x2, y)], fill=(r, g, b))
    else:
        for x in range(int(x1), int(x2)):
            progress = (x - x1) / max(1, (x2 - x1))
            r = int(color1[0] + (color2[0] - color1[0]) * progress)
            g = int(color1[1] + (color2[1] - color1[1]) * progress)
            b = int(color1[2] + (color2[2] - color1[2]) * progress)
            draw.line([(x, y1), (x, y2)], fill=(r, g, b))


def draw_wallpaper_art(draw, xy, style="aurora"):
    """Draw beautiful wallpaper art."""
    x1, y1, x2, y2 = xy
    width = x2 - x1
    height = y2 - y1
    
    if style == "aurora":
        draw_gradient_rect(draw, xy, (15, 20, 45), (25, 35, 65))
        for i in range(5):
            wave_y = y1 + height * (0.3 + i * 0.12)
            color = (
                40 + i * 30,
                80 + i * 25,
                120 + i * 20
            )
            for x in range(int(x1), int(x2), 2):
                offset = math.sin((x - x1) / 40 + i * 0.5) * 20
                y = wave_y + offset
                draw.ellipse([x-3, y-2, x+3, y+2], fill=color)
        
        for i in range(3):
            peak_x = x1 + width * (0.2 + i * 0.3)
            peak_h = height * (0.15 + i * 0.08)
            mountain_color = (20 + i*5, 25 + i*5, 40 + i*5)
            points = [
                (peak_x - width*0.2, y2),
                (peak_x, y2 - peak_h),
                (peak_x + width*0.2, y2)
            ]
            draw.polygon(points, fill=mountain_color)
    
    elif style == "sunset":
        colors = [
            (45, 25, 60),
            (80, 35, 70),
            (140, 60, 70),
            (200, 100, 70),
            (240, 150, 80),
        ]
        segment_h = height // len(colors)
        for i, color in enumerate(colors):
            seg_y1 = y1 + i * segment_h
            seg_y2 = y1 + (i + 1) * segment_h
            next_color = colors[i+1] if i < len(colors)-1 else colors[-1]
            draw_gradient_rect(draw, (x1, seg_y1, x2, seg_y2), color, next_color)
        
        sun_x = x1 + width * 0.5
        sun_y = y1 + height * 0.35
        sun_r = min(width, height) * 0.12
        for r in range(int(sun_r), 0, -2):
            alpha = int(255 * (r / sun_r))
            color = (255, min(255, 180 + int(75 * r/sun_r)), 100)
            draw.ellipse([sun_x-r, sun_y-r, sun_x+r, sun_y+r], fill=color)


def draw_sf_icon(draw, center, icon_type, size, color):
    """Draw SF Symbol-style icons."""
    x, y = center
    s = size // 2
    
    if icon_type == "gear":
        draw.ellipse([x-s*0.6, y-s*0.6, x+s*0.6, y+s*0.6], outline=color, width=2)
        draw.ellipse([x-s*0.25, y-s*0.25, x+s*0.25, y+s*0.25], fill=color)
        for i in range(8):
            angle = i * math.pi / 4
            dx = math.cos(angle) * s * 0.8
            dy = math.sin(angle) * s * 0.8
            draw.line([(x+dx*0.5, y+dy*0.5), (x+dx, y+dy)], fill=color, width=2)
    
    elif icon_type == "photo":
        draw.rounded_rectangle([x-s, y-s*0.7, x+s, y+s*0.7], radius=3, outline=color, width=2)
        draw.ellipse([x-s*0.5, y-s*0.3, x-s*0.1, y+s*0.1], fill=color)
        draw.polygon([(x-s*0.8, y+s*0.5), (x, y-s*0.1), (x+s*0.8, y+s*0.5)], fill=color)
    
    elif icon_type == "heart":
        draw.ellipse([x-s*0.6, y-s*0.4, x, y+s*0.1], fill=color)
        draw.ellipse([x, y-s*0.4, x+s*0.6, y+s*0.1], fill=color)
        draw.polygon([(x-s*0.6, y), (x, y+s*0.7), (x+s*0.6, y)], fill=color)
    
    elif icon_type == "lock":
        draw.rounded_rectangle([x-s*0.5, y-s*0.1, x+s*0.5, y+s*0.6], radius=3, fill=color)
        draw.arc([x-s*0.35, y-s*0.6, x+s*0.35, y+s*0.1], 180, 360, fill=color, width=3)
    
    elif icon_type == "arrow_down":
        draw.line([(x, y-s*0.5), (x, y+s*0.3)], fill=color, width=2)
        draw.polygon([(x-s*0.4, y), (x, y+s*0.5), (x+s*0.4, y)], fill=color)
    
    elif icon_type == "plus":
        draw.line([(x-s*0.5, y), (x+s*0.5, y)], fill=color, width=2)
        draw.line([(x, y-s*0.5), (x, y+s*0.5)], fill=color, width=2)
    
    elif icon_type == "undo":
        draw.arc([x-s*0.5, y-s*0.3, x+s*0.3, y+s*0.5], 90, 270, fill=color, width=2)
        draw.polygon([(x-s*0.6, y-s*0.1), (x-s*0.3, y-s*0.5), (x-s*0.3, y+s*0.3)], fill=color)
    
    elif icon_type == "redo":
        draw.arc([x-s*0.3, y-s*0.3, x+s*0.5, y+s*0.5], 270, 90, fill=color, width=2)
        draw.polygon([(x+s*0.6, y-s*0.1), (x+s*0.3, y-s*0.5), (x+s*0.3, y+s*0.3)], fill=color)
    
    elif icon_type == "layers":
        for i in range(3):
            offset = i * s * 0.25
            draw.polygon([
                (x, y - s*0.4 + offset),
                (x + s*0.6, y + offset),
                (x, y + s*0.2 + offset),
                (x - s*0.6, y + offset)
            ], outline=color, width=2)
    
    elif icon_type == "crop":
        draw.line([(x-s*0.6, y-s*0.3), (x-s*0.6, y+s*0.6), (x+s*0.3, y+s*0.6)], fill=color, width=2)
        draw.line([(x+s*0.6, y+s*0.3), (x+s*0.6, y-s*0.6), (x-s*0.3, y-s*0.6)], fill=color, width=2)


def draw_device_frame_inner(img, draw, padding=30):
    """Draw the unfolded iPhone Duo device frame."""
    w, h = img.size
    frame_x1 = padding
    frame_y1 = padding
    frame_x2 = w - padding
    frame_y2 = h - padding
    
    draw_rounded_rect(draw, (frame_x1-BEZEL, frame_y1-BEZEL, frame_x2+BEZEL, frame_y2+BEZEL),
                      DEVICE_CORNER_RADIUS, fill=DEVICE_FRAME)
    
    crease_x = (frame_x1 + frame_x2) // 2
    crease_width = 8
    draw.rectangle([crease_x - crease_width//2, frame_y1-BEZEL, 
                    crease_x + crease_width//2, frame_y2+BEZEL], fill=CREASE_COLOR)
    
    screen_x1 = frame_x1
    screen_y1 = frame_y1
    screen_x2 = frame_x2
    screen_y2 = frame_y2
    
    return (screen_x1, screen_y1, screen_x2, screen_y2)


def draw_device_frame_outer(img, draw, padding=60):
    """Draw the closed iPhone Duo device frame with side thickness."""
    w, h = img.size
    
    thickness = 25
    frame_x1 = padding + thickness
    frame_y1 = padding
    frame_x2 = w - padding
    frame_y2 = h - padding
    
    draw.rounded_rectangle(
        [padding, frame_y1 - BEZEL, padding + thickness, frame_y2 + BEZEL],
        radius=8, fill=DEVICE_SIDE
    )
    for i in range(3):
        line_x = padding + 5 + i * 7
        draw.line([(line_x, frame_y1 + 50), (line_x, frame_y1 + 120)], fill=(55, 55, 65), width=2)
    
    draw_rounded_rect(draw, (frame_x1-BEZEL, frame_y1-BEZEL, frame_x2+BEZEL, frame_y2+BEZEL),
                      DEVICE_CORNER_RADIUS, fill=DEVICE_FRAME)
    
    return (frame_x1, frame_y1, frame_x2, frame_y2)


def create_unfolded_mockup():
    """Create polished unfolded inner display mockup."""
    canvas_w = INNER_WIDTH + 80
    canvas_h = INNER_HEIGHT + 80
    img = Image.new('RGB', (canvas_w, canvas_h), (10, 10, 15))
    draw = ImageDraw.Draw(img)
    
    screen = draw_device_frame_inner(img, draw, padding=40)
    sx1, sy1, sx2, sy2 = screen
    sw = sx2 - sx1
    sh = sy2 - sy1
    
    draw.rectangle(screen, fill=BG_DARK)
    
    left_w = sw // 2 - 4
    right_w = sw // 2 - 4
    
    draw_wallpaper_art(draw, (sx1, sy1 + 50, sx1 + left_w, sy2 - 10), "aurora")
    
    crop_margin = left_w * 0.25
    crop_x1 = sx1 + crop_margin
    crop_x2 = sx1 + left_w - crop_margin * 0.5
    draw.rounded_rectangle([crop_x1, sy1 + 60, crop_x2, sy2 - 20],
                           radius=8, outline=ACCENT, width=2)
    
    font_small = get_font(11)
    draw.text((crop_x1 + 8, sy1 + 68), "OUTER SCREEN", fill=ACCENT, font=font_small)
    
    panel_x = sx1 + sw // 2 + 8
    panel_w = right_w - 8
    
    draw.rectangle([panel_x, sy1, sx2, sy2], fill=BG_PANEL)
    
    header_h = 44
    draw.rectangle([panel_x, sy1, sx2, sy1 + header_h], fill=BG_CARD)
    
    font_title = get_font(16, bold=True)
    font_label = get_font(12)
    font_small = get_font(10)
    
    draw.text((panel_x + 15, sy1 + 14), "Editor", fill=TEXT_PRIMARY, font=font_title)
    
    draw.text((sx2 - 55, sy1 + 16), "Export", fill=ACCENT, font=font_label)
    
    draw_sf_icon(draw, (panel_x + panel_w - 120, sy1 + 22), "undo", 16, TEXT_SECONDARY)
    draw_sf_icon(draw, (panel_x + panel_w - 90, sy1 + 22), "redo", 16, TEXT_SECONDARY)
    
    section_y = sy1 + header_h + 20
    
    draw.text((panel_x + 15, section_y), "Overlays", fill=TEXT_SECONDARY, font=font_small)
    section_y += 22
    
    toggles = [("Outer Frame", True), ("Crease Line", True), ("Safe Areas", False)]
    for label, enabled in toggles:
        draw.text((panel_x + 15, section_y + 4), label, fill=TEXT_PRIMARY, font=font_label)
        toggle_x = panel_x + panel_w - 50
        toggle_color = ACCENT if enabled else BORDER_SUBTLE
        draw.rounded_rectangle([toggle_x, section_y + 2, toggle_x + 36, section_y + 20],
                               radius=10, fill=toggle_color)
        knob_x = toggle_x + 20 if enabled else toggle_x + 4
        draw.ellipse([knob_x, section_y + 4, knob_x + 14, section_y + 18], fill=TEXT_PRIMARY)
        section_y += 32
    
    section_y += 15
    draw.line([(panel_x + 15, section_y), (sx2 - 15, section_y)], fill=BORDER_SUBTLE, width=1)
    section_y += 20
    
    draw.text((panel_x + 15, section_y), "Template", fill=TEXT_SECONDARY, font=font_small)
    section_y += 22
    
    templates = [("Reveal", True), ("Panorama", False), ("Split Mood", False)]
    btn_w = (panel_w - 45) // 3
    for i, (name, selected) in enumerate(templates):
        btn_x = panel_x + 15 + i * (btn_w + 5)
        btn_fill = ACCENT if selected else BG_CARD
        text_color = BG_DARK if selected else TEXT_SECONDARY
        draw.rounded_rectangle([btn_x, section_y, btn_x + btn_w, section_y + 30],
                               radius=6, fill=btn_fill)
        text_x = btn_x + btn_w // 2
        draw.text((text_x, section_y + 9), name, fill=text_color, font=font_small, anchor="mt")
        
    section_y += 50
    draw.line([(panel_x + 15, section_y), (sx2 - 15, section_y)], fill=BORDER_SUBTLE, width=1)
    section_y += 20
    
    draw.text((panel_x + 15, section_y), "Layers", fill=TEXT_SECONDARY, font=font_small)
    draw_sf_icon(draw, (sx2 - 25, section_y + 6), "plus", 14, ACCENT)
    section_y += 25
    
    layers = [("Photo", "photo", True), ("Fill - Blur", "layers", False)]
    for name, icon, selected in layers:
        layer_fill = (35, 35, 48) if selected else BG_CARD
        draw.rounded_rectangle([panel_x + 15, section_y, sx2 - 15, section_y + 40],
                               radius=6, fill=layer_fill,
                               outline=ACCENT if selected else None, width=2 if selected else 0)
        draw_sf_icon(draw, (panel_x + 35, section_y + 20), icon, 16, TEXT_SECONDARY)
        draw.text((panel_x + 55, section_y + 13), name, fill=TEXT_PRIMARY, font=font_label)
        section_y += 48
    
    crease_x = sx1 + sw // 2
    draw.line([(crease_x, sy1), (crease_x, sy2)], fill=CREASE_COLOR, width=4)
    
    return img


def create_half_folded_mockup():
    """Create polished half-folded mockup with visible hinge."""
    canvas_w = INNER_WIDTH + 80
    canvas_h = int(INNER_HEIGHT * 1.4) + 80
    img = Image.new('RGB', (canvas_w, canvas_h), (10, 10, 15))
    draw = ImageDraw.Draw(img)
    
    screen_w = INNER_WIDTH
    top_h = int(INNER_HEIGHT * 0.55)
    bottom_h = int(INNER_HEIGHT * 0.45)
    
    margin = 40
    top_x1 = margin
    top_y1 = margin
    top_x2 = margin + screen_w
    top_y2 = margin + top_h
    
    draw_rounded_rect(draw, (top_x1-BEZEL, top_y1-BEZEL, top_x2+BEZEL, top_y2+BEZEL//2),
                      DEVICE_CORNER_RADIUS, fill=DEVICE_FRAME)
    draw.rectangle((top_x1, top_y1, top_x2, top_y2), fill=BG_DARK)
    
    draw_wallpaper_art(draw, (top_x1 + 20, top_y1 + 50, top_x2 - 20, top_y2 - 20), "sunset")
    
    crop_w = (top_x2 - top_x1) * 0.35
    crop_x1 = top_x1 + (top_x2 - top_x1 - crop_w) // 2
    crop_x2 = crop_x1 + crop_w
    draw.rounded_rectangle([crop_x1, top_y1 + 60, crop_x2, top_y2 - 30],
                           radius=6, outline=ACCENT, width=2)
    
    font_small = get_font(10)
    draw.text((crop_x1 + 8, top_y1 + 68), "OUTER", fill=ACCENT, font=font_small)
    
    hinge_y = top_y2 + BEZEL // 2
    hinge_h = 20
    
    draw.rounded_rectangle([top_x1 - BEZEL, hinge_y, top_x2 + BEZEL, hinge_y + hinge_h],
                           radius=4, fill=(55, 55, 65))
    draw.line([(top_x1, hinge_y + hinge_h//2), (top_x2, hinge_y + hinge_h//2)],
              fill=(70, 70, 85), width=2)
    
    for x in range(int(top_x1), int(top_x2), 40):
        draw.ellipse([x-2, hinge_y + hinge_h//2 - 2, x+2, hinge_y + hinge_h//2 + 2],
                     fill=(80, 80, 95))
    
    bottom_y1 = hinge_y + hinge_h
    bottom_y2 = bottom_y1 + bottom_h
    
    draw_rounded_rect(draw, (top_x1-BEZEL, bottom_y1-BEZEL//2, top_x2+BEZEL, bottom_y2+BEZEL),
                      DEVICE_CORNER_RADIUS, fill=DEVICE_FRAME)
    draw.rectangle((top_x1, bottom_y1, top_x2, bottom_y2), fill=BG_PANEL)
    
    font_title = get_font(14, bold=True)
    font_label = get_font(11)
    font_small = get_font(10)
    
    col_w = screen_w // 3
    sections = [
        ("Overlays", ["Outer Frame", "Crease", "Safe Areas"]),
        ("Template", ["Reveal", "Panorama", "Split"]),
        ("Layers", ["Photo", "Fill"])
    ]
    
    for i, (title, items) in enumerate(sections):
        col_x = top_x1 + i * col_w + 20
        y = bottom_y1 + 25
        
        draw.text((col_x, y), title, fill=TEXT_SECONDARY, font=font_small)
        y += 25
        
        for item in items:
            is_selected = item in ["Outer Frame", "Crease", "Reveal", "Photo"]
            item_fill = (40, 40, 55) if is_selected else BG_CARD
            draw.rounded_rectangle([col_x, y, col_x + col_w - 40, y + 28],
                                   radius=5, fill=item_fill,
                                   outline=ACCENT if is_selected and i == 1 else None,
                                   width=2 if is_selected and i == 1 else 0)
            draw.text((col_x + 10, y + 7), item, fill=TEXT_PRIMARY, font=font_label)
            y += 36
    
    font_label = get_font(12)
    draw.text((margin + 10, margin - 25), "Half-Folded • Hinge ~120°", fill=TEXT_TERTIARY, font=font_label)
    
    return img


def create_outer_mockup():
    """Create polished outer (closed) display mockup."""
    canvas_w = OUTER_WIDTH + 140
    canvas_h = OUTER_HEIGHT + 100
    img = Image.new('RGB', (canvas_w, canvas_h), (10, 10, 15))
    draw = ImageDraw.Draw(img)
    
    screen = draw_device_frame_outer(img, draw, padding=50)
    sx1, sy1, sx2, sy2 = screen
    sw = sx2 - sx1
    sh = sy2 - sy1
    
    draw.rectangle(screen, fill=BG_DARK)
    
    draw_wallpaper_art(draw, (sx1, sy1, sx2, sy2), "aurora")
    
    font_time = get_font(48, bold=True)
    font_date = get_font(14)
    
    time_y = sy1 + sh * 0.12
    draw.text((sx1 + 25, time_y), "9:41", fill=TEXT_PRIMARY, font=font_time)
    draw.text((sx1 + 25, time_y + 55), "Wednesday, October 14", fill=TEXT_PRIMARY, font=font_date)
    
    di_w = 28
    di_h = 85
    di_x = sx2 - 45
    di_y = sy1 + 20
    draw.rounded_rectangle([di_x, di_y, di_x + di_w, di_y + di_h],
                           radius=14, fill=(0, 0, 0))
    
    camera_y = di_y + 15
    draw.ellipse([di_x + 8, camera_y, di_x + 20, camera_y + 12], fill=(30, 30, 35))
    draw.ellipse([di_x + 10, camera_y + 2, di_x + 18, camera_y + 10], fill=(15, 15, 20))
    
    flashlight_y = sy2 - 80
    flashlight_x = sx1 + 35
    draw.rounded_rectangle([flashlight_x, flashlight_y, flashlight_x + 50, flashlight_y + 50],
                           radius=25, fill=(50, 50, 60, 180))
    draw.ellipse([flashlight_x + 15, flashlight_y + 15, flashlight_x + 35, flashlight_y + 35],
                 fill=TEXT_SECONDARY)
    
    camera_btn_x = sx2 - 85
    draw.rounded_rectangle([camera_btn_x, flashlight_y, camera_btn_x + 50, flashlight_y + 50],
                           radius=25, fill=(50, 50, 60, 180))
    draw_sf_icon(draw, (camera_btn_x + 25, flashlight_y + 25), "photo", 18, TEXT_SECONDARY)
    
    indicator_y = sy2 - 25
    indicator_w = 120
    indicator_x = sx1 + (sw - indicator_w) // 2
    draw.rounded_rectangle([indicator_x, indicator_y, indicator_x + indicator_w, indicator_y + 5],
                           radius=2, fill=TEXT_PRIMARY)
    
    font_label = get_font(11)
    draw.text((50, canvas_h - 30), "Closed • Outer Display", fill=TEXT_TERTIARY, font=font_label)
    
    return img


def create_gallery_mockup():
    """Create polished gallery screen mockup."""
    canvas_w = INNER_WIDTH + 80
    canvas_h = INNER_HEIGHT + 80
    img = Image.new('RGB', (canvas_w, canvas_h), (10, 10, 15))
    draw = ImageDraw.Draw(img)
    
    screen = draw_device_frame_inner(img, draw, padding=40)
    sx1, sy1, sx2, sy2 = screen
    sw = sx2 - sx1
    sh = sy2 - sy1
    
    draw.rectangle(screen, fill=BG_DARK)
    
    header_h = 50
    draw.rectangle([sx1, sy1, sx2, sy1 + header_h], fill=BG_PANEL)
    
    font_title = get_font(18, bold=True)
    font_label = get_font(12)
    font_small = get_font(10)
    
    draw.text((sx1 + sw//2, sy1 + 18), "DuoWall", fill=TEXT_PRIMARY, font=font_title, anchor="mt")
    draw_sf_icon(draw, (sx2 - 35, sy1 + 25), "gear", 20, TEXT_SECONDARY)
    
    content_y = sy1 + header_h + 15
    crease_x = sx1 + sw // 2
    
    card_w = (sw // 2 - 60) // 2
    card_h = int(card_w * 1.4)
    padding = 15
    
    draw.text((sx1 + 25, content_y), "Free Collection", fill=TEXT_PRIMARY, font=font_label)
    content_y += 25
    
    free_cards = [
        ("Aurora", (30, 60, 100), (60, 120, 180)),
        ("Sunset", (100, 50, 70), (200, 120, 80)),
        ("Ocean", (20, 50, 80), (40, 100, 140)),
        ("Forest", (30, 60, 45), (60, 120, 90)),
    ]
    
    for i, (name, c1, c2) in enumerate(free_cards):
        col = i % 2
        row = i // 2
        
        if col == 0:
            card_x = sx1 + 25 + col * (card_w + padding)
        else:
            card_x = sx1 + 25 + col * (card_w + padding)
        card_y = content_y + row * (card_h + padding + 20)
        
        if card_x + card_w > crease_x - 10:
            continue
            
        draw_gradient_rect(draw, (card_x, card_y, card_x + card_w, card_y + card_h), c1, c2)
        draw.rounded_rectangle([card_x, card_y, card_x + card_w, card_y + card_h],
                               radius=12, outline=(60, 60, 75), width=1)
        
        draw_sf_icon(draw, (card_x + card_w//2, card_y + card_h//2 - 10), "photo", 24, (255, 255, 255, 180))
        
        draw.text((card_x + card_w//2, card_y + card_h - 20), name,
                  fill=TEXT_PRIMARY, font=font_small, anchor="mt")
    
    right_x = crease_x + 15
    
    draw.text((right_x, sy1 + header_h + 15), "Pro Collection", fill=TEXT_PRIMARY, font=font_label)
    pro_y = sy1 + header_h + 40
    
    pro_cards = [
        ("Nebula", (60, 30, 80), (120, 60, 140)),
        ("Minimal", (40, 40, 50), (80, 80, 100)),
        ("Abstract", (80, 40, 60), (160, 80, 100)),
        ("Gradient", (40, 60, 80), (80, 120, 160)),
    ]
    
    for i, (name, c1, c2) in enumerate(pro_cards):
        col = i % 2
        row = i // 2
        
        card_x = right_x + col * (card_w + padding)
        card_y = pro_y + row * (card_h + padding + 20)
        
        if card_x + card_w > sx2 - 25:
            continue
        
        draw_gradient_rect(draw, (card_x, card_y, card_x + card_w, card_y + card_h), c1, c2)
        draw.rounded_rectangle([card_x, card_y, card_x + card_w, card_y + card_h],
                               radius=12, outline=(60, 60, 75), width=1)
        
        draw.rounded_rectangle([card_x + card_w - 45, card_y + 8, card_x + card_w - 8, card_y + 26],
                               radius=4, fill=(0, 0, 0, 150))
        draw_sf_icon(draw, (card_x + card_w - 35, card_y + 17), "lock", 10, ACCENT)
        draw.text((card_x + card_w - 22, card_y + 12), "PRO", fill=ACCENT, font=get_font(8))
        
        draw_sf_icon(draw, (card_x + card_w//2, card_y + card_h//2 - 10), "photo", 24, (255, 255, 255, 150))
        
        draw.text((card_x + card_w//2, card_y + card_h - 20), name,
                  fill=TEXT_PRIMARY, font=font_small, anchor="mt")
    
    draw.line([(crease_x, sy1), (crease_x, sy2)], fill=CREASE_COLOR, width=4)
    
    return img


def create_editor_mockup():
    """Create polished editor screen mockup with full UI."""
    canvas_w = INNER_WIDTH + 80
    canvas_h = INNER_HEIGHT + 80
    img = Image.new('RGB', (canvas_w, canvas_h), (10, 10, 15))
    draw = ImageDraw.Draw(img)
    
    screen = draw_device_frame_inner(img, draw, padding=40)
    sx1, sy1, sx2, sy2 = screen
    sw = sx2 - sx1
    sh = sy2 - sy1
    
    draw.rectangle(screen, fill=BG_DARK)
    
    crease_x = sx1 + sw // 2
    canvas_area = (sx1, sy1, crease_x - 8, sy2)
    
    draw.rectangle(canvas_area, fill=(20, 20, 28))
    
    canvas_margin = 30
    art_x1 = sx1 + canvas_margin
    art_y1 = sy1 + 60
    art_x2 = crease_x - 8 - canvas_margin
    art_y2 = sy2 - canvas_margin
    
    draw_wallpaper_art(draw, (art_x1, art_y1, art_x2, art_y2), "aurora")
    draw.rounded_rectangle([art_x1, art_y1, art_x2, art_y2], radius=8, outline=(60, 60, 75), width=1)
    
    art_w = art_x2 - art_x1
    crop_w = art_w * 0.48
    crop_x1 = art_x1 + (art_w - crop_w) // 2
    crop_x2 = crop_x1 + crop_w
    draw.rounded_rectangle([crop_x1, art_y1 + 10, crop_x2, art_y2 - 10],
                           radius=6, outline=ACCENT, width=3)
    
    font_tiny = get_font(9)
    draw.text((crop_x1 + 8, art_y1 + 18), "OUTER SCREEN", fill=ACCENT, font=font_tiny)
    
    art_center_x = (art_x1 + art_x2) // 2
    draw.line([(art_center_x, art_y1 + 5), (art_center_x, art_y2 - 5)],
              fill=(255, 255, 255, 80), width=1)
    
    draw.text((art_x1, art_y1 - 20), "Canvas Preview", fill=TEXT_TERTIARY, font=font_tiny)
    
    panel_x = crease_x + 8
    panel_w = sx2 - panel_x
    draw.rectangle([panel_x, sy1, sx2, sy2], fill=BG_PANEL)
    
    header_h = 48
    draw.rectangle([panel_x, sy1, sx2, sy1 + header_h], fill=BG_CARD)
    
    font_title = get_font(15, bold=True)
    font_label = get_font(11)
    font_small = get_font(10)
    
    draw.text((panel_x + 60, sy1 + 16), "Editor", fill=TEXT_PRIMARY, font=font_title)
    draw.text((panel_x + 15, sy1 + 17), "Cancel", fill=TEXT_SECONDARY, font=font_label)
    
    btn_y = sy1 + 12
    draw.rounded_rectangle([sx2 - 70, btn_y, sx2 - 15, btn_y + 26],
                           radius=6, fill=ACCENT)
    draw.text((sx2 - 42, btn_y + 6), "Export", fill=BG_DARK, font=font_small, anchor="mt")
    
    draw_sf_icon(draw, (sx2 - 105, sy1 + 24), "undo", 14, TEXT_SECONDARY)
    draw_sf_icon(draw, (sx2 - 85, sy1 + 24), "redo", 14, TEXT_SECONDARY)
    
    section_y = sy1 + header_h + 20
    section_indent = 18
    
    draw.text((panel_x + section_indent, section_y), "OVERLAYS", fill=TEXT_TERTIARY, font=font_tiny)
    section_y += 20
    
    overlays = [("Outer Frame", True), ("Crease Line", True), ("Safe Areas", False)]
    for label, enabled in overlays:
        draw.text((panel_x + section_indent, section_y + 3), label, fill=TEXT_PRIMARY, font=font_label)
        toggle_x = sx2 - 55
        toggle_bg = ACCENT if enabled else (50, 50, 60)
        draw.rounded_rectangle([toggle_x, section_y, toggle_x + 38, section_y + 22],
                               radius=11, fill=toggle_bg)
        knob_x = toggle_x + 19 if enabled else toggle_x + 3
        draw.ellipse([knob_x, section_y + 3, knob_x + 16, section_y + 19], fill=TEXT_PRIMARY)
        section_y += 32
    
    section_y += 12
    draw.line([(panel_x + section_indent, section_y), (sx2 - section_indent, section_y)],
              fill=BORDER_SUBTLE, width=1)
    section_y += 18
    
    draw.text((panel_x + section_indent, section_y), "TEMPLATE", fill=TEXT_TERTIARY, font=font_tiny)
    section_y += 20
    
    templates = ["Reveal", "Panorama", "Split"]
    btn_w = (panel_w - section_indent * 2 - 16) // 3
    for i, name in enumerate(templates):
        btn_x = panel_x + section_indent + i * (btn_w + 8)
        is_selected = i == 0
        btn_bg = ACCENT if is_selected else BG_CARD
        text_col = BG_DARK if is_selected else TEXT_SECONDARY
        draw.rounded_rectangle([btn_x, section_y, btn_x + btn_w, section_y + 32],
                               radius=6, fill=btn_bg)
        draw.text((btn_x + btn_w//2, section_y + 10), name, fill=text_col, font=font_small, anchor="mt")
    section_y += 48
    
    draw.line([(panel_x + section_indent, section_y), (sx2 - section_indent, section_y)],
              fill=BORDER_SUBTLE, width=1)
    section_y += 18
    
    draw.text((panel_x + section_indent, section_y), "LAYERS", fill=TEXT_TERTIARY, font=font_tiny)
    draw_sf_icon(draw, (sx2 - 25, section_y + 5), "plus", 12, ACCENT)
    section_y += 24
    
    layers = [
        ("Photo Layer", "photo", True, "aurora-photo.heic"),
        ("Fill - Blur Extend", "layers", False, "Radius: 50px"),
    ]
    
    for name, icon, selected, detail in layers:
        layer_h = 50
        layer_bg = (38, 38, 52) if selected else BG_CARD
        draw.rounded_rectangle([panel_x + section_indent, section_y,
                                sx2 - section_indent, section_y + layer_h],
                               radius=8, fill=layer_bg,
                               outline=ACCENT if selected else None,
                               width=2 if selected else 0)
        
        icon_x = panel_x + section_indent + 20
        draw_sf_icon(draw, (icon_x, section_y + layer_h//2), icon, 16, TEXT_SECONDARY)
        
        draw.text((icon_x + 20, section_y + 12), name, fill=TEXT_PRIMARY, font=font_label)
        draw.text((icon_x + 20, section_y + 28), detail, fill=TEXT_TERTIARY, font=font_tiny)
        
        section_y += layer_h + 8
    
    draw.line([(crease_x, sy1), (crease_x, sy2)], fill=CREASE_COLOR, width=4)
    
    return img


def main():
    output_dirs = [
        "/workspace/docs/ui/png",
        "/opt/cursor/artifacts"
    ]
    
    for dir_path in output_dirs:
        os.makedirs(dir_path, exist_ok=True)
    
    mockups = {
        "duowall-inner-unfolded.png": create_unfolded_mockup(),
        "duowall-half-folded.png": create_half_folded_mockup(),
        "duowall-outer-cover.png": create_outer_mockup(),
        "duowall-gallery.png": create_gallery_mockup(),
        "duowall-editor.png": create_editor_mockup(),
    }
    
    for filename, img in mockups.items():
        for dir_path in output_dirs:
            filepath = os.path.join(dir_path, filename)
            img.save(filepath, 'PNG')
            print(f"Saved: {filepath} ({img.size[0]}x{img.size[1]})")
    
    print(f"\nGenerated {len(mockups)} polished mockups at 2x resolution")


if __name__ == "__main__":
    main()
