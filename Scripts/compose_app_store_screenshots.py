#!/usr/bin/env python3
"""Compose App Store marketing screenshots from verified simulator captures."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "AppStoreAssets" / "Screenshots" / "iPhone-6.9"
OUTPUT = ROOT / "AppStoreAssets" / "Screenshots" / "iPhone-6.9-Marketing"

CANVAS_SIZE = (1320, 2868)
PHONE_SIZE = (1010, 2195)
PHONE_ORIGIN = (155, 610)

HEADLINES = {
    "01-home.jpg": "Your home,\nbeautifully organized",
    "02-areas.jpg": "Every room\nat a glance",
    "03-history.jpg": "Understand\nwhat changed",
    "04-customize.jpg": "Dashboards\nmade for you",
    "05-widgets.jpg": "Powerful widgets,\nright where you need them",
    "06-homestead-plus.jpg": "More home\nwith Homestead+",
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
        if bold
        else "/System/Library/Fonts/SFNS.ttf"
    )
    return ImageFont.truetype(path, size=size)


def vertical_gradient() -> Image.Image:
    width, height = CANVAS_SIZE
    image = Image.new("RGB", CANVAS_SIZE)
    pixels = image.load()
    top = (11, 24, 43)
    bottom = (2, 7, 14)
    for y in range(height):
        progress = y / (height - 1)
        eased = progress ** 0.82
        color = tuple(round(a + (b - a) * eased) for a, b in zip(top, bottom))
        for x in range(width):
            pixels[x, y] = color
    return image


def rounded_phone(source: Image.Image) -> tuple[Image.Image, Image.Image]:
    fitted = source.resize(PHONE_SIZE, Image.Resampling.LANCZOS).convert("RGB")
    mask = Image.new("L", PHONE_SIZE, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, PHONE_SIZE[0] - 1, PHONE_SIZE[1] - 1),
        radius=86,
        fill=255,
    )
    return fitted, mask


def draw_centered_multiline(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    text_font: ImageFont.FreeTypeFont,
) -> None:
    spacing = 4
    box = draw.multiline_textbbox((0, 0), text, font=text_font, spacing=spacing, align="center")
    width = box[2] - box[0]
    draw.multiline_text(
        ((CANVAS_SIZE[0] - width) / 2, y),
        text,
        font=text_font,
        fill=(250, 252, 255),
        spacing=spacing,
        align="center",
    )


def compose(source_path: Path, output_path: Path, headline: str) -> None:
    canvas = vertical_gradient()
    draw = ImageDraw.Draw(canvas)

    kicker_font = font(30, bold=True)
    headline_font = font(88, bold=True)

    kicker = "HOMESTEAD"
    kicker_box = draw.textbbox((0, 0), kicker, font=kicker_font)
    kicker_width = kicker_box[2] - kicker_box[0]
    draw.text(
        ((CANVAS_SIZE[0] - kicker_width) / 2, 108),
        kicker,
        font=kicker_font,
        fill=(74, 169, 255),
    )
    draw.rounded_rectangle((620, 170, 700, 180), radius=5, fill=(74, 169, 255))
    draw_centered_multiline(draw, headline, 214, headline_font)

    phone, phone_mask = rounded_phone(Image.open(source_path))

    shadow = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    x, y = PHONE_ORIGIN
    shadow_draw.rounded_rectangle(
        (x - 18, y + 12, x + PHONE_SIZE[0] + 18, y + PHONE_SIZE[1] + 42),
        radius=104,
        fill=(0, 0, 0, 190),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.paste(phone.convert("RGBA"), PHONE_ORIGIN, phone_mask)

    frame = ImageDraw.Draw(canvas)
    frame.rounded_rectangle(
        (x - 3, y - 3, x + PHONE_SIZE[0] + 3, y + PHONE_SIZE[1] + 3),
        radius=90,
        outline=(255, 255, 255, 44),
        width=6,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output_path, quality=96, subsampling=0)


def main() -> None:
    for filename, headline in HEADLINES.items():
        compose(SOURCE / filename, OUTPUT / filename, headline)
        print(OUTPUT / filename)


if __name__ == "__main__":
    main()
