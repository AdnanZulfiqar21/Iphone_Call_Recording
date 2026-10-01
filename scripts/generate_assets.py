"""Generates the asset catalog: semantic colour sets (light/dark/increased contrast) and the app icon.
Colour values are the roadmap section 14.12 proposals; contrast is measured by scripts/contrast_check.py."""
import json, os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets")

COLORS = {
    # name: (light, dark, light high-contrast, dark high-contrast)
    "AccentColor":    ("#3B4FD8", "#7C8CFF", "#2A3BB5", "#A3AEFF"),
    "RecordRed":      ("#D92D20", "#FF5A4E", "#B42318", "#FF7A70"),
    "WarningText":    ("#B54708", "#FDB022", "#93370D", "#FEC84B"),
    "WarningFill":    ("#FEF0C7", "#3A2A0A", "#FEDF89", "#4E3510"),
    "PassGreen":      ("#067647", "#47CD89", "#05603A", "#75E0A7"),
    "NeutralUnknown": ("#5D6679", "#98A2B3", "#475467", "#D0D5DD"),
    "AccentFill":     ("#E8EBFF", "#1E2250", "#D6DBFF", "#2A307A"),
    "LaunchBackground": ("#F2F2F7", "#000000", "#F2F2F7", "#000000"),
    # Filled buttons carry white labels, so their fills stay dark enough in every appearance.
    "RecordButtonFill": ("#D92D20", "#C4261A", "#B42318", "#A11E14"),
    "AccentButtonFill": ("#3B4FD8", "#4152D6", "#2A3BB5", "#2F3FB8"),
}

def comp(hexv):
    h = hexv.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return {"color-space": "srgb", "components": {"red": f"0x{r:02X}", "green": f"0x{g:02X}", "blue": f"0x{b:02X}", "alpha": "1.000"}}

def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

write(os.path.join(ROOT, "Contents.json"), {"info": {"author": "xcode", "version": 1}})
for name, (light, dark, hcl, hcd) in COLORS.items():
    write(os.path.join(ROOT, f"{name}.colorset", "Contents.json"), {
        "colors": [
            {"idiom": "universal", "color": comp(light)},
            {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}], "color": comp(dark)},
            {"idiom": "universal", "appearances": [{"appearance": "contrast", "value": "high"}], "color": comp(hcl)},
            {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}, {"appearance": "contrast", "value": "high"}], "color": comp(hcd)},
        ],
        "info": {"author": "xcode", "version": 1},
    })

def icon(bg_top, bg_bottom, ring, dot, path, tinted=False):
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0) if tinted else bg_top)
    if not tinted:
        top, bottom = Image.new("RGB", (1, 2)), None
        grad = Image.new("RGB", (1, size))
        for y in range(size):
            t = y / (size - 1)
            grad.putpixel((0, y), tuple(int(bg_top[i] * (1 - t) + bg_bottom[i] * t) for i in range(3)))
        img = grad.resize((size, size)).convert("RGBA")
    d = ImageDraw.Draw(img)
    c = size // 2
    r_outer, width = 300, 56
    d.ellipse([c - r_outer, c - r_outer, c + r_outer, c + r_outer], outline=ring, width=width)
    r_dot = 170
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([c - r_dot - 30, c - r_dot - 30, c + r_dot + 30, c + r_dot + 30], fill=dot[:3] + (90,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(28)))
    d = ImageDraw.Draw(img)
    d.ellipse([c - r_dot, c - r_dot, c + r_dot, c + r_dot], fill=dot)
    img.save(path)

iconset = os.path.join(ROOT, "AppIcon.appiconset")
os.makedirs(iconset, exist_ok=True)
icon((70, 92, 232), (37, 46, 150), (255, 255, 255, 255), (229, 72, 77, 255), os.path.join(iconset, "AppIcon.png"))
icon((24, 28, 62), (12, 14, 32), (124, 140, 255, 255), (255, 90, 78, 255), os.path.join(iconset, "AppIcon-Dark.png"))
icon((0, 0, 0), (0, 0, 0), (255, 255, 255, 255), (200, 200, 200, 255), os.path.join(iconset, "AppIcon-Tinted.png"), tinted=True)
write(os.path.join(iconset, "Contents.json"), {
    "images": [
        {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-Dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "AppIcon-Tinted.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
    ],
    "info": {"author": "xcode", "version": 1},
})
print("assets generated")
