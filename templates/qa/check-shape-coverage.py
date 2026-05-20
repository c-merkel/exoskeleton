#!/usr/bin/env python3
"""Pre-commit shape-coverage gate.

For every entity touched in the staged file set, check whether the OTHER
critical parity layers were also staged. Critical pairings are loaded from
qa/entity-shapes.config.yaml (key: `critical_pairings`).

Default mode: warn (exit 0). `--strict` exits 1 on coverage gaps.

Override env: <PROJECT_SLUG>_SKIP_SHAPE_CHECK=1 exits 0 silently.

Reads:
  qa/entity-shapes.json (via qa/lib/entity_shapes.py)
  qa/entity-shapes.config.yaml (for critical_pairings + uncovered_entities)
  git diff --cached --name-only --diff-filter=ACMR (or stdin via --stdin)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "qa" / "lib"))

from entity_shapes import (  # noqa: E402
    load_shapes,
    resolve_entity_for_path,
    missing_layers,
    is_synced,
)


CONFIG_PATH = REPO_ROOT / "qa" / "entity-shapes.config.yaml"


# Default critical pairings if no config present.
DEFAULT_CRITICAL_PAIRINGS = {
    "sync_service": ["sync_store", "wire_spec"],
    "sync_store": ["sync_service"],
    "migrations": ["sync_service"],
}


def _load_simple_yaml(path: Path) -> dict:
    """Minimal YAML parser — handles the subset we ship in the config template.

    Supports: top-level scalars, dicts of lists-of-scalars, dicts of dicts of
    lists. No anchors, no flow style, no quoted multi-line.
    """
    if not path.exists():
        return {}
    out: dict = {}
    stack = [(0, out)]
    cur_list_key = None
    cur_list_indent = -1
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.lstrip()

        # Close stacks above current indent
        while stack and indent < stack[-1][0]:
            stack.pop()
            if cur_list_indent >= 0 and indent <= cur_list_indent:
                cur_list_key = None
                cur_list_indent = -1

        if stripped.startswith("- "):
            val = stripped[2:].strip()
            if cur_list_key is None:
                continue
            parent = stack[-1][1]
            if isinstance(parent.get(cur_list_key), list):
                parent[cur_list_key].append(val)
            continue

        if ":" in stripped:
            key, _, val = stripped.partition(":")
            key = key.strip()
            val = val.strip()
            parent = stack[-1][1]
            if val == "":
                # Could be dict or list — peek next non-empty line via deferred
                parent[key] = {}
                stack.append((indent + 2, parent[key]))
                cur_list_key = key
                cur_list_indent = indent
            else:
                # Inline scalar
                if val.startswith("[") and val.endswith("]"):
                    items = [v.strip().strip("'\"") for v in val[1:-1].split(",") if v.strip()]
                    parent[key] = items
                elif val in ("true", "false"):
                    parent[key] = val == "true"
                else:
                    parent[key] = val.strip("'\"")
                cur_list_key = key
                cur_list_indent = indent
    return out


def _load_config() -> dict:
    cfg = _load_simple_yaml(CONFIG_PATH)
    return cfg


def get_staged() -> list[str]:
    try:
        out = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            cwd=str(REPO_ROOT),
            stderr=subprocess.DEVNULL,
        )
        return [ln.strip() for ln in out.decode().splitlines() if ln.strip()]
    except subprocess.CalledProcessError:
        return []


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true", help="exit 1 on coverage gaps")
    ap.add_argument("--stdin", action="store_true", help="read staged paths from stdin")
    ap.add_argument("--quiet", action="store_true", help="suppress 'no gaps' message")
    args = ap.parse_args()

    if os.environ.get("<PROJECT_SLUG>_SKIP_SHAPE_CHECK") == "1":
        return 0

    if args.stdin:
        staged = [ln.strip() for ln in sys.stdin if ln.strip()]
    else:
        staged = get_staged()
    if not staged:
        return 0

    shapes = load_shapes()
    if not shapes:
        return 0  # no entities defined yet

    cfg = _load_config()
    critical_pairings = cfg.get("critical_pairings") or DEFAULT_CRITICAL_PAIRINGS
    # Normalize: values can be list-of-strings
    critical_pairings = {
        k: (v if isinstance(v, list) else [s.strip() for s in str(v).split(",")])
        for k, v in critical_pairings.items()
    }
    uncovered_entities = set(cfg.get("uncovered_by_parity_check") or [])

    by_entity: dict[str, list[str]] = {}
    entity_data_map: dict[str, dict] = {}
    for f in staged:
        key, data = resolve_entity_for_path(f)
        if key:
            by_entity.setdefault(key, []).append(f)
            entity_data_map[key] = data

    if not by_entity:
        if not args.quiet:
            print("[shape-check] no entity files staged — pass")
        return 0

    findings = []
    for entity_key, files_staged in by_entity.items():
        data = entity_data_map[entity_key]
        miss = missing_layers(data, set(staged))
        if not miss:
            continue
        layers_in_staged = set()
        for layer_name, layer_files in (data.get("parity_layers") or {}).items():
            for lf in layer_files:
                hit = (any(f.startswith(lf) for f in staged) if lf.endswith("/") else lf in staged)
                if hit:
                    layers_in_staged.add(layer_name)
                    break
        critical_gaps = {}
        for layer in layers_in_staged:
            for partner in critical_pairings.get(layer, []):
                if partner in miss:
                    critical_gaps[partner] = miss[partner]
        if critical_gaps:
            findings.append((entity_key, data, files_staged, critical_gaps))

    uncovered_touched = sorted(uncovered_entities & set(by_entity.keys()))
    if uncovered_touched:
        print("")
        print("ℹ️  shape-check info — these entities are touched but flagged in config as")
        print("   not covered by deeper parity tooling:")
        for k in uncovered_touched:
            display = entity_data_map[k].get("display_name", k)
            print(f"     • {k} ({display})")
        print("")

    if not findings:
        if not args.quiet:
            print(f"[shape-check] {len(by_entity)} entit{'y' if len(by_entity)==1 else 'ies'} touched, no critical gaps")
        return 0

    print("")
    print("⚠️  Shape-coverage WARN — staged change touches an entity but one or more")
    print("    critical parity layers were not staged.")
    print("")
    for entity_key, data, files_staged, gaps in findings:
        display = data.get("display_name", entity_key)
        synced_tag = " (synced)" if is_synced(data) else ""
        print(f"  {display}{synced_tag}")
        print(f"    staged: {', '.join(files_staged[:4])}{' …' if len(files_staged) > 4 else ''}")
        for layer, files in gaps.items():
            print(f"    ⚠ missing layer '{layer}':")
            for lf in files:
                print(f"        {lf}")
        print("")

    print("    Why this fires: critical pairings declared in qa/entity-shapes.config.yaml")
    print("    catch the cross-layer drift class (wire ↔ Codable, schema ↔ projection).")
    print("    If the change is intentional (docs-only, server-only) commit through.")
    print("")
    print("    Override: <PROJECT_SLUG>_SKIP_SHAPE_CHECK=1 git commit ...")
    print("")
    return 1 if args.strict else 0


if __name__ == "__main__":
    sys.exit(main())
