"""Manifest-driven character production and export. Approval happens only through pick/keep."""
import argparse
import json
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from . import pixel

ROOT = pixel.ROOT
MANIFEST = ROOT / 'cast_manifest.json'
GAME = ROOT.parent


def load():
    return json.loads(MANIFEST.read_text())


def save(manifest):
    from .batch import atomic_write
    atomic_write(MANIFEST, json.dumps(manifest, indent=2) + '\n')


def record_approval(name, candidate=None, animation=None):
    if not MANIFEST.exists():
        return
    manifest = load()
    subject = manifest['subjects'].get(name)
    if not subject:
        return
    if animation:
        if animation not in subject['animations']:
            return
        subject['animations'][animation]['approval'] = 'approved'
        source_meta = ROOT / 'sprites' / name / animation / 'meta.json'
        if source_meta.exists():
            source = json.loads(source_meta.read_text())
            subject['animations'][animation]['source_models'] = source.get('models', {})
            subject['animations'][animation]['source_grid'] = source.get('grid', {})
        pilot = manifest.get('batch_pilot', {})
        if pilot.get('subject') == name and pilot.get('animation') == animation:
            pilot['visual_approval'] = 'approved'
    else:
        subject['approval'] = 'approved'
        subject['candidate'] = candidate
        meta = json.loads((ROOT / 'sprites' / name / 'meta.json').read_text())
        subject.update(canvas=meta['canvas'], anchor=meta['anchor'])
        subject['base_source_model'] = meta.get('model', 'pro')
    save(manifest)
    update_checklists(name, animation)


def update_checklists(name, animation):
    if animation:
        path = ROOT / 'Animations-List.md'
        lines, current = path.read_text().splitlines(), None
        headers = {'## Siya': 'siya', '## Robin': 'robin', '## Raj': 'raj',
                   '### Basic': 'basic-rakshas', '### Ground': 'ground-shooter',
                   '### Brute': 'brute', '### Winged': 'winged-forest-demon',
                   '## Khara': 'khara', '### Body': 'swaminathan', '### Head': 'swaminathan-head'}
        for n, line in enumerate(lines):
            for prefix, value in headers.items():
                if line.startswith(prefix):
                    current = value
            if line.startswith('## Props'):
                current = None
            if current == name and line.startswith('| [ ]') and f'`{animation}`' in line:
                lines[n] = line.replace('| [ ]', '| [x]', 1)
        path.write_text('\n'.join(lines) + '\n')
    else:
        path = ROOT / 'Sprites_List.md'
        lines = path.read_text().splitlines()
        for n, line in enumerate(lines):
            if line.startswith('- [ ]') and f'(`{name}`,' in line:
                lines[n] = line.replace('- [ ]', '- [x]', 1)
        path.write_text('\n'.join(lines) + '\n')


def commands(manifest, base=False, wave=None, names=None, only=None):
    for name, subject in manifest['subjects'].items():
        if names and name not in names:
            continue
        if base:
            if subject['approval'] == 'approved':
                continue
            g = subject['generation']
            argv = ['sprite', name, subject['brief'], '--role', subject['role'],
                    '--height', str(subject['art_px']), '--anchor', subject['anchor_mode'],
                    '--view', subject['view'], '--subject', subject['subject'], '--key', subject['key'],
                    '--size', g['size'], '--model', g['model'], '-n', str(g['candidates']), '--retry', '0']
            argv += ['--jobs', str(g.get('jobs', 3))]
            if g.get('fallback'):
                argv += ['--fallback', g['fallback']]
            for ref in subject['references']:
                argv += ['-r', ref]
            argv += ['--style', *subject['style']]
            if g['batch']:
                argv.append('--batch')
            if only:
                argv += ['--only', only]
            yield argv
        else:
            if subject['approval'] != 'approved':
                continue
            for anim, data in subject['animations'].items():
                if data['approval'] == 'approved' and not only:
                    continue
                if wave and data['wave'] != wave:
                    continue
                g = subject['generation']
                argv = ['frames', name, anim, *data['poses'], '--fps', str(data['fps']),
                        '--loop', data['loop'], '--durations', ','.join(map(str, data['durations'])),
                        '--size', g['size'], '--model', g['model'], '--retry', '0']
                argv += ['--jobs', str(g.get('jobs', 3))]
                if g.get('fallback'):
                    argv += ['--fallback', g['fallback']]
                if g['batch']:
                    argv.append('--batch')
                if data['free_palette']:
                    argv.append('--free-palette')
                if only:
                    argv += ['--only', only]
                yield argv


