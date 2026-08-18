#!/usr/bin/env bash
set -euo pipefail
BR=${1:?usage: probe /absolute/path/to/br-v0.3.2}
ASSET=${2:?usage: probe br tarball}
PATH=$(command -p getconf PATH)
export PATH
ROOT=$(mktemp -d /tmp/e3-native-br.XXXXXX)
trap 'rm -rf "$ROOT"' EXIT
export HOME="$ROOT/home"; mkdir "$HOME"
# Normalize rendering/logging knobs so the retained transcript is deterministic.
for n in $(env | sed -n 's/^\(GIT_[^=]*\)=.*/\1/p; s/^\(PYTHON[^=]*\)=.*/\1/p; s/^\(BEADS_[^=]*\)=.*/\1/p; s/^\(BD_[^=]*\)=.*/\1/p'); do unset "$n"; done
unset BR_OUTPUT_FORMAT TOON_DEFAULT_FORMAT TOON_STATS RUST_LOG
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export XDG_CONFIG_HOME="$ROOT/xdg-config" XDG_CACHE_HOME="$ROOT/xdg-cache"
export PYTHONNOUSERSITE=1 PYTHONSAFEPATH=1
mkdir "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
export NO_COLOR=1
# Authoritative release asset and checksum listing:
# https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.3.2/br-0.3.2-linux_x86_64.tar.gz
# https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.3.2/SHA256SUMS
python3 -I - "$ASSET" "$BR" <<'PYHASH'
import hashlib, sys
expected = {
    "ARCHIVE": "e67c560e77e912490e44a65e3e9c13205210d171e729c5d801072ee508207288",
    "BINARY": "590aebae292bca9d36bf90d3219dcb27a3536f402864841b2a11d5c07c4c6c63",
}
for label, path in zip(("ARCHIVE", "BINARY"), sys.argv[1:]):
    digestor = hashlib.sha256()
    with open(path, "rb") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digestor.update(chunk)
    digest = digestor.hexdigest()
    print(f"{label}_SHA256={digest}")
    if digest != expected[label]:
        raise SystemExit(f"unexpected {label.lower()} digest")
PYHASH
VERSION_JSON=$("$BR" --no-auto-import --no-auto-flush version --json)
printf 'VERSION_JSON=%s\n' "$VERSION_JSON"
python3 -I - "$VERSION_JSON" <<'PYVERSION'
import json, sys
value = json.loads(sys.argv[1])
expected = {
    "version": "0.3.2",
    "build": "release",
    "commit": "4104c31e79bf806f53e2eba0a4cd2ba6c594f8b9",
}
if any(value.get(key) != expected_value for key, expected_value in expected.items()):
    raise SystemExit("unexpected br release identity")
PYVERSION

seed=$ROOT/seed; clone=$ROOT/clone; mkdir "$seed"; cd "$seed"
git init -q; git config user.email probe@example.invalid; git config user.name Probe; mkdir .beads
"$BR" init --prefix p --quiet
A=$("$BR" create alpha --silent); B=$("$BR" create beta --silent); C=$("$BR" create gamma --silent)
"$BR" --no-auto-import --no-auto-flush comments add "$C" --message preserved >/dev/null
"$BR" sync --flush-only --quiet
git add .beads; git commit -qm seed
git clone -q "$seed" "$clone"; cd "$clone"; git config user.email probe@example.invalid; git config user.name Probe
FRESH_DB_BEFORE=$(test -e .beads/beads.db && echo present || echo absent)
printf 'FRESH_DB_BEFORE=%s\n' "$FRESH_DB_BEFORE"
[[ $FRESH_DB_BEFORE == absent ]]
set +e; "$BR" sync --import-only >import.out 2>import.err; irc=$?; set -e
printf 'IMPORT_RC=%s IMPORT_STDOUT_BYTES=%s IMPORT_STDERR_BYTES=%s\n' "$irc" "$(wc -c <import.out)" "$(wc -c <import.err)"
[[ $irc -eq 0 && ! -s import.err ]]
set +e; "$BR" --no-auto-import --no-auto-flush sync --reconcile-additive --json >rec.json 2>rec.err; rrc=$?; set -e
python3 -I - "$rrc" <<'PY'
import json,sys
x=json.load(open('rec.json'))
print('RECONCILE_RC='+sys.argv[1]+' RECONCILE_STDERR_BYTES='+str(len(open('rec.err','rb').read())))
projection = {k:x.get(k) for k in ('schema','tool_version','status','conflicted','conflict_occurrences','db_only_preserved','postcommit_failures')}
print('RECONCILE_PROJECTION='+json.dumps(projection,sort_keys=True,separators=(',',':')))
expected = {'schema':'br.sync.additive-reconciliation.v2','tool_version':'0.3.2','status':'no_changes','conflicted':0,'conflict_occurrences':0,'db_only_preserved':0,'postcommit_failures':[]}
if sys.argv[1] != '0' or projection != expected or open('rec.err','rb').read(): raise SystemExit('unexpected reconciliation result')
PY

