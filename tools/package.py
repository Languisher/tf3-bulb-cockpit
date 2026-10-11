"""Build a deterministic installable archive using the repository VERSION."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    version = (ROOT / "VERSION").read_text().strip()
    match = re.fullmatch(r"0\.1\.(\d+)dev", version)
    if not match:
        raise SystemExit("Expected VERSION format 0.1.<revision>dev")
    metadata = json.loads((ROOT / "mod/mod.json").read_text())
    if metadata["revision"] != int(match[1]):
        raise SystemExit("VERSION and game revision disagree")
    destination = ROOT / "dist"
    destination.mkdir(exist_ok=True)
    archive = destination / f"tf3-bulb-cockpit-{version}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for path in sorted((ROOT / "mod").rglob("*")):
            if not path.is_file() or path.name == ".DS_Store" or "__pycache__" in path.parts:
                continue
            entry = zipfile.ZipInfo("linnan_bulb_cockpit/" + path.relative_to(ROOT / "mod").as_posix(),
                                    date_time=(2026, 10, 11, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            output.writestr(entry, path.read_bytes())
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (destination / "SHA256SUMS").write_text(f"{checksum}  {archive.name}\n")
    print(archive)
    print(checksum)


if __name__ == "__main__":
    main()
