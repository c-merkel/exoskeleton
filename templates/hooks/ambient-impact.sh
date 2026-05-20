#!/usr/bin/env bash
# Autonomic layer 1 — Ambient Impact Dossier (peripheral vision)
#
# Fires on Read | Edit | Write | MultiEdit. Tracks every file touched this
# session. On the FIRST Edit/Write that lands inside a known entity's parity-
# layer fingerprint, emits a compact dossier of that entity's shape with the
# layers the AI hasn't touched yet flagged. Subsequent edits to the same
# entity are silent — peripheral vision should fire once per surface area.
#
# Reads are tracked but never emit a dossier (would be noisy on exploration).
#
# Requires: qa/entity-shapes.json + qa/lib/entity_shapes.py
#   These are populated by `python3 qa/mine-entity-shapes.py` from your
#   project's qa/entity-shapes.config.yaml. Without them, this hook silently
#   no-ops on every call (resolver returns NONE).
#
# Override:
#   <PROJECT_SLUG>_SKIP_AMBIENT=1                 one-shot skip
#   <PROJECT_SLUG>_AMBIENT_VERBOSE=1              re-emit dossier on every edit
#   touch ${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-ambient   machine-wide skip

set +e
JSON_INPUT=$(cat 2>/dev/null || echo "{}")

source "$(dirname "$0")/lib-session.sh"

if [ "${<PROJECT_SLUG>_SKIP_AMBIENT:-0}" = "1" ] || [ -f "${TMPDIR:-/tmp}/<PROJECT_SLUG>-skip-ambient" ]; then
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except Exception: pass" 2>/dev/null)
  TOOL_NAME=$(echo "$JSON_INPUT" | python3 -c "import json,sys
try: print(json.load(sys.stdin).get('tool_name',''))
except Exception: pass" 2>/dev/null)
fi

[ -z "$FILE_PATH" ] && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SID=$(extract_session_id "$JSON_INPUT")
DIR=$(session_dir "$SID")
TOUCHED="$DIR/touched-files.log"
SURFACED="$DIR/entity-surfaced.log"
READS_LOG="$DIR/reads.log"
EDITS_LOG="$DIR/edits.tsv"

# 1. Append to touched-files (deduped).
if ! grep -qxF "$FILE_PATH" "$TOUCHED" 2>/dev/null; then
  echo "$FILE_PATH" >> "$TOUCHED"
fi

# 1b. Per-tool logs feeding the watchdog.
case "$TOOL_NAME" in
  Read)
    if ! grep -qxF "$FILE_PATH" "$READS_LOG" 2>/dev/null; then
      echo "$FILE_PATH" >> "$READS_LOG"
    fi
    ;;
  Edit|Write|MultiEdit)
    printf '%s\t%s\t%s\n' "$(date -u +%s)" "$TOOL_NAME" "$FILE_PATH" >> "$EDITS_LOG"
    ;;
esac

# 2. Dossier only on Edit/Write/MultiEdit; Reads are silent (just tracked).
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) : ;;
  *) exit 0 ;;
esac

# 3. Resolve entity via the project's resolver lib. Fail-safe.
RESOLVE=$(python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/qa/lib')
try:
    from entity_shapes import resolve_entity_for_path, missing_layers, parity_layer_files, is_synced
    key, data = resolve_entity_for_path('$FILE_PATH')
    if not key: print('NONE'); sys.exit(0)
    touched = set()
    try:
        with open('$TOUCHED') as f:
            for ln in f:
                ln = ln.strip()
                if ln: touched.add(ln)
    except Exception: pass
    miss = missing_layers(data, touched)
    layers = parity_layer_files(data)
    synced = is_synced(data)
    print('OK'); print(key); print(data.get('display_name', key)); print('SYNCED' if synced else 'UNSYNCED')
    print('LAYERS_BEGIN')
    for layer_name, files in layers.items():
        marker = 'MISS' if layer_name in miss else 'OK'
        for f in files: print(f'{marker}\t{layer_name}\t{f}')
    print('LAYERS_END')
    parent = data.get('parent')
    if parent: print(f'PARENT\t{parent}')
    ws = (data.get('parity_layers') or {}).get('wire_spec') or []
    if ws: print(f'WIRE_SPEC\t{ws[0]}')
except Exception as e:
    print(f'ERROR\t{type(e).__name__}\t{e}')
" 2>/dev/null)

[ -z "$RESOLVE" ] && exit 0
FIRST=$(echo "$RESOLVE" | head -1)
[ "$FIRST" = "NONE" ] && exit 0
case "$FIRST" in ERROR*) exit 0;; esac
[ "$FIRST" != "OK" ] && exit 0

