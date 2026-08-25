#!/usr/bin/env bash
set -euo pipefail
# This retained evidence is run by the exact env -i / absolute-Bash invocation recorded in
# the plan. It is not a hostile-shell wrapper.
BR=${1:?usage: probe /absolute/path/to/br-v0.3.2}
ASSET=${2:?usage: probe br tarball}
CANDIDATE_JSONL=${3:?usage: probe br tarball candidate-issues.jsonl}
SAFE_PATH=$(command -p getconf PATH)
[[ $PATH == "$SAFE_PATH" ]]
ROOT=$(mktemp -d /tmp/e3-native-br.XXXXXX)
cleanup() {
  rc=$?
  trap - EXIT
  if (( rc == 0 )); then
    rm -rf "$ROOT"
  else
    printf 'PROBE_FAILED_ROOT=%s\n' "$ROOT" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT
export HOME="$ROOT/home"; mkdir "$HOME"
# Normalize rendering/logging knobs so the retained transcript is deterministic.
for n in $(env | sed -n 's/^\(GIT_[^=]*\)=.*/\1/p; s/^\(PYTHON[^=]*\)=.*/\1/p; s/^\(BEADS_[^=]*\)=.*/\1/p; s/^\(BD_[^=]*\)=.*/\1/p'); do unset "$n"; done
unset BR_OUTPUT_FORMAT TOON_DEFAULT_FORMAT TOON_STATS RUST_LOG
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export XDG_CONFIG_HOME="$ROOT/xdg-config" XDG_CACHE_HOME="$ROOT/xdg-cache"
export PYTHONNOUSERSITE=1 PYTHONSAFEPATH=1
mkdir "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
export NO_COLOR=1 LC_ALL=C TZ=UTC
GIT_VERSION=$(git --version)
PYTHON_VERSION=$(python3 --version 2>&1)
KERNEL_VERSION=$(uname -srm)
printf 'PROBE_ENV=Bash=%s Git=%s Python=%s Kernel=%s\n' \
  "$BASH_VERSION" "$GIT_VERSION" "$PYTHON_VERSION" "$KERNEL_VERSION"
# Authoritative release asset and checksum listing:
# https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.3.2/br-0.3.2-linux_x86_64.tar.gz
# https://github.com/Dicklesworthstone/beads_rust/releases/download/v0.3.2/SHA256SUMS
python3 -I - "$ASSET" "$BR" "$CANDIDATE_JSONL" <<'PYHASH'
import hashlib, sys
expected = {
    "ARCHIVE": "e67c560e77e912490e44a65e3e9c13205210d171e729c5d801072ee508207288",
    "BINARY": "590aebae292bca9d36bf90d3219dcb27a3536f402864841b2a11d5c07c4c6c63",
    "CANDIDATE_JSONL": "7269d4e17a3be4b19f957b4084001e0f529db7453cf667fef84b6e89a85a98eb",
}
if len(sys.argv) != 4:
    raise SystemExit("expected archive, binary, and candidate JSONL")
for label, path in zip(("ARCHIVE", "BINARY", "CANDIDATE_JSONL"), sys.argv[1:]):
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

# Reproduce the installed-0.2.19-export -> v0.3.2 byte-identity measurement.
compat=$ROOT/compat; mkdir -p "$compat/.beads"; cd "$compat"
git init -q; git config user.email probe@example.invalid; git config user.name Probe
cp "$CANDIDATE_JSONL" .beads/issues.jsonl
cp .beads/issues.jsonl compat-before.jsonl
printf '%s\n' '{"database":"beads.db","jsonl_export":"issues.jsonl"}' >.beads/metadata.json
printf '%s\n' '# issue_prefix: skills' >.beads/config.yaml
set +e; "$BR" --no-auto-import --no-auto-flush where --json >compat-where.out 2>compat-where.err; compat_wrc=$?; set -e
python3 -I - "$compat/compat-where.out" "$compat/.beads/issues.jsonl" \
  "$compat/.beads/beads.db" "$ROOT" <<'PYWHERE'
import json, os, sys
value = json.load(open(sys.argv[1]))
if value.get("jsonl_path") != os.path.realpath(sys.argv[2]):
    raise SystemExit("where did not select the candidate JSONL")
database_path = value.get("database_path")
expected_database_path = os.path.realpath(sys.argv[3])
if database_path != expected_database_path:
    raise SystemExit("where did not report the production database_path")
root = os.path.realpath(sys.argv[4])
if not database_path.startswith(root + os.sep):
    raise SystemExit("where database_path escaped the probe root")
print("WHERE_DATABASE_PATH=$PROBE_ROOT" + database_path[len(root):])
PYWHERE
printf 'WHERE_NO_DB_RC=%s STDERR_BYTES=%s DB=%s\n' "$compat_wrc" \
  "$(wc -c <compat-where.err)" "$([[ -e .beads/beads.db ]] && echo present || echo absent)"
[[ $compat_wrc -eq 0 && ! -s compat-where.err && ! -e .beads/beads.db ]]
set +e; "$BR" --no-auto-import --no-auto-flush sync --import-only >compat-import.out 2>compat-import.err; compat_irc=$?; set -e
set +e; "$BR" --no-auto-import --no-auto-flush sync --flush-only >compat-flush.out 2>compat-flush.err; compat_frc=$?; set -e
set +e; cmp -s compat-before.jsonl .beads/issues.jsonl; compat_cmp=$?; set -e
printf 'COMPAT_IMPORT_RC=%s IMPORT_STDOUT_BYTES=%s IMPORT_STDERR_BYTES=%s FLUSH_RC=%s FLUSH_STDOUT_BYTES=%s FLUSH_STDERR_BYTES=%s CMP_RC=%s\n' \
  "$compat_irc" "$(wc -c <compat-import.out)" "$(wc -c <compat-import.err)" \
  "$compat_frc" "$(wc -c <compat-flush.out)" "$(wc -c <compat-flush.err)" "$compat_cmp"
[[ $compat_irc -eq 0 && $compat_frc -eq 0 && $compat_cmp -eq 0 && \
   ! -s compat-import.err && ! -s compat-flush.err ]]

seed=$ROOT/seed; clone=$ROOT/clone; mkdir "$seed"; cd "$seed"
git init -q; git config user.email probe@example.invalid; git config user.name Probe; mkdir .beads
"$BR" init --prefix p --quiet
A=$("$BR" create alpha --silent); B=$("$BR" create beta --silent); C=$("$BR" create gamma --silent); D=$("$BR" create delta-in-progress --silent); E=$("$BR" create outside-scope-decoy --silent); F=$("$BR" create scoped-closed-decoy --status closed --silent); G=$("$BR" create scoped-deferred --silent); H=$("$BR" create unlabeled-generic --silent)
"$BR" --no-auto-import --no-auto-flush label add "$A" --label executor-skills >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$A" --label drive-open-issues >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$B" --label executor-rb-lite >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$B" --label drive-open-issues >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$C" --label authority-human >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$C" --label drive-open-issues >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$D" --label executor-skills >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$D" --label drive-open-issues >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$E" --label executor-rb-lite >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$F" --label executor-skills >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$F" --label drive-open-issues >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$G" --label executor-skills >/dev/null
"$BR" --no-auto-import --no-auto-flush label add "$G" --label drive-open-issues >/dev/null
# `$H` is deliberately never labelled: the generic closure preflight admits a row by the
# ABSENCE of every recognized Drive label, so what an unlabelled row's `labels` field looks
# like on this release decides whether that admission is a real check or a vacuous one.
"$BR" --no-auto-import --no-auto-flush update "$D" --status in_progress >/dev/null
# A scoped row deferred the way this release defers, so the selector's own `list` argv can be
# measured against deferred open work rather than reasoned about from the `status` field.
"$BR" --no-auto-import --no-auto-flush update "$G" --defer 2099-01-01 >/dev/null
"$BR" --no-auto-import --no-auto-flush dep add "$B" "$A" --quiet
"$BR" --no-auto-import --no-auto-flush dep add "$E" "$A" --quiet
"$BR" --no-auto-import --no-auto-flush comments add "$C" --message a-preserved >/dev/null
"$BR" --no-auto-import --no-auto-flush comments add "$C" --message z-preserved >/dev/null
"$BR" sync --flush-only --quiet
python3 -I - .beads/issues.jsonl "$C" <<'PY'
import json,sys
path,issue_id=sys.argv[1:]
rows=[json.loads(line) for line in open(path)]
for row in rows:
    if row['id'] == issue_id:
        for comment in row.get('comments',[]):
            comment['created_at']='2099-01-01T00:00:00Z'
with open(path,'w') as stream:
    stream.writelines(json.dumps(row,separators=(',',':'))+'\n' for row in rows)
PY
"$BR" --no-auto-import --no-auto-flush sync --import-only --rebuild --quiet
"$BR" --no-auto-import --no-auto-flush sync --flush-only --quiet
git add .beads; git commit -qm seed
git clone -q "$seed" "$clone"; cd "$clone"; git config user.email probe@example.invalid; git config user.name Probe
FRESH_DB_BEFORE=$(test -e .beads/beads.db && echo present || echo absent)
printf 'FRESH_DB_BEFORE=%s\n' "$FRESH_DB_BEFORE"
[[ $FRESH_DB_BEFORE == absent ]]
set +e; "$BR" --no-auto-import --no-auto-flush version --json >version-no-db.json 2>version-no-db.err; version_no_db_rc=$?; set -e
printf 'VERSION_NO_DB_RC=%s STDERR_BYTES=%s DB=%s\n' "$version_no_db_rc" \
  "$(wc -c <version-no-db.err)" "$([[ -e .beads/beads.db ]] && echo present || echo absent)"
[[ $version_no_db_rc -eq 0 && ! -s version-no-db.err && ! -e .beads/beads.db &&
   "$(<version-no-db.json)" == "$VERSION_JSON" ]]
set +e
"$BR" --no-db --no-auto-import --no-auto-flush ready --limit 0 --label drive-open-issues --label executor-skills --json >ready-skills.json 2>ready-skills.err; ready_skills_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush ready --limit 0 --label drive-open-issues --label executor-skills --include-deferred --json >ready-skills-deferred.json 2>ready-skills-deferred.err; ready_skills_deferred_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush ready --limit 0 --label drive-open-issues --label executor-rb-lite --json >ready-rb.json 2>ready-rb.err; ready_rb_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush ready --limit 0 --label drive-open-issues --label authority-human --json >ready-human.json 2>ready-human.err; ready_human_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --status open --all --json >list-open.json 2>list-open.err; list_open_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --status open --all --deferred --json >list-open-deferred.json 2>list-open-deferred.err; list_open_deferred_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --status in_progress --all --json >progress-all.json 2>progress-all.err; progress_all_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --status in_progress --all --deferred --json >progress-all-deferred.json 2>progress-all-deferred.err; progress_all_deferred_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --label executor-skills --status in_progress --all --deferred --json >progress-skills-deferred.json 2>progress-skills-deferred.err; progress_skills_deferred_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --label executor-rb-lite --status in_progress --all --deferred --json >progress-rb-deferred.json 2>progress-rb-deferred.err; progress_rb_deferred_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush list --label drive-open-issues --label authority-human --status in_progress --all --deferred --json >progress-human-deferred.json 2>progress-human-deferred.err; progress_human_deferred_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush blocked --limit 0 --label drive-open-issues --json >blocked-all.json 2>blocked-all.err; blocked_all_rc=$?
set -e
python3 -I - "$E" "$F" "$G" "$ready_skills_rc" "$ready_skills_deferred_rc" "$ready_rb_rc" "$ready_human_rc" "$list_open_rc" "$list_open_deferred_rc" "$progress_all_rc" "$progress_all_deferred_rc" "$progress_skills_deferred_rc" "$progress_rb_deferred_rc" "$progress_human_deferred_rc" "$blocked_all_rc" <<'PY'
import json,sys
decoys=set(sys.argv[1:3])
deferred=sys.argv[3]
# The `-deferred` names are the argv the selector now issues; `list-open` and `progress-all`
# are the same queries without the flag, retained as controls so the transcript shows what
# the flag does to each result set rather than asserting it.
names=('ready-skills','ready-skills-deferred','ready-rb','ready-human','list-open',
       'list-open-deferred','progress-all','progress-all-deferred',
       'progress-skills-deferred','progress-rb-deferred','progress-human-deferred',
       'blocked-all')
expected=(1,2,0,1,4,4,1,1,1,0,0,1)
projection={}
selected={}
for name,want,rc in zip(names,expected,sys.argv[4:]):
    payload=json.load(open(name+'.json'))
    stderr=open(name+'.err','rb').read()
    if name.startswith('list-') or name.startswith('progress-'):
        if not isinstance(payload,dict) or not isinstance(payload.get('issues'),list) or \
           type(payload.get('total')) is not int or payload.get('total') != want or \
           payload.get('has_more') is not False:
            raise SystemExit('unexpected selector envelope: '+name)
        rows=payload['issues']
    else:
        rows=payload
    if rc != '0' or stderr or not isinstance(rows,list) or len(rows) != want:
        raise SystemExit('unexpected selector result: '+name)
    if any(row.get('id') in decoys for row in rows):
        raise SystemExit('selector leaked outside-scope decoy: '+name)
    projection[name]=len(rows)
    selected[name]=sorted(row['id'] for row in rows)
print('NO_DB_SELECTOR_PROJECTION='+json.dumps(projection,sort_keys=True,separators=(',',':')))
# Deferral is measured, not inferred from the `status` field. The row must really be deferred
# for this release (absent from `ready`, present under `--include-deferred`), and the
# `--deferred` count argv the selector issues must return it — that is what keeps deferred
# open work inside `unresolved_count` without a second query surface. The two controls say
# what the flag itself changes on this release: on both count queries, nothing.
rows=[json.loads(line) for line in open('.beads/issues.jsonl')]
deferred_row=next((row for row in rows if row.get('id') == deferred), None)
if deferred_row is None:
    raise SystemExit('the deferred fixture row is missing from the JSONL')
deferral={
 'defer_until_is_set': bool(deferred_row.get('defer_until')),
 'jsonl_status': deferred_row.get('status'),
 'absent_from_lane_ready': deferred not in selected['ready-skills'],
 'present_under_include_deferred': deferred in selected['ready-skills-deferred'],
 'counted_by_selector_open_list': deferred in selected['list-open-deferred'],
 'deferred_flag_changes_open_list':
   selected['list-open'] != selected['list-open-deferred'],
 'deferred_flag_changes_progress_list':
   selected['progress-all'] != selected['progress-all-deferred'],
}
print('DEFERRED_OPEN_PROJECTION='+json.dumps(deferral,sort_keys=True,separators=(',',':')))
if deferral != {'defer_until_is_set': True, 'jsonl_status': 'open',
                'absent_from_lane_ready': True, 'present_under_include_deferred': True,
                'counted_by_selector_open_list': True,
                'deferred_flag_changes_open_list': False,
                'deferred_flag_changes_progress_list': False}:
    raise SystemExit('unexpected deferred-row visibility')
# Both `--status in_progress` forms carry the flag, so the exact ID arrays — not just the
# counts — must still partition. A one-sided flag would break this before it reached the
# selector's own partition check.
if sorted(selected['progress-skills-deferred'] + selected['progress-rb-deferred']
          + selected['progress-human-deferred']) != selected['progress-all-deferred']:
    raise SystemExit('the lane in-progress arrays do not partition the global one')
PY
[[ ! -e .beads/beads.db ]]
set +e; "$BR" --no-auto-import --no-auto-flush sync --import-only >import.out 2>import.err; irc=$?; set -e
printf 'IMPORT_RC=%s IMPORT_STDOUT_BYTES=%s IMPORT_STDERR_BYTES=%s\n' "$irc" "$(wc -c <import.out)" "$(wc -c <import.err)"
[[ $irc -eq 0 && ! -s import.err ]]

"$BR" --no-auto-import --no-auto-flush update "$A" --title db-stale-title >/dev/null
stale_ready=$("$BR" --no-db --no-auto-import --no-auto-flush ready --limit 0 --label drive-open-issues --label executor-skills --json)
python3 -I - "$stale_ready" <<'PY'
import json,sys
rows=json.loads(sys.argv[1])
if len(rows) != 1 or rows[0].get('status') != 'open' or rows[0].get('title') != 'alpha':
    raise SystemExit('no-db selector did not ignore stale DB')
print('STALE_DB_NO_DB_READY_COUNT=1')
PY
rm -f .beads/beads.db .beads/beads.db-wal .beads/beads.db-shm .beads/beads.db-journal
"$BR" --no-auto-import --no-auto-flush sync --import-only --quiet
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
projection={'status':x['status'],'close_reason':x['close_reason'],'comment':remaining[0].get('text') if len(remaining)==1 else None}
print('SUCCESS_PROJECTION='+json.dumps(projection,sort_keys=True,separators=(',',':')))
print('SUCCESS_CHANGED_FIELDS='+json.dumps(changed[id],separators=(',',':')))
if crc != '0' or frc != '0' or open('close.err','rb').read() or open('flush.err','rb').read(): raise SystemExit('close or flush failed')
if projection['status'] != 'closed' or projection['comment'] != 'evidence' or projection['close_reason'] != 'work_pr=https://github.com/o/r/pull/1 merge_sha=0123456789012345678901234567890123456789': raise SystemExit('wrong close projection')
if len(before_comments) != 2 or {comment.get('text') for comment in before_comments} != {'a-preserved','z-preserved'}: raise SystemExit('seeded comments missing before close')
if len(after_comments) != len(before_comments)+1 or len(remaining) != 1: raise SystemExit('comments were not preserved with one addition')
if after_comments == before_comments + remaining: raise SystemExit('fixture did not exercise canonical insertion order')
if list(changed) != [id] or changed[id] != ['close_reason','closed_at','comments','status','updated_at']: raise SystemExit('unexpected JSONL delta')
PY

# Step 11 routes on `show --json` row fields, not just on `status`: the pre-close preflight
# reads `labels`, the resume classifier reads `comments[].text` and `close_reason` in BOTH
# `--no-db` and cache mode, and the read-back reads `close_reason`. Pin that payload against
# the real binary rather than against a fixture stub, in every mode a decision reads it from.
set +e
"$BR" --no-db --no-auto-import --no-auto-flush show "$A" --json >show-open-labeled.json 2>show-open-labeled.err; show_open_labeled_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush show "$H" --json >show-unlabeled.json 2>show-unlabeled.err; show_unlabeled_rc=$?
"$BR" --no-db --no-auto-import --no-auto-flush show "$C" --json >show-closed-no-db.json 2>show-closed-no-db.err; show_closed_no_db_rc=$?
"$BR" --no-auto-import --no-auto-flush show "$C" --json >show-closed-db.json 2>show-closed-db.err; show_closed_db_rc=$?
set -e
python3 -I - "$A" "$H" "$C" "$reason" "$show_open_labeled_rc" "$show_unlabeled_rc" "$show_closed_no_db_rc" "$show_closed_db_rc" <<'PYSHOW'
import json, sys
open_id, unlabeled_id, closed_id, reason = sys.argv[1:5]
names = ('show-open-labeled', 'show-unlabeled', 'show-closed-no-db', 'show-closed-db')
wanted = {'show-open-labeled': open_id, 'show-unlabeled': unlabeled_id,
          'show-closed-no-db': closed_id, 'show-closed-db': closed_id}
projection = {}
for name, rc in zip(names, sys.argv[5:]):
    rows = json.load(open(name + '.json'))
    if rc != '0' or open(name + '.err', 'rb').read():
        raise SystemExit('show --json failed: ' + name)
    if not isinstance(rows, list) or len(rows) != 1 or rows[0].get('id') != wanted[name]:
        raise SystemExit('show --json did not return exactly the requested row: ' + name)
    row = rows[0]
    projection[name] = {
        'has_labels': 'labels' in row,
        'labels': sorted(row['labels']) if isinstance(row.get('labels'), list) else row.get('labels'),
        'status': row.get('status'),
        'has_close_reason': 'close_reason' in row,
        'close_reason': row.get('close_reason'),
        'has_comments': 'comments' in row,
        'comment_texts': sorted(comment.get('text') for comment in row.get('comments', [])),
    }
print('SHOW_ROW_PROJECTION=' + json.dumps(projection, sort_keys=True, separators=(',', ':')))
# Measured: this release OMITS `labels`, `comments`, and `close_reason` rather than emitting
# an empty array or null, so absence is this payload's only spelling of "none". That is why
# the consumers read them absence-tolerantly (`.[0].labels[]?`, `.comments[]?`, `label_list`'s
# `has("labels")` fallback) instead of requiring the key: an unlabelled row is proved by the
# missing key, so the generic lane's "carries no recognized Drive label" gate is measuring
# absence, not passing vacuously over a shape it failed to parse.
labeled = {'has_labels': True, 'labels': ['drive-open-issues', 'executor-skills'],
           'status': 'open', 'has_close_reason': False, 'close_reason': None,
           'has_comments': False, 'comment_texts': []}
unlabeled = dict(labeled, has_labels=False, labels=None)
closed = {'has_labels': True, 'labels': ['authority-human', 'drive-open-issues'],
          'status': 'closed', 'has_close_reason': True, 'close_reason': reason,
          'has_comments': True,
          'comment_texts': ['a-preserved', 'evidence', 'z-preserved']}
if projection != {'show-open-labeled': labeled, 'show-unlabeled': unlabeled,
                  'show-closed-no-db': closed, 'show-closed-db': closed}:
    raise SystemExit('unexpected show --json row payload')
PYSHOW

cp .beads/issues.jsonl before-in-progress.jsonl
set +e; "$BR" --no-auto-import --no-auto-flush close "$D" --reason in-progress-probe --transition-comment in-progress-evidence >/dev/null 2>in-progress-close.err; ip_crc=$?; set -e
set +e; "$BR" --no-auto-import --no-auto-flush sync --flush-only >/dev/null 2>in-progress-flush.err; ip_frc=$?; set -e
python3 -I - "$D" "$ip_crc" "$ip_frc" <<'PYINPROGRESS'
import json, sys
issue_id, close_rc, flush_rc = sys.argv[1:]
before = {row["id"]: row for row in map(json.loads, open("before-in-progress.jsonl"))}
after = {row["id"]: row for row in map(json.loads, open(".beads/issues.jsonl"))}
def field_changes(left, right):
    return [field for field in sorted(set(left) | set(right))
            if (field in left) != (field in right)
            or (field in left and left[field] != right[field])]
changed = {key: field_changes(before[key], after[key]) for key in before}
changed = {key: fields for key, fields in changed.items() if fields}
fields = changed.get(issue_id)
print(f'IN_PROGRESS_CLOSE_RC={close_rc} FLUSH_RC={flush_rc} CLOSE_STDERR_BYTES={len(open("in-progress-close.err","rb").read())} FLUSH_STDERR_BYTES={len(open("in-progress-flush.err","rb").read())}')
print('IN_PROGRESS_CHANGED_FIELDS=' + json.dumps(fields, separators=(',', ':')))
if close_rc != '0' or flush_rc != '0' or open('in-progress-close.err','rb').read() or open('in-progress-flush.err','rb').read():
    raise SystemExit('in-progress close or flush failed')
if set(before) != set(after) or list(changed) != [issue_id]:
    raise SystemExit('in-progress close changed the JSONL shape or a bystander')
if before[issue_id].get('status') != 'in_progress' or after[issue_id].get('status') != 'closed':
    raise SystemExit('in-progress target did not close')
if after[issue_id].get('close_reason') != 'in-progress-probe':
    raise SystemExit('in-progress close reason did not land')
if fields != ['close_reason', 'closed_at', 'comments', 'status', 'updated_at']:
    raise SystemExit('unexpected in-progress close field set')
PYINPROGRESS

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
cp .beads/issues.jsonl idempotent-before.jsonl
set +e; "$BR" --no-auto-import --no-auto-flush sync --flush-only >idempotent.out 2>idempotent.err; idempotent_rc=$?; set -e
set +e; cmp -s idempotent-before.jsonl .beads/issues.jsonl; idempotent_cmp=$?; set -e
printf 'IDEMPOTENT_FLUSH_RC=%s STDOUT_BYTES=%s STDERR_BYTES=%s CMP_RC=%s\n' \
  "$idempotent_rc" "$(wc -c <idempotent.out)" "$(wc -c <idempotent.err)" "$idempotent_cmp"
[[ $idempotent_rc -eq 0 && $idempotent_cmp -eq 0 && ! -s idempotent.err ]]
