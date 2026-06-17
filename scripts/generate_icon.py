#!/usr/bin/env python3
"""
Generate app icon for Claude Code Panel.
macOS-style squircle with bold </> code bracket motif.
Clean, recognizable at 16×16 through 1024×1024.
"""

import math
import os
import subprocess
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


# ── Paths ───────────────────────────────────────────────────────────────────

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "build" / "icon.iconset"
OUTPUT_ICNS = Path(__file__).resolve().parent.parent / "build" / "AppIcon.icns"


# ── Color palette ───────────────────────────────────────────────────────────

# Background gradient (diagonal, top-left to bottom-right)
BG_TOP    = (95, 50, 200)     # vibrant violet
BG_MID    = (55, 30, 135)     # mid purple
BG_BOTTOM = (20, 12, 55)      # deep indigo

# Bracket </> symbol
BRACKET_FILL   = (255, 255, 255, 240)   # bright white, slight translucency
BRACKET_GLOW   = (180, 160, 255, 60)    # soft purple glow

# Inner border (depth cue)
BORDER_OUTER = (0, 0, 0, 30)           # subtle dark edge
BORDER_INNER = (255, 255, 255, 20)      # hairline light inner

# Top shine (glass effect)
SHINE_COLOR = (255, 255, 255, 35)


# ── Squircle mask ───────────────────────────────────────────────────────────

def squircle_mask(size: int, supersample: int = 4) -> Image.Image:
    """macOS-style continuous-curvature rounded rect via supersampling."""
    large = size * supersample
    radius = int(large * 0.227)
    mask = Image.new("L", (large, large), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (large - 1, large - 1)], radius=radius, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


# ── Multi-stop diagonal gradient ────────────────────────────────────────────

