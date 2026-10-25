"""Generate Windows icons from the user-supplied Radio Diabolus symbol."""
from pathlib import Path
from io import BytesIO
from PIL import Image
import base64

repo = Path(__file__).resolve().parents[1]
app = repo / 'mirall-src'
data = (repo / 'teamshare-build/branding/icon128.b64').read_text().strip()
image = Image.open(BytesIO(base64.b64decode(data))).convert('RGBA')
if image.size != (128, 128):
    raise SystemExit('Wrong Radio Diabolus icon dimensions')
def png(size, where):
    path = app / where
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size,size), Image.Resampling.LANCZOS).save(path,format='PNG')
def ico(where):
    path = app / where
    path.parent.mkdir(parents=True,exist_ok=True)
    image.resize((256,256),Image.Resampling.LANCZOS).save(
        path,format='ICO',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
png(128,'assets/brand/radio-diabolus-icon.png')
ico('resources/win32/icon.ico')
ico('resources/tray/tray.ico')
png(32,'resources/tray/tray.png')
png(64,'resources/tray/tray@2x.png')
png(256,'resources/linux/icon.png')
for size in [16,32,48,64,128,256]:
    png(size, f'resources/linux/icons/{size}x{size}.png')
assets = [
(150,'Square150x150Logo.png'),(44,'Square44x44Logo.png'),
(71,'Square71x71Logo.png'),(256,'StoreLogo.png')]
for size in (16,24,32,48,256):
    for suffix in ('','_altform-unplated'):
        assets.append((size,f'Square44x44Logo.targetsize-{size}{suffix}.png'))
for size,name in assets:
    png(size, 'resources/win32/msix-assets/'+name)
print('Radio Diabolus icon generated for Windows EXE, tray and resources')