"$BR" dep add "$B" "$A" --quiet
set +e; "$BR" --no-auto-import --no-auto-flush close "$B" --reason blocked --transition-comment must-not-land >/dev/null 2>blocked.err; brc=$?; set -e
bst=$("$BR" --no-auto-import --no-auto-flush show "$B" --json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)[0]["status"])')
bcc=$("$BR" --no-auto-import --no-auto-flush comments list "$B" --json | python3 -I -c 'import json,sys; print(len(json.load(sys.stdin)))')
printf 'BLOCKED_CLOSE_RC=%s STATUS=%s COMMENTS=%s\n' "$brc" "$bst" "$bcc"
[[ $brc -eq 3 && $bst == open && $bcc -eq 0 ]]

cp .beads/issues.jsonl before.jsonl
reason='work_pr=https://github.com/o/r/pull/1 merge_sha=0123456789012345678901234567890123456789'
set +e; "$BR" --no-auto-import --no-auto-flush close "$C" --reason "$reason" --transition-comment evidence >/dev/null 2>close.err; crc=$?; set -e
set +e; "$BR" --no-auto-import --no-auto-flush sync --flush-only >/dev/null 2>flush.err; frc=$?; set -e
python3 -I - "$C" "$crc" "$frc" <<'PY'
import json,sys
id,crc,frc=sys.argv[1:]
before_rows=[json.loads(line) for line in open('before.jsonl')]
after_rows=[json.loads(line) for line in open('.beads/issues.jsonl')]
before_ids=[row['id'] for row in before_rows]; after_ids=[row['id'] for row in after_rows]
if len(before_ids) != len(set(before_ids)) or len(after_ids) != len(set(after_ids)): raise SystemExit('duplicate JSONL ID')
if len(before_rows) != len(after_rows): raise SystemExit('JSONL row count changed')
b={x['id']:x for x in before_rows}; a={x['id']:x for x in after_rows}
if set(b) != set(a): raise SystemExit('JSONL ID set changed')
def field_changes(left, right):
    return [field for field in sorted(set(left) | set(right))
            if (field in left) != (field in right)
            or (field in left and left[field] != right[field])]
changed={k:field_changes(b[k],a[k]) for k in b}
changed={k:v for k,v in changed.items() if v}
x=a[id]
before_comments=b[id].get('comments',[])
after_comments=x.get('comments',[])
remaining=list(after_comments)
for existing in before_comments:
    try:
        remaining.remove(existing)
    except ValueError:
        raise SystemExit('existing comment was not preserved')
