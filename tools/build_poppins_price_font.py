"""Build Garmin bitmap fonts used throughout the app."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FONT_DIRECTORY = ROOT / "resources" / "fonts"
SOURCE_FONT = FONT_DIRECTORY / "Poppins-SemiBold.ttf"
ATLAS_WIDTH = 512
ATLAS_PADDING = 2
FONT_SIZES = {
    "PoppinsMicro": 10,
    "PoppinsTiny": 12,
    "PoppinsSmall": 16,
    "PoppinsMedium": 24,
    "PoppinsLarge": 34,
    "PoppinsPrice": 46,
}
UI_GLYPHS = "".join(chr(codepoint) for codepoint in range(32, 127)) + "ÅÄÖåäö€"
PRICE_GLYPHS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ- .,€£$¥ÅÄÖåäöre"
GLYPHS_BY_RESOURCE = {
    "PoppinsMicro": UI_GLYPHS,
    "PoppinsTiny": UI_GLYPHS,
    "PoppinsSmall": UI_GLYPHS,
    "PoppinsMedium": PRICE_GLYPHS,
    "PoppinsLarge": PRICE_GLYPHS,
    "PoppinsPrice": PRICE_GLYPHS,
}


def build_font(resource_name, font_size, glyphs):
    """Rasterize the supported glyphs into a packed grayscale atlas."""
    descriptor_file = FONT_DIRECTORY / (resource_name + ".fnt")
    atlas_file = FONT_DIRECTORY / (resource_name + "_0.png")
    font = ImageFont.truetype(str(SOURCE_FONT), font_size)
    ascent, descent = font.getmetrics()
    line_height = ascent + descent

    glyph_records = []
    atlas_x = ATLAS_PADDING
    row_y = ATLAS_PADDING
    for glyph in glyphs:
        bounds = font.getbbox(glyph)
        glyph_width = bounds[2] - bounds[0]
        glyph_height = bounds[3] - bounds[1]
        if atlas_x + glyph_width + ATLAS_PADDING > ATLAS_WIDTH:
            atlas_x = ATLAS_PADDING
            row_y += line_height
        if glyph_width + ATLAS_PADDING * 2 > ATLAS_WIDTH:
            raise ValueError("Poppins glyph is wider than the atlas")

        glyph_records.append(
            {
                "id": ord(glyph),
                "x": atlas_x,
                "y": row_y,
                "width": glyph_width,
                "height": glyph_height,
                "xoffset": bounds[0],
                "yoffset": bounds[1],
                "xadvance": round(font.getlength(glyph)),
            }
        )
        atlas_x += glyph_width + ATLAS_PADDING

    atlas_height = row_y + line_height + ATLAS_PADDING
    atlas = Image.new("L", (ATLAS_WIDTH, atlas_height), 0)
    atlas_draw = ImageDraw.Draw(atlas)
    for glyph, record in zip(glyphs, glyph_records):
        bounds = font.getbbox(glyph)
        atlas_draw.text(
            (record["x"] - bounds[0], record["y"] - bounds[1]),
            glyph,
            font=font,
            fill=255,
        )
    atlas.save(atlas_file)

    descriptor_lines = [
        'info face="Poppins SemiBold" size=-{} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0'.format(font_size),
        "common lineHeight={} base={} scaleW={} scaleH={} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0".format(
            line_height, ascent, ATLAS_WIDTH, atlas_height
        ),
        'page id=0 file="{}"'.format(atlas_file.name),
        "chars count={}".format(len(glyph_records)),
    ]
    for glyph in glyph_records:
        descriptor_lines.append(
            "char id={id} x={x} y={y} width={width} height={height} xoffset={xoffset} yoffset={yoffset} xadvance={xadvance} page=0 chnl=15".format(
                **glyph
            )
        )
    descriptor_lines.append("kernings count=0")
    descriptor_file.write_text("\n".join(descriptor_lines) + "\n", encoding="ascii")


def main():
    """Build the Poppins sizes used by current-price and graph screens."""
    for resource_name, font_size in FONT_SIZES.items():
        build_font(resource_name, font_size, GLYPHS_BY_RESOURCE[resource_name])


if __name__ == "__main__":
    main()