"""Entity shape resolver — load qa/entity-shapes.json and answer:
   "what entity does this file belong to?" "what files belong to entity X?"

Consumed by:
  - .claude/hooks/ambient-impact.sh    (ambient peripheral vision)
  - .claude/hooks/self-stop-watchdog.sh (entity hint in D2 warning)
  - qa/check-shape-coverage.py          (pre-commit shape gate)

Fail-safe: any read error returns empty state — callers should treat
"no entity" as the silent path, never crash.

This file ships with the exoskeleton bundle. Don't customize it directly —
edit `qa/entity-shapes.config.yaml` then re-run `python3 qa/mine-entity-shapes.py`.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SHAPES_PATH = REPO_ROOT / "qa" / "entity-shapes.json"

_cache: Optional[dict] = None


def load_shapes() -> dict:
    """Return the {entity_key: shape_dict} mapping, cached for the process."""
    global _cache
    if _cache is not None:
        return _cache
    if not SHAPES_PATH.exists():
        _cache = {}
        return _cache
    try:
        data = json.loads(SHAPES_PATH.read_text())
        _cache = data.get("entities", {}) or {}
    except (OSError, json.JSONDecodeError):
        _cache = {}
    return _cache


def all_files_for_entity(entity_data: dict, *, include_cochange: bool = True) -> list[str]:
    out: list[str] = []
    for files in (entity_data.get("parity_layers") or {}).values():
        out.extend(files)
    if include_cochange:
        out.extend((entity_data.get("cochange_frequent") or {}).keys())
    return out


def _normalize(file_path: str) -> str:
    if not file_path:
        return ""
    p = Path(file_path)
    if p.is_absolute():
        try:
            p = p.relative_to(REPO_ROOT)
        except ValueError:
            return str(p)
    s = str(p).replace(os.sep, "/")
    return s.lstrip("./")


def resolve_entity_for_path(file_path: str) -> tuple[Optional[str], Optional[dict]]:
    """Resolve file_path → (entity_key, entity_data). Returns (None, None) if no match.

    Resolution combines three signals into a score:
      +100 exact file membership in a parity_layer
      +60  cochange_frequent membership
      +40  display-name token in filename basename
      +15  snake-name appearance in path segment
      +5   directory-prefix membership (entry ends with "/")
    Most-specific (longest snake) wins ties.
    """
    if not file_path:
        return None, None
    rel = _normalize(file_path)
    if not rel:
        return None, None

    shapes = load_shapes()
    basename = rel.rsplit("/", 1)[-1]
    rel_l = rel.lower()

    best_score = 0
    best_key: Optional[str] = None
    best_data: Optional[dict] = None
    best_snake_len = 0

    for key, data in shapes.items():
        score = 0
        snake = (data.get("snake") or "").lower()
        display = data.get("display_name") or ""

        for layer_files in (data.get("parity_layers") or {}).values():
            for f in layer_files:
                if f.endswith("/"):
                    if rel.startswith(f):
                        score = max(score, 5)
                elif rel == f:
                    score = max(score, 100)
        if rel in (data.get("cochange_frequent") or {}):
            score = max(score, 60)
        if display and (
            basename.startswith(display)
            or basename.startswith(display + ".")
            or display + "Store" in basename
            or display + "Service" in basename
            or display + "Controller" in basename
            or display + "View" in basename
            or display + "Model" in basename
        ):
            score = max(score, 40)
        if snake:
            for tok in (f"/{snake}_", f"/{snake}.", f"/{snake}/", f"/{snake}s/", f"/{snake}s."):
                if tok in rel_l:
                    score = max(score, 15)
                    break

        if score > best_score or (score == best_score and score > 0 and len(snake) > best_snake_len):
            best_score = score
            best_key = key
            best_data = data
            best_snake_len = len(snake)

    if best_score > 0:
        return best_key, best_data
    return None, None


def parity_layer_files(entity_data: dict) -> dict[str, list[str]]:
    return dict(entity_data.get("parity_layers") or {})


def missing_layers(entity_data: dict, touched_files: set[str]) -> dict[str, list[str]]:
    """Layers where NONE of the canonical files have been touched yet."""
    missing: dict[str, list[str]] = {}
    for layer_name, files in parity_layer_files(entity_data).items():
        hit = False
        for f in files:
            if f.endswith("/"):
                if any(t.startswith(f) for t in touched_files):
                    hit = True
                    break
            elif f in touched_files:
                hit = True
                break
        if not hit:
            missing[layer_name] = files
    return missing


def is_synced(entity_data: dict) -> bool:
    layers = entity_data.get("parity_layers") or {}
    return "sync_service" in layers


# ---- CLI introspection ---------------------------------------------------
def _cli():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--resolve", help="resolve a file path → entity")
    ap.add_argument("--list", action="store_true", help="list all entity keys")
    ap.add_argument("--show", help="show one entity's full shape")
    args = ap.parse_args()
    if args.list:
        for k in load_shapes():
            print(k)
        return 0
    if args.resolve:
        key, data = resolve_entity_for_path(args.resolve)
        if key:
            print(json.dumps({"entity": key, "shape": data}, indent=2))
        else:
            print("(no entity match)")
        return 0
    if args.show:
        shapes = load_shapes()
        if args.show in shapes:
            print(json.dumps(shapes[args.show], indent=2))
            return 0
        print(f"unknown entity: {args.show}", flush=True)
        return 1
    ap.print_help()
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(_cli())