print(f'SUCCESS_CLOSE_RC={crc} FLUSH_RC={frc} CLOSE_STDERR_BYTES={len(open("close.err","rb").read())} FLUSH_STDERR_BYTES={len(open("flush.err","rb").read())}')
projection={'status':x['status'],'close_reason':x['close_reason'],'comment':remaining[0].get('text') if len(remaining)==1 else None,'changed':changed}
print('SUCCESS_PROJECTION='+json.dumps(projection,sort_keys=True,separators=(',',':')))
print('SUCCESS_CHANGED_FIELDS='+json.dumps(changed[id],separators=(',',':')))
if crc != '0' or frc != '0' or open('close.err','rb').read() or open('flush.err','rb').read(): raise SystemExit('close or flush failed')
if projection['status'] != 'closed' or projection['comment'] != 'evidence' or projection['close_reason'] != 'work_pr=https://github.com/o/r/pull/1 merge_sha=0123456789012345678901234567890123456789': raise SystemExit('wrong close projection')
if len(before_comments) != 1 or before_comments[0].get('text') != 'preserved': raise SystemExit('seeded comment missing before close')
if len(after_comments) != len(before_comments)+1 or len(remaining) != 1: raise SystemExit('comments were not preserved with one addition')
if list(changed) != [id] or changed[id] != ['close_reason','closed_at','comments','status','updated_at']: raise SystemExit('unexpected JSONL delta')
PY

# Equal timestamp drift is rejected by additive reconciliation.
python3 -I - .beads/issues.jsonl "$A" <<'PY'
import json,sys
p,id=sys.argv[1:]; rows=[json.loads(l) for l in open(p)]
for x in rows:
 if x['id']==id: x['description']='same timestamp conflict'
open(p,'w').writelines(json.dumps(x,separators=(',',':'))+'\n' for x in rows)
PY
set +e; "$BR" --no-auto-import --no-auto-flush sync --reconcile-additive --json >conflict.json 2>conflict.err; xrc=$?; set -e
python3 -I - "$xrc" <<'PY'
import json,sys
x=json.load(open('conflict.json'))
stderr=open('conflict.err','rb').read()
print('CONFLICT_RC='+sys.argv[1]+' CONFLICT_STDERR_BYTES='+str(len(stderr))+' STATUS='+str(x.get('status'))+' REASONS='+json.dumps(x.get('conflict_reasons'),sort_keys=True,separators=(',',':')))
if sys.argv[1] != '6' or stderr or x.get('status') != 'conflicted' or x.get('conflict_reasons') != {'equal_timestamp_shared_scalar_drift':1}: raise SystemExit('equal-time conflict was not refused')
PY
# Restore reviewed bytes and recover DB, then demonstrate explicit flush failure.
git checkout -q -- .beads/issues.jsonl
"$BR" sync --import-only --rebuild --quiet
D=$("$BR" create delta --silent --no-auto-flush)
"$BR" --no-auto-import --no-auto-flush close "$D" --reason incomplete --transition-comment evidence >/dev/null
mv .beads/issues.jsonl .beads/issues.saved; mkdir .beads/issues.jsonl
set +e; "$BR" --no-auto-import --no-auto-flush sync --flush-only >fail.out 2>fail.err; ffrc=$?; set -e
dst=$("$BR" --no-auto-import --no-auto-flush show "$D" --json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)[0]["status"])')
printf 'EXPLICIT_FLUSH_FAILURE_RC=%s DB_STATUS=%s STDOUT_BYTES=%s STDERR_BYTES=%s\n' "$ffrc" "$dst" "$(wc -c <fail.out)" "$(wc -c <fail.err)"
[[ $ffrc -eq 7 && $dst == closed && ! -s fail.out && -s fail.err ]]
rmdir .beads/issues.jsonl; mv .beads/issues.saved .beads/issues.jsonl
set +e; "$BR" --no-auto-import --no-auto-flush sync --flush-only >/dev/null 2>retry.err; retry=$?; set -e
jst=$("$BR" --no-db --no-auto-import --no-auto-flush show "$D" --json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)[0]["status"])')
printf 'FLUSH_RETRY_RC=%s JSONL_STATUS=%s STDERR_BYTES=%s\n' "$retry" "$jst" "$(wc -c <retry.err)"
[[ $retry -eq 0 && $jst == closed && ! -s retry.err ]]