def prepare(a):
    manifest = load()
    if not a.base and not a.wave:
        raise SystemExit('choose --base or --wave movement|combat|story')
    if a.execute and not a.base:
        from .batch import read_jobs
        jobs = read_jobs()
        pilot = a.wave == 'movement' and a.names == ['siya'] and not jobs
        if not pilot and not any(j['fetched'] and all(i.get('done') for i in j['items']) for j in jobs):
            raise SystemExit('finish and fetch a successful 1K batch pilot before expanding animation production')
    for argv in commands(manifest, a.base, a.wave, a.names, a.only):
        print(shlex.join([sys.executable, '-m', 'ab', *argv]), flush=True)
        if a.execute:
            subprocess.run([sys.executable, '-m', 'ab', *argv], cwd=ROOT, check=True)


def status(a):
    manifest = load()
    sets = frames = bases = 0
    for name, subject in manifest['subjects'].items():
        approved = [d for d in subject['animations'].values() if d['approval'] == 'approved']
        sets += len(approved)
        frames += sum(d['frame_count'] for d in approved)
        bases += subject['approval'] == 'approved'
        print(f"{name:24} base {subject['approval']:8} | {len(approved):2}/{len(subject['animations']):2} sets")
    print(f'{bases}/11 bases, {sets}/73 sets, {frames}/195 frames approved (aliases excluded)')


def animation_data(subject, anim, data):
    folder = ROOT / 'sprites' / subject / anim
    ids = [f'{n:02}' for n in range(1, data['frame_count'] + 1)]
    paths = [folder / f'{i}.png' for i in ids]
    if any(not p.is_file() for p in paths):
        raise ValueError(f'{subject}/{anim}: missing ordered kept frames')
    meta_path = folder / 'meta.json'
    if meta_path.exists():
        meta = json.loads(meta_path.read_text())
        if meta['expected_frames'] != data['frame_count'] or meta['frames'] != ids:
            raise ValueError(f'{subject}/{anim}: frame metadata disagrees with manifest')
        if meta['poses'] != data['poses']:
            raise ValueError(f'{subject}/{anim}: pose metadata disagrees with manifest')
    else:  # previously approved Robin sources predate animation metadata
        meta = json.loads((folder.parent / 'meta.json').read_text())
    images = []
    for path in paths:
        with Image.open(path) as im:
            im = im.convert('RGBA')
            if list(im.size) != meta['canvas'] or not im.getchannel('A').getbbox():
                raise ValueError(f'{subject}/{anim}/{path.name}: wrong canvas or empty image')
            images.append(im.copy())
    return images, meta


def validate(a):
    manifest = load()
    errors = []
    sets = sum(len(s['animations']) for s in manifest['subjects'].values())
    frames = sum(d['frame_count'] for s in manifest['subjects'].values() for d in s['animations'].values())
    if (sets, frames) != (73, 195):
        errors.append(f'manifest totals: {sets} sets, {frames} frames')
    for name, subject in manifest['subjects'].items():
        if a.complete and subject['approval'] != 'approved':
            errors.append(f'{name}: base awaiting approval')
        for anim, data in subject['animations'].items():
            if len(data['poses']) != data['frame_count'] or len(data['durations']) != data['frame_count']:
                errors.append(f'{name}/{anim}: incorrect pose/timing count')
            if data['fps'] <= 0 or any(d <= 0 for d in data['durations']):
                errors.append(f'{name}/{anim}: nonpositive timing')
            if data['approval'] == 'approved':
                try:
                    animation_data(name, anim, data)
                except (ValueError, KeyError, OSError) as e:
                    errors.append(str(e))
            elif a.complete:
                errors.append(f'{name}/{anim}: awaiting approval')
        if a.complete and name in ('khara', 'khara-gada') and subject['attachment']['approval'] != 'approved':
            errors.append(f'{name}: attachment registration awaiting review')
        if a.complete and name == 'khara':
            for anim, data in subject['animations'].items():
                if (len(subject['attachment']['frames'].get(anim, [])) != data['frame_count'] or
                        not all(subject['attachment']['frames'].get(anim, []))):
                    errors.append(f'khara/{anim}: missing hand attachments')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'Cast manifest valid: {sets} sets / {frames} frames; ' + ('complete' if a.complete else 'approved sources checked'))


