import base64
import hashlib
import os
from pathlib import Path

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = ROOT / "payload-usability"
OUT = ROOT / "rd-drive-usability-source.tar.xz"

raw_secret = os.environ.get("RD_BUILD_KEY", "")
if len(raw_secret) != 64:
    raise SystemExit("RD_BUILD_KEY missing or invalid")
secret = bytes.fromhex(raw_secret)

parts = sorted(PAYLOAD.glob("usability.enc.b64.*"))
if not parts:
    raise SystemExit("encrypted usability payload missing")
b64 = "".join(p.read_text().strip() for p in parts)
blob = base64.b64decode(b64, validate=True)

expected_cipher = (PAYLOAD / "usability.enc.sha256").read_text().strip().split()[0].lower()
actual_cipher = hashlib.sha256(blob).hexdigest()
if actual_cipher != expected_cipher:
    raise SystemExit(f"cipher SHA256 mismatch: {actual_cipher}")

if len(blob) < 4 + 32 + 12 + 16 or blob[:4] != b"RDX1":
    raise SystemExit("invalid encrypted source envelope")
ephemeral_public = X25519PublicKey.from_public_bytes(blob[4:36])
nonce = blob[36:48]
ciphertext = blob[48:]

seed = hashlib.sha256(secret + b"RD-DRIVE-X25519-v1").digest()
private = X25519PrivateKey.from_private_bytes(seed)
shared = private.exchange(ephemeral_public)
key = HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=b"RD-DRIVE-USABILITY-v1").derive(shared)
plain = AESGCM(key).decrypt(nonce, ciphertext, b"RD-DRIVE-USABILITY-v1")
OUT.write_bytes(plain)
print("decrypted_source_sha256=" + hashlib.sha256(plain).hexdigest())