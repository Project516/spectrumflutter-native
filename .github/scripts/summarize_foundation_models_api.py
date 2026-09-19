#!/usr/bin/env python3
"""Summarize FoundationModels symbols of interest from swift-symbolgraph-extract output.

Reads every *.symbols.json file in each given symbol-graph directory, keeps
symbols whose full path contains one of a fixed set of names, and writes one
line per match (kind, full path, availability) to the given output file.
"""

import json
import sys
from pathlib import Path

NEEDLES = (
    "GenerationOptions",
    "GenerationError",
    "ToolCallingMode",
    "ErrorCode",
    "contextWindow",
    "Transcript",
    "SystemLanguageModel",
    "LanguageModelSession",
)


def last_path_component(symbol: dict) -> str:
    components = symbol.get("pathComponents")
    if components:
        return components[-1] if isinstance(components, list) else str(components).split(".")[-1]
    title = symbol.get("names", {}).get("title", "<unknown>")
    return title.split(".")[-1]


def full_path(symbol: dict) -> str:
    components = symbol.get("pathComponents")
    if components:
        return ".".join(components)
    return symbol.get("names", {}).get("title", "<unknown>")


def format_availability(symbol: dict) -> str:
    entries = symbol.get("availability", [])
    if not entries:
        return "no availability info"
    parts = []
    for entry in entries:
        domain = entry.get("domain", "?")
        introduced = entry.get("introduced")
        if introduced:
            version = ".".join(
                str(introduced.get(part, 0))
                for part in ("major", "minor", "patch")
                if part in introduced
            )
            parts.append(f"{domain} {version}+")
        elif entry.get("isUnconditionallyUnavailable"):
            parts.append(f"{domain} unavailable")
        else:
            parts.append(f"{domain} (no introduced version)")
    return ", ".join(parts)


def collect_matches(symbol_graph_dir: Path, label: str) -> list[str]:
    lines = []
    if not symbol_graph_dir.is_dir():
        lines.append(f"- `{symbol_graph_dir}` was not produced (the extract step failed)")
        return lines
    json_files = sorted(symbol_graph_dir.glob("*.symbols.json"))
    if not json_files:
        lines.append(f"- no symbol graph files found under `{symbol_graph_dir}`")
        return lines
    for path in json_files:
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError as error:
            lines.append(f"- `{path}` is not valid JSON: {error}")
            continue
        for symbol in data.get("symbols", []):
            name = full_path(symbol)
            symbol_name = last_path_component(symbol)
            if not any(needle == symbol_name or needle.lower() == symbol_name.lower() for needle in NEEDLES):
                continue
            kind = symbol.get("kind", {}).get("displayName", "?")
            availability = format_availability(symbol)
            lines.append(f"- [{label}] {kind}: `{name}` -- {availability}")
    return lines


def main() -> None:
    if len(sys.argv) < 4:
        print(
            "usage: summarize_foundation_models_api.py <ios-dir> <macos-dir> <output.md>",
            file=sys.stderr,
        )
        sys.exit(1)

    ios_dir, macos_dir, output_path = (Path(a) for a in sys.argv[1:4])

    lines = ["# FoundationModels public API of interest", ""]
    lines += collect_matches(ios_dir, "ios")
    lines += collect_matches(macos_dir, "macos")
    if len(lines) == 2:
        lines.append("- no matching symbols found")

    output_path.write_text("\n".join(lines) + "\n")
    print(f"wrote {len(lines) - 2} lines to {output_path}")


if __name__ == "__main__":
    main()
