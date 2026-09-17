from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image

EXPECTED_SOURCE_SHA256 = "5a0d653aa640fed37c45b2e181317a161323bdcbb147ad14eb7a55fac81753f2"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    source_path = Path(args.source)
    output = Path(args.output)
    raw = source_path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"RD icon source SHA256 mismatch: {digest}")

    with Image.open(source_path) as source:
        source.verify()
    with Image.open(source_path) as source:
        image = source.convert("RGBA")
        if image.size != (128, 128):
            raise SystemExit(f"Unexpected RD icon source size: {image.size}")
        output.mkdir(parents=True, exist_ok=True)
        image.resize((32, 32), Image.Resampling.LANCZOS).save(output / "32x32.png", optimize=True)
        image.save(output / "128x128.png", optimize=True)
        image256 = image.resize((256, 256), Image.Resampling.LANCZOS)
        image256.save(output / "128x128@2x.png", optimize=True)
        image256.save(output / "icon.png", optimize=True)
        image256.save(
            output / "icon.ico",
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )

    ico = (output / "icon.ico").read_bytes()
    if len(ico) < 4096 or ico[:4] != b"\x00\x00\x01\x00":
        raise SystemExit("Generated RD Drive icon.ico is invalid")

    print(f"Generated RD Drive icon assets from uploaded artwork ({digest}).")


if __name__ == "__main__":
    main()
