#!/usr/bin/env bash
# Memory-backend abstraction for the autonomic-layer hooks.
#
# Two hooks (recall-topic-area.sh, learn-from-correction.sh) need persistent
# cross-session memory. The exoskeleton supports three backends, chosen by
# the consumer at install time and switched via env var at runtime:
#
#   <PROJECT_SLUG>_MEMORY_BACKEND=mempalace  (default — canonical stack MCP)
#   <PROJECT_SLUG>_MEMORY_BACKEND=file       (no-MCP fallback — local files)
#   <PROJECT_SLUG>_MEMORY_BACKEND=custom     (user supplies an impl script)
#
# The hooks call into two functions and don't know or care which backend ran:
#
#   memory_recall <entity-name> <days-back>
#     → emits markdown lines about that entity's recent history
#
#   memory_capture <doc-text> <tags-csv> <branch> <entities-csv>
#     → persists the doc; idempotent on identical input within the same day
#
# Each backend implements those two functions. The dispatcher picks one
# based on the env var, with a sanity probe for the mempalace path.
#
# Override / silence:
#   <PROJECT_SLUG>_MEMORY_BACKEND=none — both functions become no-ops

# ---------- Backend selector --------------------------------------------------

_memory_backend() {
  local backend="${<PROJECT_SLUG>_MEMORY_BACKEND:-mempalace}"
  case "$backend" in
    none|file|custom|mempalace) echo "$backend" ;;
    *) echo "mempalace" ;;
  esac
}

# ---------- mempalace backend -------------------------------------------------

_memory_mempalace_dir() {
  echo "${<PROJECT_SLUG>_MEMPALACE_DIR:-$HOME/Documents/Claude/MCP-TOOLS/mempalace}"
}

_memory_mempalace_palace() {
  echo "${<PROJECT_SLUG>_MEMPALACE_PALACE:-$HOME/.mempalace/palace}"
}

_memory_mempalace_recall() {
  local entity="$1" days="${2:-14}"
  local mempalace_dir; mempalace_dir=$(_memory_mempalace_dir)
  local palace_dir; palace_dir=$(_memory_mempalace_palace)
  [ -d "$mempalace_dir" ] || return 0
  uv run --directory "$mempalace_dir" python -c "
import sys
from datetime import datetime, timedelta
try:
    from mempalace.palace import get_collection
    col = get_collection('$palace_dir', create=False)
    if col is None: sys.exit(0)
    today = datetime.now().date()
    dates = [(today - timedelta(days=i)).isoformat() for i in range($days + 1)]
    res = col.get(
        where={'\$and': [{'room': 'diary'}, {'date': {'\$in': dates}}]},
        limit=80,
    )
    entity_l = '''$entity'''.lower()
    docs = res.get('documents') or []
    metas = res.get('metadatas') or []
    hits = [(m.get('date','?'), (d or '').strip()) for d, m in zip(docs, metas) if entity_l in (d or '').lower()]
    hits.sort(key=lambda x: x[0], reverse=True)
    for date, doc in hits[:2]:
        s = doc.replace(chr(10), ' ').strip()
        if len(s) > 260: s = s[:260] + '…'
        print(f'- {date}: {s}')
except Exception:
    pass
" 2>/dev/null
}

_memory_mempalace_capture() {
  local doc="$1" tags="$2" branch="$3" entities="$4"
  local mempalace_dir; mempalace_dir=$(_memory_mempalace_dir)
  local palace_dir; palace_dir=$(_memory_mempalace_palace)
  [ -d "$mempalace_dir" ] || return 0
  uv run --directory "$mempalace_dir" python -c "
import sys
from datetime import datetime
try:
    from mempalace.palace import get_collection
    col = get_collection('$palace_dir', create=False)
    if col is None: sys.exit(0)
    today = datetime.now().date().isoformat()
    doc = '''$doc'''
    meta = {'room':'diary','agent':'Claude','date':today,'tags':'''$tags''','branch':'''$branch'''}
    ent = '''$entities'''
    if ent: meta['entities'] = ent
    col.add(
        ids=[f'capture-{today}-{abs(hash(doc))%10**8}'],
        documents=[doc],
        metadatas=[meta],
    )
except Exception:
    pass
" 2>/dev/null
}

# ---------- file backend ------------------------------------------------------

_memory_file_dir() {
  local root; root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  echo "${<PROJECT_SLUG>_MEMORY_FILE_DIR:-$root/qa/.lessons}"
}

_memory_file_recall() {
  local entity="$1" days="${2:-14}"
  local dir; dir=$(_memory_file_dir)
  [ -d "$dir" ] || return 0
  python3 -c "
import os, sys, glob
from datetime import datetime, timedelta
entity = '''$entity'''.lower()
today = datetime.now().date()
dates = [(today - timedelta(days=i)).isoformat() for i in range($days + 1)]
hits = []
for date in dates:
    for path in sorted(glob.glob(os.path.join('$dir', f'{date}-*.md'))):
        try:
            with open(path) as f:
                txt = f.read()
            if entity in txt.lower():
                snippet = txt.replace(chr(10), ' ').strip()
                if len(snippet) > 260: snippet = snippet[:260] + '…'
                hits.append((date, snippet))
                if len(hits) >= 2: break
        except Exception:
            pass
    if len(hits) >= 2: break
for date, doc in hits:
    print(f'- {date}: {doc}')
" 2>/dev/null
}

_memory_file_capture() {
  local doc="$1" tags="$2" branch="$3" entities="$4"
  local dir; dir=$(_memory_file_dir)
  mkdir -p "$dir" 2>/dev/null || return 0
  local today; today=$(date -u +%Y-%m-%d)
  local hash_id; hash_id=$(printf '%s' "$doc" | shasum 2>/dev/null | head -c 8)
  [ -z "$hash_id" ] && hash_id="$(date -u +%s)"
  local outfile="$dir/${today}-${hash_id}.md"
  [ -f "$outfile" ] && return 0  # idempotent on identical content same day
  cat > "$outfile" <<EOF
---
date: $today
agent: Claude
branch: $branch
tags: $tags
entities: $entities
---

$doc
EOF
}

# ---------- custom backend ----------------------------------------------------

_memory_custom_script() {
  local root; root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  echo "${<PROJECT_SLUG>_MEMORY_CUSTOM:-$root/qa/.memory-custom.sh}"
}

_memory_custom_recall() {
  local script; script=$(_memory_custom_script)
  [ -x "$script" ] || return 0
  "$script" recall "$@" 2>/dev/null
}

_memory_custom_capture() {
  local script; script=$(_memory_custom_script)
  [ -x "$script" ] || return 0
  "$script" capture "$@" 2>/dev/null
}

# ---------- Dispatcher --------------------------------------------------------

memory_recall() {
  local backend; backend=$(_memory_backend)
  case "$backend" in
    none)      return 0 ;;
    mempalace) _memory_mempalace_recall "$@" ;;
    file)      _memory_file_recall "$@" ;;
    custom)    _memory_custom_recall "$@" ;;
  esac
}

memory_capture() {
  local backend; backend=$(_memory_backend)
  case "$backend" in
    none)      return 0 ;;
    mempalace) _memory_mempalace_capture "$@" ;;
    file)      _memory_file_capture "$@" ;;
    custom)    _memory_custom_capture "$@" ;;
  esac
}
