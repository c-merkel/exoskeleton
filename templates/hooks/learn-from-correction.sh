#!/usr/bin/env bash
# Autonomic layer 5 — Correction-learning loop (the flywheel)
#
# Fires on UserPromptSubmit. Conservative regex detector for high-confidence
# correction phrases ("you missed", "from now on always", "don't ever",
# "rule:"). On hit: capture a lesson into the configured memory backend
# tagged `correction` + branch + entities (derived from last-touched files).
# Future sessions in the same area auto-recall via the memory-recall path.
#
# Conservative on purpose — false positives flood memory; false negatives
# are fine (Chris can always explicitly /remember).
#
# Override:
#   <PROJECT_SLUG>_SKIP_LEARN=1                     one-shot skip
#   touch ${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-learn   machine-wide skip

set +e
JSON_INPUT=$(cat 2>/dev/null || echo "{}")

if [ "${<PROJECT_SLUG>_SKIP_LEARN:-0}" = "1" ] || [ -f "${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-learn" ]; then
  exit 0
fi

source "$(dirname "$0")/lib-memory.sh"

if command -v jq >/dev/null 2>&1; then
  PROMPT=$(echo "$JSON_INPUT" | jq -r '.prompt // empty' 2>/dev/null)
  SID=$(echo "$JSON_INPUT" | jq -r '.session_id // empty' 2>/dev/null)
else
  PROMPT=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('prompt',''))
except Exception: pass" 2>/dev/null)
  SID=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('session_id',''))
except Exception: pass" 2>/dev/null)
fi

[ -z "$PROMPT" ] && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

DETECTED=$(python3 -c "
import re
prompt = '''$PROMPT'''
patterns = [
    r'\byou (forgot|missed|skipped|didn..?t)\b',
    r'\b(stop|don..?t) (doing|using|building|creating|making|adding)\b',
    r'\bdon..?t ever\b',
    r'\bnever (use|do|edit|touch|skip|build|create)\b',
    r'\b(always|from now on|in the future) (use|do|prefer|run|check|read)\b',
    r'\bwrong\W.*(should|must|need)',
    r'\bnext time,?\s+(use|do|run|check|read|verify)',
    r'\bthat..?s not (how|what|the)\b',
    r'\bnot like that\b',
    r'\bremember.*(use|don..?t|always|never|prefer)',
    r'\brule:',
]
hits = [p for p in patterns if re.search(p, prompt, re.IGNORECASE)]
if hits: print('|'.join(hits[:3]))
" 2>/dev/null)

[ -z "$DETECTED" ] && exit 0

TRIMMED=$(python3 -c "
p = '''$PROMPT'''.replace(chr(10), ' ').strip()
if len(p) > 380: p = p[:380] + '…'
print(p)
" 2>/dev/null)

# Capture session context — touched files + their entities.
SESSION_DIR="${TMPDIR:-/tmp}/<PROJECT_SLUG>-session/$SID"
TOUCHED_FILES=""
ENTITIES=""
if [ -f "$SESSION_DIR/touched-files.log" ]; then
  TOUCHED_FILES=$(tail -n 8 "$SESSION_DIR/touched-files.log" | tr '\n' ',' | sed 's/,$//')
  if [ -f "$REPO_ROOT/qa/lib/entity_shapes.py" ]; then
    ENTITIES=$(python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/qa/lib')
try:
    from entity_shapes import resolve_entity_for_path
    seen = set()
    for f in '''$TOUCHED_FILES'''.split(','):
        f = f.strip()
        if not f: continue
        key, _ = resolve_entity_for_path(f)
        if key: seen.add(key)
    if seen: print(','.join(sorted(seen)))
except Exception: pass
" 2>/dev/null)
  fi
fi

TODAY=$(date -u +%Y-%m-%d)
DOC="CORRECTION [${TODAY}]  branch=${BRANCH} entities=[${ENTITIES}]  patterns=[${DETECTED}]
Operator: ${TRIMMED}
Context: last-touched files = ${TOUCHED_FILES}"

memory_capture "$DOC" "correction" "$BRANCH" "$ENTITIES"

# Also append a Task:<branch> observation if mempalace is in play (best signal).
if [ "${<PROJECT_SLUG>_MEMORY_BACKEND:-mempalace}" = "mempalace" ] && [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
  MEMP_DIR="${<PROJECT_SLUG>_MEMPALACE_DIR:-$HOME/Documents/Claude/MCP-TOOLS/mempalace}"
  if [ -d "$MEMP_DIR" ]; then
    uv run --directory "$MEMP_DIR" python -c "
import json, sqlite3
from datetime import datetime
try:
    from mempalace.knowledge_graph import KnowledgeGraph
    kg = KnowledgeGraph()
    conn = sqlite3.connect(kg.db_path)
    row = conn.execute('SELECT properties FROM entities WHERE name = ?', (f'Task:$BRANCH',)).fetchone()
    if row:
        props = json.loads(row[0] or '{}')
        obs = props.get('observations', []) or []
        obs.append(f'{datetime.now().isoformat(timespec=\"seconds\")} — CORRECTION: '''$TRIMMED'''[:200])
        props['observations'] = obs[-500:]
        conn.execute('UPDATE entities SET properties=? WHERE name=?', (json.dumps(props), f'Task:$BRANCH'))
        conn.commit()
    conn.close()
except Exception: pass
" 2>/dev/null
  fi
fi

cat >&2 <<EOF

🧠 Correction captured for future sessions
   Patterns: $DETECTED
   Entities: ${ENTITIES:-(none)}
   Backend:  ${<PROJECT_SLUG>_MEMORY_BACKEND:-mempalace}
   (<PROJECT_SLUG>_SKIP_LEARN=1 to silence)

EOF

exit 0
