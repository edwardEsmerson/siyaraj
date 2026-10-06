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


VIEWS = {"right-profile": "facing RIGHT in strict side profile (orthographic side view)",
         "front-three-quarter": "front three-quarter view, facing slightly right",
         "front": "front view, facing the camera"}
SUBJECTS = {"full-body": "full body with feet, hands and props",
            "head": "ONE isolated head and a short neck stub only; no body, hands or shoulders",
            "headless-body": "headless body with feet and all arms; no face, crown or head",
            "prop": "ONE isolated prop only; no character, hand or body"}


def composition(view, subject):
    return f"{VIEWS[view]}. Composition: {SUBJECTS[subject]}."


def sprite(brief, key, roles, px, view="right-profile", subject="full-body"):
    return (f"{background(key)}\n"
            f"Draw ONE pixel-art game sprite: {brief}\n"
            f"Single subject, {composition(view, subject)} Everything fully inside the frame; "
            "the subject's longest side is about 65% of the image, with "
            "empty background all around. Neutral idle pose. "
            f"Pixel art drawn on a {px}x{px} source-pixel grid (each art pixel is a {px}x{px} square block).\n"
            f"{ref_roles(roles)}\n{STYLE}\n{background(key)}")


def frame(name, brief, pose, key, extra_roles=(), view="right-profile", subject="full-body", framing=""):
    roles = [f"the approved sprite of {name}: the identity to keep", *extra_roles]
    return (f"{background(key)}\n"
            f"Redraw the exact subject from attached image 1 in a new pose. {ref_roles(roles)}\n"
            f"Character: {brief}\n"
            f"POSE: {pose}\n"
            "Keep identical: face, hair, outfit, colours, props, outline weight, pixel-block size, body size and "
            f"camera distance. Keep this view and composition: {composition(view, subject)} "
            "Only the pose changes. Keep the entire subject inside "
            "the frame with empty margin. No motion lines, speed trails or extra effects unless the pose asks.\n"
            f"{framing}\n{STYLE}\n{background(key)}")


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
                  "(left edge continues into right edge, top into bottom). It is the inside of a solid platform or "
                  "wall in a side-scroller, seen straight from the side: flat front view, no perspective, no top "
                  "surface, no border, no single object in the centre, even detail density everywhere.")
        bg = ""
    elif mode == "cap":  # the lip drawn along the top edge of every platform, over the fill
        layout = ("A long horizontal pixel-art border strip that runs across the FULL image width, edge to edge, "
                  "horizontally seamless (the left end continues into the right end), centred vertically and about "
                  "a third of the image tall, with flat key colour above and below it. It is the top edge of a "
                  "platform in a side-scroller, side view: the upper third pokes up above the walking surface "
                  "(tufts, ledge lip), the rest hangs down over the platform face with a ragged, irregular bottom "
                  "edge. Detail is evenly spread, no single object, no perspective.")
        bg = background(key) + "\n"
    elif mode == "layer":
        layout = ("A wide side-scrolling parallax background layer. Horizontally seamless: the left edge "
                  "continues into the right edge. Side view, no characters, no UI, no text.")
        bg = ""
    elif mode == "fringe":  # hangs under a platform
        layout = ("A long horizontal pixel-art strip that runs across the FULL image width, edge to edge, "
                  "horizontally seamless (the left end continues into the right end), centred vertically and about "
                  "a third of the image tall, with flat key colour above and below it. It hangs UNDER a floating "
                  "platform in a side-scroller, side view: a straight, solid top edge where it attaches to the "
                  "platform's underside, and a ragged, dangling bottom edge. Evenly spread detail, no perspective.")
        bg = background(key) + "\n"
    elif mode == "piece":  # one isolated terrain piece (platform end cap etc.)
        layout = ("Draw ONE isolated pixel-art game terrain piece, side view, no perspective, centred, about 65% of "
                  "the image, with empty background all around. No characters, no text.")
        bg = background(key) + "\n"
    elif mode == "props":  # many small props on one sheet, split apart afterwards
        layout = ("A pixel-art game prop sheet: 8 to 12 SEPARATE small decorative props, side view, no perspective, "
                  "each standing upright, arranged in a loose grid with wide empty gaps between them (no prop touches "
                  "another or the image edge). All at one consistent game scale: a small clay diya lamp is about 1/20 "
                  "of the image height, a pot about 1/10, the largest prop at most 1/3. No characters, no text, no "
                  "ground, no shadows.")
        bg = background(key) + "\n"
    elif mode == "concept":  # art-direction mock: one framed screen, not seamless
        layout = ("A mock in-game screenshot of a 2D side-scrolling platformer level, 16:9, orthographic side "
                  "view, no perspective, no HUD, no text, no UI. Show the level's terrain kit clearly: a ground "
                  "floor along the bottom, two or three floating platforms at different heights, one tall ledge "
                  "or wall, one thin jump-through platform, decorative props sitting on surfaces, and a calmer "
                  "background behind. Terrain reads clearly against the background; characters stay the "
                  "brightest, most saturated things on screen.")
        bg = ""
    else:  # cutout layer: shapes over a key colour (foreground parallax, props, platforms)
        layout = ("A wide side-scrolling parallax layer of silhouettes/shapes placed over a flat key colour, "
                  "horizontally seamless, side view, no characters, no UI, no text.")
        bg = background(key) + "\n"
    return f"{bg}{layout}\nSubject: {brief}\n{ref_roles(roles)}\n{STYLE}\n{bg}"
