from __future__ import annotations

import argparse
import base64
import hashlib
import string
from pathlib import Path

from PIL import Image

EXPECTED_SOURCE_SHA256 = "3dd310da140ee2c4f769e7ca0708fc41c9bd81ddf0bc2b5cfc99f72b8c4f869d"
BASE64_CHARS = frozenset(string.ascii_letters + string.digits + "+/=")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--carrier", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    carrier = Path(args.carrier)
    output = Path(args.output)
    text = carrier.read_text(encoding="utf-8-sig")
    payload = "".join(ch for ch in text if ch in BASE64_CHARS).rstrip("=")
    payload += "=" * (-len(payload) % 4)
    raw = base64.b64decode(payload, validate=True)
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"RD icon source SHA256 mismatch: {digest}")

    output.mkdir(parents=True, exist_ok=True)
    source_jpg = output / "rd-drive-icon-source.jpg"
    source_jpg.write_bytes(raw)

    with Image.open(source_jpg) as source:
        source.verify()
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
