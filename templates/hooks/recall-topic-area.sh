#!/usr/bin/env bash
# Autonomic layer 2 — Topic-area recall (deep memory on demand)
#
# Fires on UserPromptSubmit. When the user's prompt mentions a known entity
# by display or snake name, inject recent diary entries + Task:<branch>
# observations about that entity as additionalContext on the prompt. Catches
# topic switches mid-session that the SessionStart injection misses.
#
# Memory backend is pluggable via lib-memory.sh (mempalace | file | custom).
# If the backend is `none` or has no matching content, the hook exits silently.
#
# Override:
#   <PROJECT_SLUG>_SKIP_TOPIC_RECALL=1                one-shot skip
#   touch ${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-topic-recall   machine-wide skip

set +e
JSON_INPUT=$(cat 2>/dev/null || echo "{}")

if [ "${<PROJECT_SLUG>_SKIP_TOPIC_RECALL:-0}" = "1" ] || [ -f "${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-topic-recall" ]; then
  exit 0
fi

source "$(dirname "$0")/lib-memory.sh"

if command -v jq >/dev/null 2>&1; then
  PROMPT=$(echo "$JSON_INPUT" | jq -r '.prompt // empty' 2>/dev/null)
else
  PROMPT=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('prompt',''))
except Exception: pass" 2>/dev/null)
fi

[ -z "$PROMPT" ] && exit 0
[ ${#PROMPT} -lt 8 ] && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SHAPES="$REPO_ROOT/qa/entity-shapes.json"
[ -f "$SHAPES" ] || exit 0

BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Match prompt against entity display + snake names.
MATCHED=$(python3 -c "
import json, re, sys
prompt = '''$PROMPT'''.lower()
try:
    shapes = json.load(open('$SHAPES'))['entities']
except Exception:
    sys.exit(0)
hits = []
for key, data in shapes.items():
    display = (data.get('display_name') or '').lower()
    snake = (data.get('snake') or '').lower()
    if display and re.search(r'\b' + re.escape(display) + r'\b', prompt):
        hits.append((key, data.get('display_name', key)))
        continue
    if snake and re.search(r'\b' + re.escape(snake) + r's?\b', prompt):
        hits.append((key, data.get('display_name', key)))
        continue
# de-dup, prefer most specific (longer snake)
seen = {}
for k, d in hits: seen[k] = d
ordered = sorted(seen.items(), key=lambda x: -len(x[0]))
for k, d in ordered[:3]:
    print(f'{k}\t{d}')
" 2>/dev/null)

[ -z "$MATCHED" ] && exit 0

OUT=""
while IFS=$'\t' read -r KEY DISPLAY; do
  [ -z "$KEY" ] && continue
  # Recall via memory backend.
  RECALL=$(memory_recall "$DISPLAY" 14)
  if [ -n "$RECALL" ]; then
    OUT+=$'\n\n**'"$DISPLAY"$'** — recent memory\n'"$RECALL"
  fi
  # Plus Task:<branch> observations if mempalace backend is active.
  if [ "${<PROJECT_SLUG>_MEMORY_BACKEND:-mempalace}" = "mempalace" ] && [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
    MEMP_DIR="${<PROJECT_SLUG>_MEMPALACE_DIR:-$HOME/Documents/Claude/MCP-TOOLS/mempalace}"
    if [ -d "$MEMP_DIR" ]; then
      TASK_OBS=$(uv run --directory "$MEMP_DIR" python -c "
import json, sqlite3, sys
try:
    from mempalace.knowledge_graph import KnowledgeGraph
    kg = KnowledgeGraph()
    conn = sqlite3.connect(kg.db_path)
    row = conn.execute('SELECT properties FROM entities WHERE name = ?', (f'Task:$BRANCH',)).fetchone()
    if not row: sys.exit(0)
    props = json.loads(row[0] or '{}')
    obs = props.get('observations', []) or []
    display = '''$DISPLAY'''.lower()
    snake = '''$KEY'''.lower()
    rel = []
    for o in obs[-40:]:
        ol = str(o).lower()
        if display in ol or snake in ol: rel.append(str(o))
    for r in rel[-3:]:
        print(f'- {r}')
except Exception: pass
" 2>/dev/null)
      if [ -n "$TASK_OBS" ]; then
        OUT+=$'\n\n**'"$DISPLAY"$'** — Task:'"$BRANCH"$' observations\n'"$TASK_OBS"
      fi
    fi
  fi
done <<< "$MATCHED"

[ -z "$OUT" ] && exit 0

HEADER='## Topic-area recall (auto-injected by UserPromptSubmit hook)
Surfacing recent history for entities mentioned in your prompt — verify against current code before acting.'

python3 -c "
import json, sys
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'UserPromptSubmit',
        'additionalContext': '''$HEADER''' + sys.stdin.read(),
    }
}))
" <<< "$OUT"

exit 0