def common_canvas(sources):
    left = min(-m['anchor'][0] for _, m in sources)
    top = min(-m['anchor'][1] for _, m in sources)
    right = max(m['canvas'][0] - m['anchor'][0] for _, m in sources)
    bottom = max(m['canvas'][1] - m['anchor'][1] for _, m in sources)
    return [right - left, bottom - top], [-left, -top]


def export_subject(name, subject, dest):
    base_meta = json.loads((ROOT / 'sprites' / name / 'meta.json').read_text())
    with Image.open(ROOT / 'sprites' / name / 'sprite.png') as im:
        base = im.convert('RGBA')
    approved = {}
    for anim, data in subject['animations'].items():
        if data['approval'] == 'approved':
            approved[anim] = (*animation_data(name, anim, data), data)
    sources = [([base], base_meta)] + [(ims, meta) for ims, meta, _ in approved.values()]
    canvas, anchor = common_canvas(sources)
    dest.mkdir(parents=True, exist_ok=True)

    def pad(im, meta):
        frame = Image.new('RGBA', canvas)
        frame.paste(im, (anchor[0] - meta['anchor'][0], anchor[1] - meta['anchor'][1]))
        return frame

    pad(base, base_meta).save(dest / 'sprite.png')
    textures = {'base': 'sprite.png'}
    animations = {}
    metadata = {'name': name, 'canvas': canvas, 'anchor': anchor, 'scale': .5,
                'art_pixels_per_unit': 2, 'anchor_mode': subject['anchor_mode'],
                'collider_units': subject['collider_units'], 'animations': {},
                'attachment': subject.get('attachment', {}),
                'view': subject['view'], 'subject': subject['subject'], 'art_px': subject['art_px'],
                'brief': subject['brief'], 'generation': subject['generation'],
                'source': f'asset-builder/sprites/{name}'}
    if name == 'khara-gada' and metadata['attachment'].get('anchor'):
        metadata['attachment'] = dict(metadata['attachment'])
        pivot = metadata['attachment']['anchor']
        metadata['attachment']['anchor'] = [pivot[n] + anchor[n] - base_meta['anchor'][n] for n in range(2)]
    for anim, (images, meta, data) in approved.items():
        folder = dest / anim
        folder.mkdir(exist_ok=True)
        padded = [pad(im, meta) for im in images]
        ids = []
        for n, im in enumerate(padded, 1):
            id_ = f'{anim}_{n:02}'
            textures[id_] = f'{anim}/{n:02}.png'
            ids.append(id_)
            im.save(folder / f'{n:02}.png')
        pixel.strip(padded, folder / 'strip.png')
        pixel.gif(padded, folder / 'preview.gif', ms=[round(d / data['fps'] * 1000) for d in data['durations']], loop=data['loop'] == 'loop')
        exported = {k: data[k] for k in ('fps', 'loop', 'durations', 'poses', 'frame_count')}
        exported.update(canvas=canvas, anchor=anchor, source_canvas=meta['canvas'], source_anchor=meta['anchor'])
        exported['models'] = meta.get('models', {})
        exported['notes'] = data.get('notes', '')
        for key in ('grid', 'sheet'):
            if key in meta:
                exported[key] = meta[key]
        (folder / 'meta.json').write_text(json.dumps(exported, indent=2) + '\n')
        metadata['animations'][anim] = exported
        animations[anim] = (ids, data)
    if not animations:
        animations['base'] = (['base'], {'fps': 8, 'loop': 'none', 'durations': [1.0]})
    for alias, original in subject.get('aliases', {}).items():
        if original in animations:
            ids, data = animations[original]
            data = dict(data)
            if alias == 'talk':
                data.update(fps=5, durations=[1.0] * len(ids))
            animations[alias] = (ids, data)
            metadata['animations'][alias] = {'alias_of': original, 'fps': data['fps'], 'loop': data['loop']}
    metadata['approval'] = 'approved'
    (dest / 'cast_meta.json').write_text(json.dumps(metadata, indent=2) + '\n')
    resource = [f'[gd_resource type="SpriteFrames" load_steps={len(textures)+1} format=3]', '']
    for id_, path in textures.items():
        resource.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/{name}/{path}" id="{id_}"]')
    resource += ['', '[resource]', 'animations = [']
    entries = []
    for anim, (ids, data) in animations.items():
        fs = ', '.join('{"duration": %.6f, "texture": ExtResource("%s")}' % (d, id_) for d, id_ in zip(data['durations'], ids))
        entries.append('{"frames": [' + fs + '], "loop": ' + str(data['loop'] == 'loop').lower() + ', "name": &"' + anim + '", "speed": ' + str(float(data['fps'])) + '}')
    resource += [',\n'.join(entries), ']']
    (dest / 'cast_frames.tres').write_text('\n'.join(resource) + '\n')
    return metadata