def bg_gradient(size: int) -> Image.Image:
    """Three-stop diagonal gradient for rich background."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))  # 0..1 diagonal
            if t < 0.5:
                # Top→Mid
                s = t / 0.5
                r = int(BG_TOP[0] + (BG_MID[0] - BG_TOP[0]) * s)
                g = int(BG_TOP[1] + (BG_MID[1] - BG_TOP[1]) * s)
                b = int(BG_TOP[2] + (BG_MID[2] - BG_TOP[2]) * s)
            else:
                # Mid→Bottom
                s = (t - 0.5) / 0.5
                r = int(BG_MID[0] + (BG_BOTTOM[0] - BG_MID[0]) * s)
                g = int(BG_MID[1] + (BG_BOTTOM[1] - BG_MID[1]) * s)
                b = int(BG_MID[2] + (BG_BOTTOM[2] - BG_BOTTOM[1]) * s)
            px[x, y] = (r, g, b, 255)
    return img


# ── Draw the </> bracket symbol ─────────────────────────────────────────────

def draw_bracket(draw: ImageDraw.ImageDraw, cx: float, cy: float, bracket_size: float,
                 stroke_w: float, color: tuple):
    """
    Draw a stylized </> code bracket centered at (cx, cy).

    The symbol is composed of:
      - Left angle bracket  <  (two line segments forming an acute angle)
      - Slash                /  (diagonal line)
      - Right angle bracket >  (mirror of left)

    All scaled to bracket_size (the total width of `</>`).
    """
    # Proportions
    char_w = bracket_size * 0.30   # each character width
    gap = bracket_size * 0.06       # gap between chars
    half_h = bracket_size * 0.36    # half character height
    arm_inset = bracket_size * 0.10 # how far the bracket arms extend inward

    # --- Left bracket < ---
    left_cx = cx - char_w - gap
    # Top arm (upper-left to center-right)
    draw.line([
        (left_cx - arm_inset, cy - half_h),    # top-left tip
        (left_cx + arm_inset, cy),              # center point
        (left_cx - arm_inset, cy + half_h),    # bottom-left tip
    ], fill=color, width=int(stroke_w), joint="curve")

    # --- Slash / ---
    mid_cx = cx
    draw.line([
        (mid_cx + arm_inset * 0.8, cy - half_h),   # top-right
        (mid_cx - arm_inset * 0.8, cy + half_h),   # bottom-left
    ], fill=color, width=int(stroke_w))

    # --- Right bracket > ---
    right_cx = cx + char_w + gap
    draw.line([
        (right_cx + arm_inset, cy - half_h),    # top-right tip
        (right_cx - arm_inset, cy),              # center point
        (right_cx + arm_inset, cy + half_h),    # bottom-right tip
    ], fill=color, width=int(stroke_w), joint="curve")


# ── Core render ─────────────────────────────────────────────────────────────

def render_icon(size: int) -> Image.Image:
    """Render the Claude Code Panel icon at `size`×`size`."""

    # ── 1. Background ──
    gradient = bg_gradient(size)
    mask = squircle_mask(size)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(gradient, mask=mask)
    draw = ImageDraw.Draw(canvas)

    # ── 2. Subtle inner border for depth ──
    inset = max(1, int(size * 0.008))
    border_rect = [
        (inset, inset),
        (size - inset - 1, size - inset - 1),
    ]
    corner_radius = int(size * 0.22)
    # Dark outer edge
    draw.rounded_rectangle(
        border_rect,
        radius=corner_radius,
        outline=BORDER_OUTER,
        width=max(1, int(size * 0.005)),
    )

    # ── 3. Top shine (glass reflection) ──
    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shine_draw = ImageDraw.Draw(shine)
    # Elliptical highlight at top
    shine_draw.ellipse(
        [
            (int(size * 0.22), int(size * 0.04)),
            (int(size * 0.78), int(size * 0.30)),
        ],
        fill=SHINE_COLOR,
    )
    # Clip to squircle
    shine_result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shine_result.paste(shine, mask=mask)
    # Feather the bottom edge
    shine_result = shine_result.filter(ImageFilter.GaussianBlur(radius=max(1, size * 0.02)))
    canvas = Image.alpha_composite(canvas, shine_result)

    # ── 4. Bracket glow (behind the symbol) ──
    glow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    bracket_size_large = size * 0.46
    cx, cy = size / 2, size / 2
    # Draw a thick, translucent version as glow
    draw_bracket(glow_draw, cx, cy, bracket_size_large, size * 0.15, BRACKET_GLOW)
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=max(1, size * 0.04)))
    canvas = Image.alpha_composite(canvas, glow_layer)

    # ── 5. Main bracket symbol ──
    draw = ImageDraw.Draw(canvas)
    bracket_size = size * 0.44
    stroke = max(2, size * 0.045)
    draw_bracket(draw, cx, cy, bracket_size, stroke, BRACKET_FILL)

    # ── 6. Subtle noise texture (adds premium feel at large sizes) ──
    if size >= 256:
        import random
        noise = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        noise_px = noise.load()
        rng = random.Random(42)  # deterministic seed
        for y in range(size):
            for x in range(size):
                if mask.getpixel((x, y)) > 128:
                    n = rng.randint(0, 12)
                    if n == 0:
                        noise_px[x, y] = (255, 255, 255, 2)
        canvas = Image.alpha_composite(canvas, noise)

    return canvas


# ── Generate iconset ────────────────────────────────────────────────────────

SIZES = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png",  1024),
]


def main():
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Generating icons → {OUTPUT_DIR}")
    for filename, size in SIZES:
        print(f"  {filename} ({size}×{size})")
        img = render_icon(size)
        filepath = OUTPUT_DIR / filename
        img.save(filepath, "PNG")

    # Convert to .icns
    print(f"\nPackaging → {OUTPUT_ICNS}")
    subprocess.run(
        ["iconutil", "-c", "icns", "-o", str(OUTPUT_ICNS), str(OUTPUT_DIR)],
        check=True,
    )

    result = subprocess.run(["file", str(OUTPUT_ICNS)], capture_output=True, text=True)
    print(f"  {result.stdout.strip()}")
    print(f"  Size: {OUTPUT_ICNS.stat().st_size / 1024:.0f} KB")

    # Preview PNG
    preview_path = OUTPUT_DIR.parent / "AppIcon_preview.png"
    render_icon(512).save(preview_path, "PNG")
    print(f"  Preview: {preview_path}")
    print("\n✓ Done.")

    # Open preview
    subprocess.run(["open", str(preview_path)])


if __name__ == "__main__":
    main()
