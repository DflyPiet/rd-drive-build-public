import base64
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
raw = base64.b64decode((root / 'ci' / 'rd-drive-icon.jpg.b64').read_text().strip(), validate=True)
asset_dir = root / 'source' / 'src' / 'assets'
public_dir = root / 'source' / 'public'
icons_dir = root / 'source' / 'src-tauri' / 'icons'
asset_dir.mkdir(parents=True, exist_ok=True)
public_dir.mkdir(parents=True, exist_ok=True)
icons_dir.mkdir(parents=True, exist_ok=True)
jpg = asset_dir / 'rd-drive-icon.jpg'
jpg.write_bytes(raw)
img = Image.open(jpg).convert('RGBA')
img.resize((512,512), Image.Resampling.LANCZOS).save(public_dir / 'rd-drive-icon.png')
for size in (32,128,256):
    img.resize((size,size), Image.Resampling.LANCZOS).save(icons_dir / f'{size}x{size}.png')
img.resize((256,256), Image.Resampling.LANCZOS).save(icons_dir / 'icon.ico', format='ICO', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
print('rd_drive_icons_ready')