def export(a):
    manifest = load()
    validate(argparse.Namespace(complete=a.complete))
    index = {'scale': .5, 'subjects': {}}
    for name, subject in manifest['subjects'].items():
        if subject['approval'] != 'approved':
            index['subjects'][name] = {'approval': 'pending', 'collider_units': subject['collider_units']}
            continue
        dest = GAME / 'assets' / 'sprites' / name
        meta = export_subject(name, subject, dest)
        index['subjects'][name] = {'approval': 'approved', 'frames': f'res://assets/sprites/{name}/cast_frames.tres',
                                  'meta': f'res://assets/sprites/{name}/cast_meta.json', 'animations': list(meta['animations'])}
        print(f'exported {name}: {len(subject["animations"])} planned, {sum(d["approval"] == "approved" for d in subject["animations"].values())} approved sets')
    backgrounds = GAME / 'assets' / 'backgrounds' / 'cast'
    backgrounds.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / 'textures' / 'forest' / 'j1.png', backgrounds / 'forest.png')
    (GAME / 'assets' / 'sprites' / 'cast_index.json').write_text(json.dumps(index, indent=2) + '\n')


def review(a):
    manifest = load()
    review_dir = ROOT / 'out' / 'cast-review'
    review_dir.mkdir(parents=True, exist_ok=True)
    groups = {'raj': ['raj'], 'enemies': ['ground-shooter', 'brute'],
              'boss-components': ['khara', 'khara-gada', 'swaminathan', 'swaminathan-head']}
    if a.wave:
        groups = {a.wave: [n for n, s in manifest['subjects'].items() if any(d['wave'] == a.wave for d in s['animations'].values())]}
    for group, names in groups.items():
        images, labels = [], []
        for name in names:
            if a.wave:
                for anim, data in manifest['subjects'][name]['animations'].items():
                    sheet = ROOT / 'out' / name / anim / 'sheet.png'
                    if data['wave'] == a.wave and sheet.exists():
                        images.append(Image.open(sheet).convert('RGBA'))
                        labels.append(f'{name} / {anim}')
            else:
                for path in sorted((ROOT / 'out' / name).glob('[0-9][0-9].png')):
                    images.append(Image.open(path).convert('RGBA'))
                    labels.append(f'{name} {path.stem}')
        if images:
            pixel.contact_sheet(images, labels, review_dir / f'{group}.png', scale=1 if a.wave else 2, columns=2 if a.wave else 4)
            print(review_dir / f'{group}.png')
    # A row per candidate number, including the original approved cast, at scale 0.5.
    backgrounds = [('forest', ROOT / 'textures/forest/j1.png'), ('title', GAME / 'assets/backgrounds/title_skyline.png')]
    cast = list(manifest['subjects'])
    for bg_name, path in backgrounds:
        bg = Image.open(path).convert('RGB')
        bg.thumbnail((960, 210))
        sheet = Image.new('RGB', (960, 840), '#291931')
        draw = ImageDraw.Draw(sheet)
        for row in range(4):
            sheet.paste(bg, (0, row * 210))
            for col, name in enumerate(cast):
                candidate = ROOT / 'out' / name / f'{row+1:02}.png'
                base = ROOT / 'sprites' / name / 'sprite.png'
                source = candidate if candidate.exists() else base
                if not source.exists():
                    continue
                im = Image.open(source).convert('RGBA')
                meta_path = source.parent / ('run.json' if source == candidate else 'meta.json')
                if meta_path.exists():
                    meta = json.loads(meta_path.read_text())
                    if source == candidate:
                        meta = meta['candidates'][f'{row+1:02}']
                else:  # live generation may still be writing the other candidates
                    meta = {'anchor': pixel.anchor_of(im, manifest['subjects'][name]['anchor_mode'])}
                origin = meta['anchor']
                x, y = 42 + col * 85, row * 210 + 176
                scaled = im.resize((round(im.width*.5), round(im.height*.5)), Image.Resampling.NEAREST)
                sheet.paste(scaled, (x-round(origin[0]*.5), y-round(origin[1]*.5)), scaled)
                draw.text((x-36, row*210+190), f'{name}\n{row+1:02}' if source == candidate else name, fill='#ffca51')
        sheet.save(review_dir / f'lineup-{bg_name}.png')
        print(review_dir / f'lineup-{bg_name}.png')
    review_html(review_dir, manifest)


