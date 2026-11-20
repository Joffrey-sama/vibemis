#!/usr/bin/env python3
"""Merge QSettings INI overlay files into Vibemis.conf without mangling raw Qt values."""

from __future__ import annotations

import os
import sys
import tempfile
from collections import OrderedDict


def parse_qsettings_ini(path: str) -> OrderedDict[str, OrderedDict[str, str]]:
    """Parse a QSettings INI file preserving section order, backslashes, and raw values."""
    sections: OrderedDict[str, OrderedDict[str, str]] = OrderedDict()
    current_section = ""

    if not os.path.exists(path):
        return sections

    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\r\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith(";"):
                continue
            if stripped.startswith("[") and stripped.endswith("]"):
                current_section = stripped[1:-1]
                sections.setdefault(current_section, OrderedDict())
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                sections.setdefault(current_section, OrderedDict())[key] = value

    return sections


def write_qsettings_ini(
    path: str,
    sections: OrderedDict[str, OrderedDict[str, str]],
    mode: int = 0o600,
) -> None:
    """Atomically write sections back in QSettings INI format."""
    parent = os.path.dirname(path) or "."
    os.makedirs(parent, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(prefix=".vibemis-ini-", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            first = True
            for section, entries in sections.items():
                if not first:
                    handle.write("\n")
                first = False
                if section:
                    handle.write(f"[{section}]\n")
                for key, value in entries.items():
                    handle.write(f"{key}={value}\n")
        os.chmod(tmp_path, mode)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


def merge_ini_files(target_path: str, overlay_paths: list[str]) -> bool:
    """Merge existing overlay INI files into target_path. Returns True if overlays applied."""
    existing_overlays = [p for p in overlay_paths if p and os.path.isfile(p)]
    if not existing_overlays:
        return False

    merged = parse_qsettings_ini(target_path)
    for overlay in existing_overlays:
        overlay_sections = parse_qsettings_ini(overlay)
        for section, entries in overlay_sections.items():
            target_section = merged.setdefault(section, OrderedDict())
            for key, value in entries.items():
                target_section[key] = value

    write_qsettings_ini(target_path, merged)
    return True


def run_self_test() -> None:
    """Verify QSettings INI merge preserves @ByteArray values, backslashes, and existing keys."""
    with tempfile.TemporaryDirectory() as tmpdir:
        target = os.path.join(tmpdir, "Vibemis.conf")
        cfg = os.path.join(tmpdir, "config.ini")
        sec = os.path.join(tmpdir, "secret.ini")

        with open(target, "w", encoding="utf-8") as f:
            f.write("[General]\nseenwelcomehint=false\n\n[hosts]\n1\\mac=@ByteArray(\\x84\\\\\\xf3)\n")
        with open(cfg, "w", encoding="utf-8") as f:
            f.write("[General]\nseenwelcomehint=true\nfps=30\n")
        with open(sec, "w", encoding="utf-8") as f:
            f.write("[General]\nuniqueid=deadbeef\n\n[hosts]\n1\\srvcert=CERTDATA==\n")

        assert merge_ini_files(target, [cfg, sec]) is True
        result = parse_qsettings_ini(target)
        assert result["General"]["seenwelcomehint"] == "true"
        assert result["General"]["fps"] == "30"
        assert result["General"]["uniqueid"] == "deadbeef"
        assert result["hosts"]["1\\mac"] == "@ByteArray(\\x84\\\\\\xf3)"
        assert result["hosts"]["1\\srvcert"] == "CERTDATA=="
    print("[vibemis-kiosk] INI merge self-test passed.")


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        run_self_test()
        return 0
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <target.conf> <overlay1.ini> [overlay2.ini ...]", file=sys.stderr)
        return 2

    target_path = sys.argv[1]
    overlay_paths = sys.argv[2:]
    if merge_ini_files(target_path, overlay_paths):
        print(f"[vibemis-kiosk] Merged declarative INI config into {target_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
