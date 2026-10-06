"""All prompt text lives here so it's easy to tune in one place."""

KEYS = {"green": (0, 255, 0), "magenta": (255, 0, 255), "blue": (0, 0, 255)}
KEY_WORDS = {"green": "pure green #00FF00", "magenta": "pure magenta #FF00FF", "blue": "pure blue #0000FF"}

STYLE = (
    "Style: Siyaraj, a playful Indian Diwali 2D side-scrolling pixel-art platformer. Clean folk-art shapes, "
    "readable silhouette, comic expression. Hot pink, turquoise and marigold accents, deep aubergine "
    "outlines, two or three flat shading tones per material, sparse simplified rangoli / truck-art / "
    "Madhubani motifs. Crisp square pixels: no anti-aliasing, gradients, blur, painterly texture, glow or dithering noise."
)


def background(key):
    word = KEY_WORDS[key]
    return (f"BACKGROUND: the entire background is one flat solid {word} colour, every background pixel identical. "
            "No checkerboard or transparency pattern, no floor, ground line, cast shadow, scenery, vignette, "
            f"frame or text. Do not use {key} anywhere on the subject.")


def ref_roles(roles):
    if not roles:
        return ""
    lines = [f"Attached image {i}: {role}." for i, role in enumerate(roles, 1)]
    return " ".join(lines) + " Never copy a reference's background, scene, lighting or rendering style. "


def sprite(brief, key, roles, px):
    return (f"{background(key)}\n"
            f"Draw ONE pixel-art game sprite: {brief}\n"
            "Single subject, facing RIGHT in strict side profile (orthographic side view), full body with feet, "
            "hands and props fully inside the frame; the subject's longest side is about 65% of the image, with "
            "empty background all around. Neutral idle pose. "
            f"Pixel art drawn on a {px}x{px} source-pixel grid (each art pixel is a {px}x{px} square block).\n"
            f"{ref_roles(roles)}\n{STYLE}\n{background(key)}")


def frame(name, brief, pose, key, extra_roles=()):
    roles = [f"the approved sprite of {name}: the identity to keep", *extra_roles]
    return (f"{background(key)}\n"
            f"Redraw the exact character from attached image 1 in a new pose. {ref_roles(roles)}\n"
            f"Character: {brief}\n"
            f"POSE: {pose}\n"
            "Keep identical: face, hair, outfit, colours, props, outline weight, pixel-block size, body size and "
            "camera distance. Same right-facing side view. Only the pose changes. Keep the whole body inside "
            "the frame with empty margin. No motion lines, speed trails or extra effects unless the pose asks.\n"
            f"{STYLE}\n{background(key)}")


def ui(brief, key, roles, kind):
    if kind == "frame":
        layout = ("Draw ONE flat pixel-art game UI frame, seen straight-on (front view, no perspective, no drop "
                  "shadow): a single rectangular panel centred in the image, about 75% of the image wide, with empty "
                  "background all around. All four corners carry the same ornament (mirror-symmetric left/right and "
                  "top/bottom). Between the corners each straight edge is a plain uniform border band that looks the "
                  "same along its whole length, so the frame can be stretched to any size. The interior is ONE flat "
                  "solid colour with no pattern. No text, letters, numbers or icons.")
    else:
        layout = ("Draw ONE small flat pixel-art game UI icon, front view, centred, about 65% of the image, with "
                  "empty background all around. Bold silhouette that stays readable at a tiny size. No text.")
    return f"{background(key)}\n{layout}\nSubject: {brief}\n{ref_roles(roles)}\n{STYLE}\n{background(key)}"


def texture(brief, key, roles, mode):
    if mode == "tile":
        layout = ("A seamless, tileable square pixel-art texture that fills the ENTIRE image edge to edge "
                  "(left edge continues into right edge, top into bottom). Flat game-texture view, no perspective, "
                  "no border, no single object in the centre.")
        bg = ""
    elif mode == "layer":
        layout = ("A wide side-scrolling parallax background layer. Horizontally seamless: the left edge "
                  "continues into the right edge. Side view, no characters, no UI, no text.")
        bg = ""
    else:  # cutout layer: shapes over a key colour (foreground parallax, props, platforms)
        layout = ("A wide side-scrolling parallax layer of silhouettes/shapes placed over a flat key colour, "
                  "horizontally seamless, side view, no characters, no UI, no text.")
        bg = background(key) + "\n"
    return f"{bg}{layout}\nSubject: {brief}\n{ref_roles(roles)}\n{STYLE}\n{bg}"