def review_html(folder, manifest):
    import html
    body = ['<!doctype html><html><meta charset="utf-8"><title>Siyaraj cast review</title>',
            '<style>body{background:#201529;color:#ffd459;font:18px system-ui;margin:24px}img{image-rendering:pixelated;max-width:100%}figure{margin:12px 0}a{color:#4ddcc7}.sets{display:flex;flex-wrap:wrap;gap:24px}.sets img{max-width:420px}h2{margin-top:32px}</style>',
            '<h1>Siyaraj cast review</h1><p>Choose one candidate ID per new subject. Review movement sheets and GIFs before keeping frames.</p>']
    for path in folder.glob('*.png'):
        body.append(f'<figure><figcaption>{html.escape(path.stem)}</figcaption><a href="{path.name}"><img src="{path.name}"></a></figure>')
    body.append('<h2>Animation sheets and GIFs</h2><div class="sets">')
    for name, subject in manifest['subjects'].items():
        for anim in subject['animations']:
            run = ROOT / 'out' / name / anim
            if (run / 'preview.gif').exists():
                prefix = f'../{name}/{anim}'
                body.append(f'<figure><figcaption>{html.escape(name+" / "+anim)}</figcaption><img src="{prefix}/preview.gif"><br><a href="{prefix}/sheet.png">Frame sheet</a></figure>')
    body += ['</div></html>']
    (folder/'index.html').write_text('\n'.join(body)+'\n')
    print(folder / 'index.html')


def attach(a):
    manifest = load()
    subject = manifest['subjects'][a.name]
    if a.name == 'khara-gada':
        subject['attachment'].update(anchor=[a.x, a.y], approval='approved')
    else:
        if not a.anim or a.anim not in subject['animations']:
            raise SystemExit('choose a Khara animation with --anim')
        data = subject['animations'][a.anim]
        entries = subject['attachment']['frames'].setdefault(a.anim, [None] * data['frame_count'])
        if not 1 <= a.frame <= data['frame_count']:
            raise SystemExit('attachment frame is outside the animation')
        entries[a.frame-1] = {'hand_from_anchor_px': [a.x, a.y], 'rotation_degrees': a.rotation,
                            'visible': not getattr(a, 'hide', False)}
        subject['attachment']['approval'] = 'approved' if all(
            len(subject['attachment']['frames'].get(anim, [])) == d['frame_count'] and
            all(subject['attachment']['frames'][anim]) for anim, d in subject['animations'].items()) else 'pending'
    save(manifest)


