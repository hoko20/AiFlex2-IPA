#!/usr/bin/env python3
"""Render the AiFlex2 app icon set (gradient + A mark + spark)."""
import json
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset"
S = 2  # supersample factor
W = 1024 * S


def gradient() -> Image.Image:
    small = Image.new("RGB", (2, 2))
    small.putpixel((0, 0), (92, 142, 255))
    small.putpixel((1, 0), (138, 112, 255))
    small.putpixel((0, 1), (116, 104, 255))
    small.putpixel((1, 1), (198, 112, 255))
    return small.resize((W, W), Image.BICUBIC).convert("RGBA")


def star(draw: ImageDraw.ImageDraw, cx: float, cy: float, outer: float, inner: float,
         color=(255, 255, 255, 255)) -> None:
    points = []
    for index in range(8):
        radius = outer if index % 2 == 0 else inner
        angle = -math.pi / 2 + index * math.pi / 4
        points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    draw.polygon(points, fill=color)


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for name in ("seguibl.ttf", "segoeuib.ttf", "arialbd.ttf"):
        path = pathlib.Path("C:/Windows/Fonts") / name
        if not path.is_file():
            path = pathlib.Path("/System/Library/Fonts") / name
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    raise SystemExit("No bold system font found")


def render() -> Image.Image:
    image = gradient()

    # 左上角柔光
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        (W * 0.20, -W * 0.22, W * 1.24, W * 0.72),
        fill=(255, 255, 255, 58),
    )
    image = Image.alpha_composite(image, glow.filter(ImageFilter.GaussianBlur(W * 0.10)))

    overlay = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # 细光环，底部亮弧
    box = (W * 0.19, W * 0.21, W * 0.81, W * 0.83)
    draw.ellipse(box, outline=(255, 255, 255, 38), width=max(2, int(W * 0.006)))
    draw.arc(box, start=160, end=340, fill=(255, 255, 255, 110), width=max(2, int(W * 0.009)))

    # 星光
    star(draw, W * 0.740, W * 0.250, W * 0.062, W * 0.018)
    star(draw, W * 0.792, W * 0.338, W * 0.022, W * 0.007, (255, 255, 255, 205))

    image = Image.alpha_composite(image, overlay)

    # 白色 A 字，带柔和投影
    glyph_mask = Image.new("L", (W, W), 0)
    mask_draw = ImageDraw.Draw(glyph_mask)
    font = load_font(int(W * 0.56))
    mask_draw.text((W * 0.5, W * 0.535), "A", font=font, anchor="mm", fill=255)
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow.paste((46, 30, 96, 96), (0, 0), glyph_mask)
    shadow = shadow.transform(
        shadow.size,
        Image.AFFINE,
        (1, 0, 0, 0, 1, -W * 0.018),
        resample=Image.BICUBIC,
    ).filter(ImageFilter.GaussianBlur(W * 0.022))
    image = Image.alpha_composite(image, shadow)
    white = Image.new("RGBA", (W, W), (255, 255, 255, 255))
    image.paste(white, (0, 0), glyph_mask)

    return image.convert("RGB").resize((1024, 1024), Image.LANCZOS)


def main() -> None:
    art = render()
    spec = json.loads((ICONSET / "Contents.json").read_text(encoding="utf-8"))
    for entry in spec["images"]:
        pixels = round(float(entry["size"].split("x")[0]) * int(entry["scale"].rstrip("x")))
        art.resize((pixels, pixels), Image.LANCZOS).save(ICONSET / entry["filename"])
    art.save(ICONSET / "ios-marketing-1024-1.png")
    print(f"Rendered {len(spec['images'])} icons into {ICONSET}")


if __name__ == "__main__":
    main()
