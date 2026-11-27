#!/usr/bin/env python3
"""Pin the whole repository to a Roc release or nightly.

Updates the `roc:` version in every example header and the archives, hashes
and URL in flake.nix. CI reads its pin from examples/simple.roc, so no
workflow needs updating.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import re
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

# e.g. nightly-2026-08-13-2fdd90e
NIGHTLY_TAG_RE = re.compile(r"^nightly-(\d{4}-\d{2}-\d{2}-[0-9a-f]{7,40})$")
# e.g. 0.1.0 or 0.1.0-RC1, the header spelling of the release 0.1.0_RC1.
RELEASE_PIN_RE = re.compile(r"^\d+\.\d+\.\d+(-[A-Za-z0-9]+)?$")
# The `roc: "<pin>"` entry of an app header.
ROC_PIN_RE = re.compile(r'(?m)^(\s*roc:\s*)"[^"]+"')

# Nix system -> release asset platform slug.
PLATFORMS = {
    "x86_64-linux": "linux_x86_64",
    "aarch64-linux": "linux_arm64",
    "x86_64-darwin": "macos_x86_64",
    "aarch64-darwin": "macos_apple_silicon",
}


def release_archives(pin: str) -> tuple[str, dict[str, str]]:
    """The download URL and the archive name for each Nix system."""
    nightly = NIGHTLY_TAG_RE.match(pin)
    if nightly is not None:
        url = f"https://github.com/roc-lang/nightlies/releases/download/{pin}"
        prefix, suffix = "roc_nightly", nightly.group(1)
    elif RELEASE_PIN_RE.match(pin) is not None:
        release = pin.replace("-", "_")
        url = f"https://github.com/roc-lang/roc/releases/download/{release}"
        prefix, suffix = "roc", release
    else:
        raise SystemExit(f"Not a Roc release like 0.1.0-RC1 or a nightly tag: {pin}")

    return url, {system: f"{prefix}-{platform}-{suffix}" for system, platform in PLATFORMS.items()}


def sri_hash(url: str) -> str:
    digest = hashlib.sha256()
    with urllib.request.urlopen(url) as response:
        for chunk in iter(lambda: response.read(1024 * 1024), b""):
            digest.update(chunk)

    return f"sha256-{base64.b64encode(digest.digest()).decode('ascii')}"


def current_version(examples_dir: Path) -> str | None:
    match = ROC_PIN_RE.search((examples_dir / "simple.roc").read_text(encoding="utf-8"))
    if match is None:
        return None

    return re.search(r'"([^"]+)"', match.group(0)).group(1)


def update_examples(examples_dir: Path, pin: str) -> list[Path]:
    examples = sorted(examples_dir.glob("*.roc"))
    if not examples:
        raise SystemExit(f"No Roc examples found in {examples_dir}")

    updated: list[Path] = []
    for example in examples:
        source = example.read_text(encoding="utf-8")
        rewritten, count = ROC_PIN_RE.subn(lambda match: f'{match.group(1)}"{pin}"', source, count=1)
        if count != 1:
            raise SystemExit(f"{example} does not pin a roc version in its header")
        if rewritten != source:
            example.write_text(rewritten, encoding="utf-8")
            updated.append(example)

    return updated


def set_string(source: str, prefix: str, value: str, flake: Path) -> str:
    """Replace the string literal that the regex `prefix` opens."""
    rewritten, count = re.subn(f'({prefix})[^"]*', lambda match: match.group(1) + value, source, count=1)
    if count != 1:
        raise SystemExit(f"{flake} does not match {prefix}")

    return rewritten


def update_flake(flake: Path, pin: str) -> bool:
    source = flake.read_text(encoding="utf-8")
    url, archives = release_archives(pin)

    rewritten = set_string(source, 'roc-version = "', pin, flake)
    rewritten = set_string(rewritten, 'roc-url = "', url, flake)

    for system, archive in archives.items():
        print(f"Hashing {archive}.tar.gz")
        digest = sri_hash(f"{url}/{archive}.tar.gz")
        entry = rf'{re.escape(system)} = \{{\s*name = "'
        rewritten = set_string(rewritten, entry, archive, flake)
        rewritten = set_string(rewritten, rf'{entry}[^"]*";\s*hash = "', digest, flake)

    if rewritten == source:
        return False

    flake.write_text(rewritten, encoding="utf-8")
    return True


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Release like 0.1.0-RC1 or nightly tag like nightly-2026-08-13-2fdd90e")
    parser.add_argument("--examples-dir", type=Path, default=ROOT / "examples")
    parser.add_argument("--flake", type=Path, default=ROOT / "flake.nix")
    args = parser.parse_args()

    pin = args.version
    release_archives(pin)  # validate before changing anything

    if current_version(args.examples_dir) == pin:
        print(f"Already pinned to {pin}.")
        return

    updated = update_examples(args.examples_dir, pin)
    if update_flake(args.flake, pin):
        updated.append(args.flake)

    print(f"Pinned to {pin}:")
    for path in updated:
        print(f"- {display_path(path)}")


if __name__ == "__main__":
    main()