def import_sheet(a):
    """Import a generated animation sheet with a single declared source grid.

    All cells use the same source pixel spacing; only registration and shared
    padding vary. Sources/provenance are retained and keep remains explicit.
    """
    from .__main__ import load_sprite
    manifest = load()
    subject = manifest['subjects'][a.name]
    if subject['approval'] != 'approved':
        raise SystemExit('pick the base identity before importing its animation sheet')
    selected = [(name, subject['animations'][name]) for name in a.animations]
    total = sum(d['frame_count'] for _, d in selected)
    first_cell = getattr(a, 'start_cell', 0)
    if (a.columns <= 0 or a.rows <= 0 or first_cell < 0 or
            a.columns * a.rows < total + first_cell or a.pixel_size <= 0):
        raise SystemExit('sheet grid must have enough cells and a positive pixel spacing')
    base_meta, base = load_sprite(a.name)
    with Image.open(a.source) as source:
        source = source.convert('RGBA')
    if source.getchannel('A').getextrema()[0] != 0:
        raise SystemExit('sheet must have real alpha transparency')
    owners = {}
    for value in getattr(a, 'effect_owner', []) or []:
        try:
            src, dst = (int(n)-1 for n in value.split(':'))
            if not (0 <= src < total+first_cell and 0 <= dst < total+first_cell):
                raise ValueError()
            owners[src] = dst
        except ValueError:
            raise SystemExit('effect owners must be valid 1-based SOURCE:DESTINATION cells')
    cells = pixel.sheet_cells(source, a.columns, a.rows, total+first_cell, owners)
    spacing = a.pixel_size
    calibration = getattr(a, 'calibration_cell', None)
    if calibration is not None:
        if not 1 <= calibration <= total+first_cell:
            raise SystemExit('calibration cell is outside the sheet')
        cell_image = cells[calibration-1]
        bounds = cell_image.getchannel('A').point(lambda v: 255 if v >= 128 else 0).getbbox()
        if not bounds:
            raise SystemExit('calibration cell is empty')
        # A neutral copy of the approved base calibrates ONE camera grid for the
        # whole sheet. No individual pose is fitted to the original dimensions.
        spacing = (bounds[3]-bounds[1]) / pixel.trim(base).height
    origin = pixel.anchor_of(base, subject['anchor_mode'])
    offset = tuple(origin[n] - base_meta['anchor'][n] for n in range(2))
    cell = first_cell
    for anim, data in selected:
        run = ROOT / 'out' / a.name / anim
        run.mkdir(parents=True, exist_ok=True)
        arts = []
        problems = {}
        for n in range(data['frame_count']):
            cut = cells[cell]
            art = pixel.trim(pixel.snap_fixed(cut, spacing,
                             palette=None if data['free_palette'] else pixel.colours_of(base)))
            bounds = cut.getchannel('A').point(lambda v: 255 if v >= 128 else 0).getbbox()
            if not bounds:
                raise SystemExit(f'{a.name}/{anim}/{n+1}: empty sheet cell')
            if min(bounds[0], bounds[1], cut.width-bounds[2], cut.height-bounds[3]) < spacing:
                problems[f'{n+1:02}'] = ['subject reaches the source sheet edge; inspect clipping']
            arts.append(art)
            cell += 1
        frames, _, canvas, anchor = pixel.place_registered(arts, base_meta['canvas'],
            base_meta['anchor'], subject['anchor_mode'], offset)
        ids = [f'{n+1:02}' for n in range(len(frames))]
        meta = {k: data[k] for k in ('fps', 'loop', 'poses', 'durations', 'free_palette')}
        meta.update(name=a.name, animation=anim, size='sheet', expected_frames=len(frames), frames=ids,
                    canvas=list(canvas), anchor=list(anchor), anchor_mode=subject['anchor_mode'],
                    view=subject['view'], subject=subject['subject'], problems=problems,
                    models={i: a.model for i in ids},
                    grid={'mode': 'uniform', 'source_pixel_spacing': spacing, 'calibration_cell': calibration},
                    sheet={'source': Path(a.source).name, 'dimensions': list(source.size),
                           'columns': a.columns, 'rows': a.rows, 'first_cell': cell-len(frames),
                           'extraction': 'connected subjects on common source canvas',
                           'effect_owners': {str(k+1): v+1 for k, v in owners.items()}})
        shutil.copyfile(a.source, run / 'source-sheet.png')
        if a.prompt:
            shutil.copyfile(a.prompt, run / 'prompt.txt')
        for id_, frame in zip(ids, frames):
            frame.save(run / f'{id_}.png')
        (run / 'meta.json').write_text(json.dumps(meta, indent=2) + '\n')
        (run / 'poses.txt').write_text('\n'.join(data['poses']) + '\n')
        pixel.strip(frames, run / 'strip.png')
        pixel.gif(frames, run / 'preview.gif', ms=[round(d/data['fps']*1000) for d in data['durations']],
                  loop=data['loop']=='loop')
        pixel.contact_sheet([base,*frames], ['base',*ids], run / 'sheet.png', columns=6)
        print(f'imported {a.name}/{anim}: {len(frames)} frames; review then ab keep')


