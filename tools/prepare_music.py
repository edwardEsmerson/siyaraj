#!/usr/bin/env python3
"""Rebuild gap-free Ogg playback copies from the supplied MP3 music (requires ffmpeg)."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent / "assets" / "Audio"
# Last audible sample regions measured with ffmpeg silencedetect at -50 dB.
# Keep a 30 ms tail, with 8 ms boundary fades to avoid clicks at the loop seam.
ENDS = {
    "title_menu": 26.088,
    "jungle_exploration": 8.784,
    "stone_ruins_exploration": 9.014,
    "mountain_exploration": 10.389,
    "palace_approach": 64.838,
}


def main():
    destination = ROOT / "music"
    destination.mkdir(exist_ok=True)
    for name, end in ENDS.items():
        filters = f"atrim=end={end},asetpts=PTS-STARTPTS,afade=t=in:d=0.008,afade=t=out:st={end - 0.008}:d=0.008"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                        "-i", str(ROOT / (name + ".mp3")), "-vn", "-af", filters,
                        "-c:a", "libvorbis", "-q:a", "5", str(destination / (name + ".ogg"))], check=True)
    print(f"Prepared {len(ENDS)} music loops in {destination}")


if __name__ == "__main__":
    main()
