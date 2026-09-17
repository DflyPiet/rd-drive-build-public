from __future__ import annotations

import argparse
import base64
import hashlib
from pathlib import Path

from PIL import Image

EXPECTED_SOURCE_SHA256 = "c200e53c142797582b93973d05d30e9c02055f34758c741e26dc62dd2d178e3d"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--carrier", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    carrier = Path(args.carrier)
    output = Path(args.output)
    payload = "".join(carrier.read_text(encoding="ascii").split())
    raw = base64.b64decode(payload, validate=True)
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"RD icon source SHA256 mismatch: {digest}")

    output.mkdir(parents=True, exist_ok=True)
    source_jpg = output / "rd-drive-icon-source.jpg"
    source_jpg.write_bytes(raw)

    with Image.open(source_jpg) as source:
        image = source.convert("RGBA")
        image.resize((32, 32), Image.Resampling.LANCZOS).save(output / "32x32.png", optimize=True)
        image.resize((128, 128), Image.Resampling.LANCZOS).save(output / "128x128.png", optimize=True)
        image.resize((256, 256), Image.Resampling.LANCZOS).save(output / "128x128@2x.png", optimize=True)
        image.resize((256, 256), Image.Resampling.LANCZOS).save(output / "icon.png", optimize=True)
        image.save(
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
