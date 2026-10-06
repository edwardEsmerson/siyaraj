import argparse
import base64
import io
import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from PIL import Image

from ab import batch, cast, pixel, prompts
from ab import __main__ as cli


class GeometryChecks(unittest.TestCase):
    def test_reviewed_detached_projectile_stays_with_throwing_actor(self):
        sheet = Image.new('RGBA', (200, 100))
        sheet.paste(Image.new('RGBA', (20, 60), 'red'), (30, 20))
        sheet.paste(Image.new('RGBA', (20, 60), 'blue'), (150, 20))
        sheet.paste(Image.new('RGBA', (10, 8), 'yellow'), (130, 40))
        first, second = pixel.sheet_cells(sheet, 2, 1, 2, {1: 0})
        self.assertEqual(first.getpixel((134, 44)), (255, 255, 0, 255))
        self.assertEqual(second.getpixel((134, 44))[3], 0)
        self.assertEqual(second.getpixel((155, 44)), (0, 0, 255, 255))

    def test_sheet_extraction_retains_weapon_crossing_a_cell_boundary(self):
        sheet = Image.new('RGBA', (200, 100))
        sheet.paste(Image.new('RGBA', (20, 60), 'red'), (40, 20))
        sheet.paste(Image.new('RGBA', (80, 5), 'red'), (60, 30))
        sheet.paste(Image.new('RGBA', (20, 60), 'blue'), (170, 20))
        first, second = pixel.sheet_cells(sheet, 2, 1, 2)
        self.assertEqual(first.size, sheet.size)
        self.assertEqual(first.getchannel('A').getbbox(), (40, 20, 140, 80))
        self.assertEqual(first.getpixel((175, 30))[3], 0)
        self.assertEqual(second.getchannel('A').getbbox(), (170, 20, 190, 80))

    def test_uniform_source_grid_keeps_camera_scale_despite_pose_edges(self):
        cut = Image.new('RGBA', (1024, 1024))
        cut.paste(Image.new('RGBA', (128, 640), '#feba42'), (256, 192))
        cut.paste(Image.new('RGBA', (320, 40), '#174738'), (384, 320))
        sampled = pixel.snap_fixed(cut, 8, palette=['feba42', '174738'])
        self.assertEqual(sampled.size, (128, 128))
        self.assertEqual(sampled.getchannel('A').getbbox(), (32, 24, 88, 104))
        self.assertEqual(sampled.getpixel((87, 44)), (23, 71, 56, 255))

    def test_forbidden_key_residue_is_removed_without_erasing_turquoise(self):
        raw = Image.new('RGB', (96, 96), (0, 255, 0))
        raw.paste(Image.new('RGB', (32, 64), (10, 170, 175)), (32, 16))
        raw.putpixel((25, 25), (40, 190, 30))
        cut, _ = pixel.remove_background(raw, key=(0, 255, 0))
        self.assertEqual(cut.getpixel((25, 25))[3], 0)
        self.assertEqual(cut.getpixel((48, 48)), (10, 170, 175, 255))

    def test_capacity_fallback_honours_attempt_counts_and_provenance(self):
        calls = []
        error = RuntimeError('capacity')
        error.code = 429
        def generate(prompt, refs, model, size, aspect, **kwargs):
            calls.append((model, kwargs['attempts']))
            if model == 'pro-model':
                raise error
            return [b'image']
        gen = SimpleNamespace(generate=generate, MODELS={'flash': 'flash-model'})
        args = SimpleNamespace(fallback='flash', size='1K', primary_attempts=2, api_attempts=4)
        result = cli.generate_in_slot(gen, args, {'id':'01', 'model':'pro-model', 'prompt':'pose', 'refs':[]})
        self.assertEqual(calls, [('pro-model', 2), ('flash-model', 4)])
        self.assertEqual(result, (b'image', 'flash-model'))

    def test_old_2k_sprite_reference_follows_requested_1k(self):
        for size, width in [('1K', 1024), ('4K', 4096)]:
            with Image.open(io.BytesIO(cli.sprite_ref('siya', 'green', size))) as im:
                self.assertEqual(im.width, width)
                self.assertEqual(im.height, width)

    def test_batch_resolution_is_resolved_before_reference_loading(self):
        args = cli.parser().parse_args(['sprite', 'test', 'test', '--batch', '--size', '2K'])
        with patch.object(cli, 'ref_bytes', side_effect=AssertionError('reference loaded')):
            with self.assertRaisesRegex(SystemExit, '1K only'):
                cli.cmd_sprite(args)
        args.size = None
        self.assertEqual(cli.resolve_size(args, '4K'), '1K')

    def test_expanded_ground_poses_keep_feet_and_pixel_size(self):
        arts = [Image.new('RGBA', (20, 40), 'red'), Image.new('RGBA', (150, 30), 'blue'),
                Image.new('RGBA', (32, 120), 'green')]
        frames, _, canvas, anchor = pixel.place_registered(arts, (80, 80), (40, 75))
        self.assertEqual(len({f.size for f in frames}), 1)
        self.assertEqual(canvas, (150, 125))
        for art, frame in zip(arts, frames):
            box = frame.getchannel('A').getbbox()
            self.assertEqual(box[3], anchor[1])
            self.assertEqual((box[2]-box[0], box[3]-box[1]), art.size)

    def test_expanded_flying_poses_keep_center(self):
        arts = [Image.new('RGBA', (20, 20), 'red'), Image.new('RGBA', (180, 130), 'blue')]
        frames, _, _, anchor = pixel.place_registered(arts, (80, 80), (40, 40), 'center')
        for frame in frames:
            box = frame.getchannel('A').getbbox()
            self.assertEqual(((box[0]+box[2])//2, (box[1]+box[3])//2), anchor)

    def test_extended_weapon_does_not_move_grounded_body_sideways(self):
        neutral = Image.new('RGBA', (20, 40), 'red')
        swing = Image.new('RGBA', (100, 40))
        swing.paste(neutral, (0, 0))
        swing.paste(Image.new('RGBA', (80, 5), 'blue'), (20, 10))
        frames, _, _, anchor = pixel.place_registered([neutral, swing], (80, 80), (40, 75))
        for frame in frames:
            self.assertEqual(pixel.anchor_of(frame), anchor)
            self.assertEqual(frame.getpixel((anchor[0], anchor[1]-1)), (255, 0, 0, 255))

    def test_component_prompts_never_force_full_body_or_profile(self):
        prompt = prompts.sprite('king head', 'green', [], 8, 'front-three-quarter', 'head')
        self.assertIn('isolated head', prompt)
        self.assertNotIn('strict side profile', prompt)
        frame = prompts.frame('king', 'headless', 'arms raised', 'blue', [], 'front-three-quarter', 'headless-body')
        self.assertIn('headless body', frame)
        self.assertNotIn('Same right-facing', frame)

    def test_only_keeps_other_cached_raws(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            for n in range(1, 4):
                (folder / f'{n:02}.raw.png').write_bytes(bytes([n]))
            cli.prepare(folder, ['2'], 3)
            self.assertEqual((folder/'01.raw.png').read_bytes(), b'\x01')
            self.assertFalse((folder/'02.raw.png').exists())
            self.assertEqual((folder/'03.raw.png').read_bytes(), b'\x03')

    def test_eight_fps_gif_keeps_total_cycle_time_and_once_policy(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'preview.gif'
            frames = [Image.new('RGBA', (8, 8), color) for color in ('red', 'blue', 'green', 'yellow')]
            pixel.gif(frames, path, ms=125, loop=False)
            with Image.open(path) as im:
                duration = 0
                for n in range(im.n_frames):
                    im.seek(n)
                    duration += im.info['duration']
                self.assertEqual(duration, 500)
                self.assertNotIn('loop', im.info)


class BatchChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmp.name)
        self.patches = [patch.object(batch, 'DIR', self.folder), patch.object(batch, 'QUEUE', self.folder/'queue.jsonl'),
                        patch.object(batch, 'JOBS', self.folder/'jobs.json')]
        for p in self.patches:
            p.start()
        self.charges = []
        self.gen = SimpleNamespace(MODELS={'pro': 'pro-model', 'flash': 'flash-model'}, DEFAULT_PROJECT='test',
                                   BUDGET_INR=25000, spent_inr=lambda: 0, price_inr=lambda m, s: 12,
                                   _ledger=lambda cost: self.charges.append(cost))

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.tmp.cleanup()

    def item(self, n, model='pro-model'):
        return {'raw': str(self.folder/f'{n}.raw.png'), 'model': model, 'size': '1K', 'aspect': '1:1',
                'prompt': f'pose {n}', 'refs': [], 'argv': ['sprite', 'test', 'brief', '--batch'], 'cwd': str(self.folder)}

    def test_submit_resumes_after_second_lane_failure_without_resubmitting_first(self):
        items = [self.item(1), self.item(2, 'flash-model')]
        batch.write_queue(items)
        create = unittest.mock.Mock(side_effect=[SimpleNamespace(name='job-pro', state=SimpleNamespace(name='JOB_STATE_RUNNING')), RuntimeError('outage')])
        self.gen.client = lambda: SimpleNamespace(batches=SimpleNamespace(create=create))
        with patch.object(batch, 'storage'):
            with self.assertRaisesRegex(RuntimeError, 'outage'):
                batch.submit(SimpleNamespace(model=None), self.gen)
            self.assertEqual(len(batch.read_jobs()), 1)
            self.assertEqual(batch.read_queue(), [items[1]])
            create.side_effect = [SimpleNamespace(name='job-flash', state=None)]
            batch.submit(SimpleNamespace(model=None), self.gen)
        self.assertEqual(len(batch.read_jobs()), 2)
        self.assertEqual(batch.read_queue(), [])
        self.assertEqual(self.charges, [6, 6])

    def test_download_failure_remains_retryable_and_preserves_completed_raw(self):
        item = self.item(1)
        Path(item['raw']).write_bytes(b'previously-downloaded')
        item['done'] = True
        job = {'name': 'job', 'tag': 'unique', 'model': 'pro-model', 'fetched': False,
               'state': 'JOB_STATE_SUCCEEDED', 'items': [item, self.item(2)], 'bucket': 'gs://test'}
        batch.write_jobs([job])
        with patch.object(batch, 'refresh', side_effect=lambda g, js: js), patch.object(batch, 'storage', side_effect=subprocess.CalledProcessError(1, ['gcloud'])):
            batch.fetch(None, self.gen)
        self.assertFalse(batch.read_jobs()[0]['fetched'])
        self.assertEqual(Path(item['raw']).read_bytes(), b'previously-downloaded')
        self.assertEqual(self.charges, [])

    def test_partial_fetch_retains_successes_and_does_not_refund_missing_rows(self):
        job = {'name': 'job', 'tag': 'unique', 'model': 'pro-model', 'fetched': False,
               'state': 'JOB_STATE_SUCCEEDED', 'items': [self.item(1), self.item(2)], 'bucket': 'gs://test'}
        batch.write_jobs([job])
        output = self.folder/'unique/out'
        output.mkdir(parents=True)
        buffer = io.BytesIO()
        Image.new('RGB', (4, 4), 'red').save(buffer, 'PNG')
        row = {'request': batch.request(job['items'][0], 'gs://test', 'r0'),
               'response': {'candidates': [{'content': {'parts': [{'inlineData': {'data': base64.b64encode(buffer.getvalue()).decode()}}]}}]}}
        (output/'results.jsonl').write_text(json.dumps(row)+'\n')
        with patch.object(batch, 'refresh', side_effect=lambda g, js: js), patch.object(batch, 'storage'):
            batch.fetch(None, self.gen)
            self.assertFalse(batch.read_jobs()[0]['fetched'])
            self.assertTrue(batch.read_jobs()[0]['items'][0]['done'])
            row2 = {'request': batch.request(job['items'][1], 'gs://test', 'r1'), 'status': {'code': 3, 'message': 'rejected'}}
            with (output/'results.jsonl').open('a') as f:
                f.write(json.dumps(row2)+'\n')
            batch.fetch(None, self.gen)
            self.assertTrue(batch.read_jobs()[0]['fetched'])
            batch.fetch(None, self.gen)
        self.assertEqual(self.charges, [-6])
        self.assertTrue(Path(job['items'][0]['raw']).exists())

    def test_batch_request_rejects_legacy_2k_queue(self):
        item = self.item(1)
        item['size'] = '2K'
        with self.assertRaisesRegex(ValueError, '1K only'):
            batch.request(item, 'gs://test', 'r0')

    def test_only_can_resubmit_a_previously_completed_frame(self):
        item = self.item(1)
        old = dict(item, done=True)
        batch.write_jobs([{'fetched': True, 'items': [old]}])
        batch.write_queue([item])
        create = unittest.mock.Mock(return_value=SimpleNamespace(name='redo', state=None))
        self.gen.client = lambda: SimpleNamespace(batches=SimpleNamespace(create=create))
        with patch.object(batch, 'storage'):
            batch.submit(SimpleNamespace(model=None), self.gen)
        self.assertEqual(create.call_count, 1)
        self.assertEqual(len(batch.read_jobs()), 2)
        self.assertEqual(batch.read_queue(), [])


class ManifestChecks(unittest.TestCase):
    def test_scope_and_existing_robin_identity(self):
        manifest = cast.load()
        self.assertEqual(sum(cast.library(a) for s in manifest['subjects'].values() for a in s['animations'].values()), 73)
        self.assertEqual(sum(a['frame_count'] for s in manifest['subjects'].values() for a in s['animations'].values() if cast.library(a)), 195)
        self.assertEqual(manifest['subjects']['robin']['art_px'], 48)
        self.assertEqual(manifest['subjects']['robin']['animations']['fly']['fps'], 10)
        cast.validate(SimpleNamespace(complete=False))

    def test_export_uses_common_canvas_and_valid_resource_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp)/'robin'
            meta = cast.export_subject('robin', cast.load()['subjects']['robin'], dest)
            self.assertIn('talk', meta['animations'])
            self.assertEqual('point' in meta['animations'],
                             cast.load()['subjects']['robin']['animations']['hint']['approval'] == 'approved')
            self.assertEqual(meta['scale'], .5)
            resource = (dest/'cast_frames.tres').read_text()
            self.assertIn('"speed": 10.0', resource)
            for anim in ['fly', 'perch']:
                for path in (dest/anim).glob('[0-9][0-9].png'):
                    with Image.open(path) as im:
                        self.assertEqual(list(im.size), meta['canvas'])
            self.assertTrue((dest/'fly/strip.png').exists())
            self.assertTrue((dest/'fly/preview.gif').exists())

    def test_incomplete_keep_does_not_replace_approved_sources(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(cli, 'OUT', Path(tmp)):
            folder = Path(tmp)/'robin/hover'
            folder.mkdir(parents=True)
            (folder/'meta.json').write_text(json.dumps({'expected_frames': 2, 'frames': ['01']}))
            with self.assertRaisesRegex(SystemExit, 'incomplete'):
                cli.cmd_keep(SimpleNamespace(name='robin', anim='hover'))

    def test_complete_export_checks_all_195_paths_and_timing_policies(self):
        # Synthetic art stays in a temporary fixture; approval logic is exercised on all requested sets.
        manifest = cast.load()
        with tempfile.TemporaryDirectory() as tmp:
            game = Path(tmp)
            root = game / 'asset-builder'
            root.mkdir()
            for name, subject in manifest['subjects'].items():
                subject['approval'] = 'approved'
                folder = root/'sprites'/name
                folder.mkdir(parents=True)
                image = Image.new('RGBA', (32, 32))
                image.paste(Image.new('RGBA', (10, 20), 'red'), (11, 10))
                image.save(folder/'sprite.png')
                base_meta = {'canvas': [32, 32], 'anchor': [16, 30]}
                (folder/'meta.json').write_text(json.dumps(base_meta))
                for anim, data in subject['animations'].items():
                    data['approval'] = 'approved'
                    frames = folder/anim
                    frames.mkdir()
                    ids = [f'{n:02}' for n in range(1, data['frame_count']+1)]
                    meta = dict(base_meta, expected_frames=data['frame_count'], frames=ids, poses=data['poses'])
                    (frames/'meta.json').write_text(json.dumps(meta))
                    for id_ in ids:
                        image.save(frames/f'{id_}.png')
                if name in ('khara', 'khara-gada'):
                    subject['attachment']['approval'] = 'approved'
                if name == 'khara':
                    subject['attachment']['frames'] = {anim: [{'hand_from_anchor_px': [0, -20], 'rotation_degrees': 0}]*data['frame_count'] for anim, data in subject['animations'].items()}
                if name == 'khara-gada':
                    subject['attachment']['anchor'] = [16, 30]
            (root/'textures/forest').mkdir(parents=True)
            Image.new('RGB', (16, 16), 'blue').save(root/'textures/forest/j1.png')
            path = root/'cast_manifest.json'
            path.write_text(json.dumps(manifest))
            with patch.object(cast, 'ROOT', root), patch.object(cast, 'GAME', game), patch.object(cast, 'MANIFEST', path):
                cast.export(SimpleNamespace(complete=True))
            total = 0
            for name, subject in manifest['subjects'].items():
                folder = game/'assets/sprites'/name
                resource = (folder/'cast_frames.tres').read_text()
                for path_ in re.findall(r'path="res://([^"]+)"', resource):
                    self.assertTrue((game/path_).is_file(), path_)
                for anim, data in subject['animations'].items():
                    self.assertEqual(len(list((folder/anim).glob('[0-9][0-9].png'))), data['frame_count'])
                    total += data['frame_count']
                    self.assertIn(f'"name": &"{anim}"', resource)
                    if not cast.library(data):
                        total -= data['frame_count']
                if name == 'robin':
                    self.assertIn('"name": &"point"', resource)
                    self.assertIn('"name": &"talk"', resource)
            self.assertEqual(total, 195)
            head_resource = (game/'assets/sprites/swaminathan-head/cast_frames.tres').read_text()
            self.assertRegex(head_resource, r'"loop": false, "name": &"faces"')
            khara_meta = json.loads((game/'assets/sprites/khara/cast_meta.json').read_text())
            slam = khara_meta['animations']['slam_windup']
            self.assertAlmostEqual(sum(slam['durations'])/slam['fps'], .85)


if __name__ == '__main__':
    unittest.main()