def add_parser(sub):
    p = sub.add_parser('cast', help='prepare, review, validate and export the tracked character library')
    commands_ = p.add_subparsers(dest='action', required=True)
    commands_.add_parser('status').set_defaults(func=status)
    c = commands_.add_parser('prepare', help='print existing ab sprite/frames commands; --execute runs them')
    c.add_argument('--base', action='store_true')
    c.add_argument('--wave', choices=['movement', 'combat', 'story'])
    c.add_argument('--names', nargs='+')
    c.add_argument('--only', help='regenerate these frame/candidate IDs')
    c.add_argument('--execute', action='store_true')
    c.set_defaults(func=prepare)
    c = commands_.add_parser('review')
    c.add_argument('--wave', choices=['movement', 'combat', 'story'])
    c.set_defaults(func=review)
    for name, func in [('validate', validate), ('export', export)]:
        c = commands_.add_parser(name)
        c.add_argument('--complete', action='store_true', help='require all 73 approved sets and 195 frames')
        c.set_defaults(func=func)
    c = commands_.add_parser('attach', help='record reviewed gada pivot or per-frame Khara hand offset in art pixels')
    c.add_argument('name', choices=['khara', 'khara-gada'])
    c.add_argument('--anim')
    c.add_argument('--frame', type=int, default=1)
    c.add_argument('--x', type=int, required=True)
    c.add_argument('--y', type=int, required=True)
    c.add_argument('--rotation', type=float, default=0)
    c.add_argument('--hide', action='store_true', help='hide the gada while hands perform another action')
    c.set_defaults(func=attach)
    c = commands_.add_parser('import-sheet', help='import a generated transparent sheet at one fixed pixel spacing')
    c.add_argument('name')
    c.add_argument('source')
    c.add_argument('--animations', nargs='+', required=True)
    c.add_argument('--columns', type=int, required=True)
    c.add_argument('--rows', type=int, required=True)
    c.add_argument('--pixel-size', type=float, required=True)
    c.add_argument('--start-cell', type=int, default=0, help='skip these initial sheet cells')
    c.add_argument('--calibration-cell', type=int, help='1-based neutral base cell calibrating the whole camera grid')
    c.add_argument('--model', default='imagegen')
    c.add_argument('--effect-owner', action='append', help='reviewed detached effect ownership, 1-based SOURCE:DESTINATION cells')
    c.add_argument('--prompt')
    c.set_defaults(func=import_sheet)
