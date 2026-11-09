#!/usr/bin/env python3
"""Bangun artefak collection (.tar.gz) dari folder collection yang sudah terpasang.

  mkcoll.py [--no-deps] <folder-collection> <output.tar.gz>

Folder boleh punya MANIFEST.json (hasil install/RPM) atau galaxy.yml (source).
FILES.json dan checksum di MANIFEST.json dibuat ulang dari isi folder, jadi
'ansible-galaxy collection install <url>' tidak gagal karena checksum mismatch
(misalnya file yang diubah saat paket RPM dibangun).
--no-deps mengosongkan 'dependencies' supaya install dari URL tidak mencoba
mengunduh collection lain dari Galaxy (lab ujian biasanya offline).
"""
import hashlib
import io
import json
import os
import sys
import tarfile

SKIP = {"MANIFEST.json", "FILES.json"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def collection_info(src):
    man = os.path.join(src, "MANIFEST.json")
    if os.path.isfile(man):
        with open(man) as f:
            return json.load(f)["collection_info"]
    import yaml  # noqa: PLC0415  (hanya dibutuhkan untuk folder source)
    with open(os.path.join(src, "galaxy.yml")) as f:
        g = yaml.safe_load(f)
    keys = ["namespace", "name", "version", "authors", "readme", "tags", "description",
            "license", "license_file", "dependencies", "repository", "documentation",
            "homepage", "issues"]
    info = {k: g.get(k) for k in keys}
    info["authors"] = info["authors"] or []
    info["tags"] = info["tags"] or []
    info["license"] = info["license"] or []
    info["dependencies"] = info["dependencies"] or {}
    return info


def main():
    args = sys.argv[1:]
    no_deps = "--no-deps" in args
    args = [a for a in args if a != "--no-deps"]
    src, out = os.path.abspath(args[0]), args[1]
    info = collection_info(src)
    if no_deps:
        info["dependencies"] = {}
    entries = []   # (rel, "dir"|"file")
    files = [{"name": ".", "ftype": "dir", "chksum_type": None, "chksum_sha256": None, "format": 1}]
    real_src = os.path.realpath(src)

    def inside(path):
        rp = os.path.realpath(path)
        return rp == real_src or rp.startswith(real_src + os.sep)

    # Symlink di dalam collection di-dereference (disalin sebagai file/folder biasa);
    # symlink yang menunjuk ke luar collection dilewati.
    for root, dirs, names in os.walk(src, followlinks=True):
        dirs[:] = sorted(d for d in dirs if d not in {"__pycache__", ".git"} and inside(os.path.join(root, d)))
        rel_root = os.path.relpath(root, src)
        for d in dirs:
            rel = os.path.normpath(os.path.join(rel_root, d))
            files.append({"name": rel, "ftype": "dir", "chksum_type": None, "chksum_sha256": None, "format": 1})
            entries.append((rel, "dir"))
        for n in sorted(names):
            rel = os.path.normpath(os.path.join(rel_root, n))
            full = os.path.join(src, rel)
            if rel in SKIP or n.endswith((".pyc", ".pyo")) or not os.path.isfile(full) or not inside(full):
                continue
            files.append({"name": rel, "ftype": "file", "chksum_type": "sha256",
                          "chksum_sha256": sha256(full), "format": 1})
            entries.append((rel, "file"))
    files_json = json.dumps({"files": files, "format": 1}, indent=2).encode()
    manifest = json.dumps({
        "collection_info": info,
        "file_manifest_file": {"name": "FILES.json", "ftype": "file", "chksum_type": "sha256",
                               "chksum_sha256": hashlib.sha256(files_json).hexdigest(), "format": 1},
        "format": 1}, indent=2).encode()

    def add_bytes(tar, name, data):
        ti = tarfile.TarInfo(name)
        ti.size, ti.mode = len(data), 0o644
        tar.addfile(ti, io.BytesIO(data))

    with tarfile.open(out, "w:gz") as tar:
        add_bytes(tar, "MANIFEST.json", manifest)
        add_bytes(tar, "FILES.json", files_json)
        for rel, kind in entries:
            full = os.path.join(src, rel)
            st = os.stat(full)
            ti = tarfile.TarInfo(rel)
            ti.mtime = int(st.st_mtime)
            if kind == "dir":
                ti.type, ti.mode = tarfile.DIRTYPE, 0o755
                tar.addfile(ti)
            else:
                ti.size = st.st_size
                ti.mode = 0o755 if st.st_mode & 0o111 else 0o644
                with open(full, "rb") as f:
                    tar.addfile(ti, f)
    print("%s.%s %s" % (info["namespace"], info["name"], info["version"]))


if __name__ == "__main__":
    main()
