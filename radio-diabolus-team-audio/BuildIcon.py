"""Build real multi-resolution Windows icons from the supplied Radio Diabolus art."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent
source = root / "work" / "source"
directories = list(source.glob("SoundSwitch-*/SoundSwitch/Resources"))
if len(directories) != 1:
    raise SystemExit("Expected one SoundSwitch Resources directory")
assets = directories[0]

picture = Image.open(root / "work" / "RDLogo256.jpg")
picture.load()
if picture.size != (256, 256):
    raise SystemExit(f"Unexpected logo dimensions {picture.size}")
picture = picture.convert("RGBA")
icon_path = assets / "Switch-SoundWave.ico"
sizes = [(16,16), (24,24), (32,32), (48,48), (64,64), (128,128), (256,256)]
picture.save(icon_path, format="ICO", sizes=sizes, bitmap_format="png")
picture.save(assets / "RadioDiabolusLogo.png", format="PNG", optimize=True)
with Image.open(icon_path) as check:
    valid = set(check.info.get("sizes", ()))
if not set(sizes).issubset(valid):
    raise SystemExit(f"Multi-resolution icon is incomplete: {valid}")
print("RD icon sizes:", sorted(valid))
