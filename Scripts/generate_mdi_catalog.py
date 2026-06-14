#!/usr/bin/env python3
"""Generate the pinned Material Design Icons lookup used by Homestead."""

import json
import pathlib
import urllib.request

VERSION = "7.4.47"
METADATA_COMMIT = "2424e748e0cc63ab7b9c095a099b9fe239b737c0"
META_URL = f"https://raw.githubusercontent.com/Templarian/MaterialDesign/{METADATA_COMMIT}/meta.json"
OUTPUT = pathlib.Path("Shared/IconSystem/Resources/MaterialDesignIconCatalog.json")


def main() -> None:
    with urllib.request.urlopen(META_URL) as response:
        metadata = json.load(response)

    entries: dict[str, int] = {}
    for icon in metadata:
        codepoint = int(icon["codepoint"], 16)
        entries[icon["name"]] = codepoint
        for alias in icon.get("aliases", []):
            entries.setdefault(alias, codepoint)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(dict(sorted(entries.items())), separators=(",", ":")),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