ENTITY_KEY=$(echo "$RESOLVE" | sed -n '2p')
DISPLAY=$(echo "$RESOLVE" | sed -n '3p')
SYNC_TAG=$(echo "$RESOLVE" | sed -n '4p')

# 4. Once-per-session gate.
if [ "${<PROJECT_SLUG>_AMBIENT_VERBOSE:-0}" != "1" ]; then
  if grep -qxF "$ENTITY_KEY" "$SURFACED" 2>/dev/null; then
    exit 0
  fi
fi
echo "$ENTITY_KEY" >> "$SURFACED"

# 5. Compose the dossier (compact — only MISSING layers).
DOSSIER=$(echo "$RESOLVE" | awk '
  /^LAYERS_BEGIN$/ { in_layers=1; next }
  /^LAYERS_END$/   { in_layers=0; next }
  in_layers == 1 {
    split($0, parts, "\t"); marker=parts[1]; layer=parts[2]; file=parts[3];
    if (marker == "MISS") {
      missing_layers[layer] = missing_layers[layer] ? missing_layers[layer] "\n      " file : file
    }
  }
  /^PARENT\t/    { parent=substr($0, 8) }
  /^WIRE_SPEC\t/ { wire_spec=substr($0, 11) }
  END {
    if (length(missing_layers) == 0) exit 0
    printf "%s", "MISSING|"
    for (l in missing_layers) printf "%s>>%s||", l, missing_layers[l]
    printf "##"
    if (parent != "")    printf "PARENT|%s##", parent
    if (wire_spec != "") printf "WIRE_SPEC|%s##", wire_spec
  }
')

[ -z "$DOSSIER" ] && exit 0

SYNC_DESC="(unsynced)"
[ "$SYNC_TAG" = "SYNCED" ] && SYNC_DESC="(synced)"

cat >&2 <<EOF

🔭 Ambient impact — $DISPLAY $SYNC_DESC

  File: $FILE_PATH
  Entity: $ENTITY_KEY

  Parity layers NOT yet touched in this session:
EOF

echo "$DOSSIER" | tr '#' '\n' | grep '^MISSING' | sed 's/^MISSING|//' | tr '|' '\n' | while IFS='>>' read -r layer files_blob; do
  [ -z "$layer" ] && continue
  files_clean=$(echo "$files_blob" | tr -d '>')
  echo "    • $layer:" >&2
  echo "        $files_clean" >&2
done

PARENT_LINE=$(echo "$DOSSIER" | tr '#' '\n' | grep '^PARENT|' | sed 's/^PARENT|//')
WIRE_LINE=$(echo "$DOSSIER" | tr '#' '\n' | grep '^WIRE_SPEC|' | sed 's/^WIRE_SPEC|//')

[ -n "$PARENT_LINE" ] && { echo "" >&2; echo "  Parent entity: $PARENT_LINE  (parent shape applies too)" >&2; }
[ -n "$WIRE_LINE" ]   && { echo "" >&2; echo "  Wire spec:  $WIRE_LINE" >&2; }

cat >&2 <<EOF

  If your change touches the wire format (field rename, projection change),
  parity layers above should move together.

  (<PROJECT_SLUG>_SKIP_AMBIENT=1 to silence • once per entity per session)

EOF

exit 0
