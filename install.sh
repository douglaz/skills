#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# skills installer
# Clones (or updates) the repo and symlinks skills into Claude and/or Codex.

REPO_URL="https://github.com/douglaz/skills.git"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/douglaz-skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
DEFAULT_CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
LEGACY_CODEX_SKILLS_DIR="$HOME/.agents/skills"
ORIGINAL_ARGS=("$@")
SCRIPT_PATH=""
SCRIPT_CKSUM=""
if [[ -f "$0" ]]; then
  SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")
  SCRIPT_CKSUM=$(cksum < "$SCRIPT_PATH") \
    || { echo "Cannot checksum running installer at $SCRIPT_PATH" >&2; exit 1; }
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [SKILL_NAME...]

Install Claude Code and Codex skills from douglaz/skills.

If no skill names are given, all skills are installed.
If skill names are given, those skills and their required companions are installed.

Options:
  --dir DIR    Install to DIR instead of $DEFAULT_INSTALL_DIR
  --target T   Install into claude, codex, or both (default: both)
  --migrate-existing
               Back up existing skill directories that look like installed
               copies, then replace them with symlinks
  --uninstall  Remove skill symlinks and optionally the cloned repo
  -h, --help   Show this help

Examples:
  $(basename "$0")                                 # install all skills to Claude and Codex
  $(basename "$0") --target codex plan-to-beads-transfer
  $(basename "$0") --target codex --migrate-existing plan-to-beads-transfer
  $(basename "$0") --target both bead-polish-loop second-model-bead-audit
  $(basename "$0") --target both --uninstall       # remove installed symlinks
EOF
}

install_dir="$DEFAULT_INSTALL_DIR"
uninstall=false
migrate_existing=false
target="both"
skills=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)       install_dir="$2"; shift 2 ;;
    --target)    target="$2"; shift 2 ;;
    --migrate-existing) migrate_existing=true; shift ;;
    --uninstall) uninstall=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)           skills+=("$1"); shift ;;
  esac
done

explicit_skill_count=${#skills[@]}

case "$target" in
  claude)
    target_dirs=("$CLAUDE_SKILLS_DIR")
    ;;
  codex)
    if [[ -d "$DEFAULT_CODEX_SKILLS_DIR" || ! -d "$LEGACY_CODEX_SKILLS_DIR" ]]; then
      target_dirs=("$DEFAULT_CODEX_SKILLS_DIR")
    else
      target_dirs=("$LEGACY_CODEX_SKILLS_DIR")
    fi
    ;;
  both)
    if [[ -d "$DEFAULT_CODEX_SKILLS_DIR" || ! -d "$LEGACY_CODEX_SKILLS_DIR" ]]; then
      target_dirs=("$CLAUDE_SKILLS_DIR" "$DEFAULT_CODEX_SKILLS_DIR")
    else
      target_dirs=("$CLAUDE_SKILLS_DIR" "$LEGACY_CODEX_SKILLS_DIR")
    fi
    ;;
  *)
    echo "Unknown target: $target" >&2
    usage
    exit 1
    ;;
esac

# Discover available skills in the repo
discover_skills() {
  local base="$1" d
  local found=()
  for d in "$base"/skills/*/; do
    # Matches .gitignore: eval-creator `*-workspace` scaffolds are not skills.
    [[ ${d%/} == *-workspace ]] && continue
    [[ -f "$d/SKILL.md" ]] && found+=("$(basename "$d")")
  done
  printf '%s\n' "${found[@]}"
}

# Exact-name companion skills hold mandatory continuations that no longer fit inside
# their owners' model-visible Tau prefix. A selective install must keep those handoffs
# loadable just as an all-skill install does. List only companions introduced by this
# repository split; this is not a general dependency solver for workflow routing.
companion_dependencies() {
  case "$1" in
    multi-reviewer-loop)
      printf '%s\n' multi-reviewer-loop-delegating-edits
      ;;
    multi-reviewer-loop-delegating-edits)
      printf '%s\n' multi-reviewer-loop
      ;;
    orchestrating-with-rb-lite|bead-polish-loop|plan-to-beads-transfer|second-model-bead-audit)
      printf '%s\n' rb-lite-backlog-drain
      ;;
    rb-lite-backlog-drain)
      printf '%s\n' orchestrating-with-rb-lite
      ;;
    pr-with-codex-bot-review)
      printf '%s\n' pr-with-codex-bot-review-merge
      ;;
    pr-with-codex-bot-review-merge)
      printf '%s\n' pr-with-codex-bot-review
      ;;
    drive)
      printf '%s\n' rb-lite-backlog-drain pr-with-codex-bot-review-merge
      ;;
  esac
}

append_skill_once() {
  local candidate="$1" existing

  for existing in "${skills[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  skills+=("$candidate")
}

expand_companion_dependencies() {
  local requested=("${skills[@]}")
  local skill dependency index=0

  # This function is called only for a non-empty explicit request. Seed the array before
  # append_skill_once inspects it: Bash 4.0-4.3 treats "${empty[@]}" as unbound under
  # `set -u`, even though newer Bash accepts it.
  skills=("${requested[0]}")
  index=1
  while [[ $index -lt ${#requested[@]} ]]; do
    append_skill_once "${requested[$index]}"
    index=$((index + 1))
  done

  # Walk the finite graph to closure. Companion -> owner edges matter when a sibling
  # consumer requests the companion directly; owner -> companion edges then complete
  # the cycle without duplication.
  index=0
  while [[ $index -lt ${#skills[@]} ]]; do
    skill=${skills[$index]}
    while IFS= read -r dependency; do
      [[ -n "$dependency" ]] || continue
      append_skill_once "$dependency"
    done < <(companion_dependencies "$skill")
    index=$((index + 1))
  done
}

skill_declares_exact_name() {
  local skill_file="$1" expected="$2"

  # Repository skills use one plain `name:` scalar in a closed YAML frontmatter block.
  # Fail conservatively on malformed or duplicate declarations: Tau indexes the declared
  # name, so a SKILL.md merely present at the expected path does not satisfy an exact-name
  # handoff.
  LC_ALL=C awk -v expected="$expected" '
    NR == 1 {
      if ($0 != "---") exit 1
      next
    }
    $0 == "---" {
      closed = 1
      exit (names == 1 && matched == 1) ? 0 : 1
    }
    /^name:/ {
      names++
      if ($0 == "name: " expected) matched++
    }
    END {
      if (!closed) exit 1
    }
  ' "$skill_file"
}

reconcile_target_companions() {
  local target_dir="$1" link target_path skill dependency
  local dependency_source dependency_target processed='|'
  local managed_skills=("")

  # A pull updates every already-linked owner in place. Repair only inside the target
  # where that owner is already managed: unioning target inventories would silently make
  # a Claude-only skill trigger-eligible in Codex (or vice versa).
  # Snapshot the pre-reconciliation inventory. Following links created by this pass would
  # turn companion -> owner back-references into an unsolicited transitive install of
  # standalone workflow selectors. An explicit selective request still gets full closure
  # through expand_companion_dependencies; upgrade repair is deliberately one hop.
  for link in "$target_dir"/*; do
    [[ -L "$link" ]] || continue
    target_path=$(readlink "$link")
    [[ "$target_path" == "$install_dir"/skills/* ]] || continue
    skill=${target_path#"$install_dir"/skills/}
    [[ $skill != */* && -f "$install_dir/skills/$skill/SKILL.md" ]] || continue
    managed_skills+=("$skill")
  done

  for skill in "${managed_skills[@]}"; do
    [[ -n "$skill" ]] || continue
    while IFS= read -r dependency; do
      [[ -n "$dependency" ]] || continue
      # One target path can be required by several installed skills. Diagnose and count
      # that path once; the action summary reports paths, not graph edges.
      [[ $processed == *"|$dependency|"* ]] && continue
      processed+="$dependency|"
      dependency_source="$install_dir/skills/$dependency"
      dependency_target="$target_dir/$dependency"
      if [[ ! -f "$dependency_source/SKILL.md" ]] \
         || ! skill_declares_exact_name "$dependency_source/SKILL.md" "$dependency"; then
        echo "  $dependency [$target_dir]: WARNING - required companion source is missing or declares the wrong skill name"
        ((missing_count += 1))
        continue
      fi
      # Any live skill at the exact target name satisfies discovery. Reconciliation
      # never migrates or overwrites an unrequested plain directory or external link.
      if [[ -f "$dependency_target/SKILL.md" ]] \
         && skill_declares_exact_name "$dependency_target/SKILL.md" "$dependency"; then
        continue
      fi
      if [[ -e "$dependency_target" || -L "$dependency_target" ]]; then
        echo "  $dependency [$target_dir]: WARNING - required companion path exists but is not a loadable skill"
        ((skipped_count += 1))
        continue
      fi
      ln -s "$dependency_source" "$dependency_target"
      echo "  $dependency [$target_dir]: installed as companion of existing $skill"
      ((installed_count += 1))
      ((reconciled_count += 1))
    done < <(companion_dependencies "$skill")
  done
}

list_relative_paths() {
  local dir="$1"
  (
    cd "$dir"
    find . -mindepth 1 -print | sed 's#^\./##' | LC_ALL=C sort
  )
}

looks_like_installed_skill_copy() {
  local existing_dir="$1"
  local source_dir="$2"
  local rel_path

  [[ -d "$existing_dir" && -f "$existing_dir/SKILL.md" ]] || return 1
  [[ -d "$source_dir" && -f "$source_dir/SKILL.md" ]] || return 1

  while IFS= read -r rel_path; do
    [[ -e "$source_dir/$rel_path" || -L "$source_dir/$rel_path" ]] || return 1
  done < <(list_relative_paths "$existing_dir")

  return 0
}

next_backup_path() {
  local path="$1"
  local stamp="$2"
  local candidate="${path}.backup.${stamp}"
  local suffix=1

  while [[ -e "$candidate" ]]; do
    candidate="${path}.backup.${stamp}.${suffix}"
    ((suffix += 1))
  done

  printf '%s\n' "$candidate"
}

remove_symlinks_from_dir() {
  local dir="$1"
  local removed=0
  local target_path

  [[ -d "$dir" ]] || {
    echo "No target directory at $dir"
    return
  }

  for link in "$dir"/*; do
    [[ -L "$link" ]] || continue
    target_path=$(readlink "$link")
    if [[ "$target_path" == "$install_dir"/* ]]; then
      rm "$link"
      echo "Removed symlink: $link"
      ((removed += 1))
    fi
  done

  # An `if`, not `[[ ... ]] && echo`: that form returns 1 whenever it DID remove
  # something, the function propagates that to its caller, and `set -e` then aborts the
  # target loop mid-way — so `--target both` cleaned Claude, left Codex linked, skipped
  # the clone prompt, and printed no error. The failure fired only when the removal
  # succeeded, which is why it read as a clean uninstall.
  if [[ $removed -eq 0 ]]; then
    echo "No symlinks found in $dir pointing to $install_dir"
  fi
}

# Drop installer-managed symlinks whose source is gone (skill renamed or removed
# upstream). Only touches links that point into $install_dir and no longer
# resolve, so a live skill or a user's own symlink is never at risk.
prune_dangling_symlinks() {
  local dir="$1"
  local target_path

  [[ -d "$dir" ]] || return 0

  for link in "$dir"/*; do
    [[ -L "$link" ]] || continue
    [[ -e "$link" ]] && continue
    target_path=$(readlink "$link")
    if [[ "$target_path" == "$install_dir"/* ]]; then
      rm "$link"
      echo "  $(basename "$link") [$dir]: pruned stale symlink (source no longer in repo)"
      ((pruned_count += 1))
    fi
  done
}

if $uninstall; then
  for target_dir in "${target_dirs[@]}"; do
    remove_symlinks_from_dir "$target_dir"
  done

  if [[ -d "$install_dir" ]]; then
    # `|| true`, because EOF makes `read` exit 1 and under `set -e` that aborts before
    # the `exit 0` below — a non-interactive uninstall reported failure for work that had
    # fully succeeded. Not `|| answer=""`: on EOF `read` still assigns whatever it read
    # first, so `printf y | ...` (no trailing newline) sets answer=y AND exits 1, and
    # clearing it there discards a real affirmative. An input-less EOF leaves it empty on
    # its own, which is the declined [y/N] default.
    read -rp "Also remove cloned repo at $install_dir? [y/N] " answer || true
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      rm -rf "$install_dir"
      echo "Removed: $install_dir"
    fi
  fi
  exit 0
fi

# Clone or update. The process re-execed just below inherits a one-shot skip: the first
# process already completed this mutable network step, so repeating it could fail after a
# successful update or advance the script again while the reexec guard suppresses a retry.
if [[ ${DOUGLAZ_INSTALL_SKIP_UPDATE_ONCE:-0} == 1 ]]; then
  echo "Using the clone already updated by the previous installer process ..."
  unset DOUGLAZ_INSTALL_SKIP_UPDATE_ONCE
else
  if [[ -d "$install_dir/.git" ]]; then
    echo "Updating existing install at $install_dir ..."
    git -C "$install_dir" pull --ff-only
  else
    echo "Cloning $REPO_URL to $install_dir ..."
    mkdir -p "$(dirname "$install_dir")"
    git clone "$REPO_URL" "$install_dir"
  fi
fi

# A pipe (`curl ... | bash`) has no readable script path, and `git pull` can replace a
# file while its Bash process keeps executing old bytes. Re-exec the clone's installer
# after clone/update when the source was stdin or its checksum changed. Preserve argv,
# guard the second run, and avoid expanding an empty array under Bash 4.0-4.3 + `set -u`.
INSTALLED_SCRIPT=$(cd "$install_dir" && pwd -P)/install.sh
if [[ ${DOUGLAZ_INSTALL_REEXECED:-0} != 1 && -f "$INSTALLED_SCRIPT" ]]; then
  INSTALLED_CKSUM=$(cksum < "$INSTALLED_SCRIPT") \
    || { echo "Cannot checksum updated installer at $INSTALLED_SCRIPT" >&2; exit 1; }
  if [[ -z "$SCRIPT_CKSUM" || "$SCRIPT_CKSUM" != "$INSTALLED_CKSUM" ]]; then
    echo "Installer source changed; re-executing the clone's version ..."
    if [[ ${#ORIGINAL_ARGS[@]} -eq 0 ]]; then
      DOUGLAZ_INSTALL_REEXECED=1 DOUGLAZ_INSTALL_SKIP_UPDATE_ONCE=1 \
        exec bash "$INSTALLED_SCRIPT"
    else
      DOUGLAZ_INSTALL_REEXECED=1 DOUGLAZ_INSTALL_SKIP_UPDATE_ONCE=1 \
        exec bash "$INSTALLED_SCRIPT" "${ORIGINAL_ARGS[@]}"
    fi
  fi
fi

# Determine which skills to install
if [[ ${#skills[@]} -eq 0 ]]; then
  mapfile -t skills < <(discover_skills "$install_dir")
else
  expand_companion_dependencies
fi

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "No skills found in $install_dir/skills/"
  exit 1
fi

installed_count=0
updated_count=0
already_linked_count=0
migrated_count=0
skipped_count=0
missing_count=0
migration_hint_count=0
pruned_count=0
reconciled_count=0
backup_stamp=$(date -u +%Y%m%dT%H%M%SZ)

# Ensure target directories exist
for target_dir in "${target_dirs[@]}"; do
  mkdir -p "$target_dir"
done

# Symlink each skill into each selected target
for skill in "${skills[@]}"; do
  skill_source="$install_dir/skills/$skill"

  if [[ ! -d "$skill_source" ]]; then
    echo "WARNING: skill '$skill' not found at $skill_source, skipping"
    ((missing_count += 1))
    continue
  fi

  for target_dir in "${target_dirs[@]}"; do
    symlink_target="$target_dir/$skill"

    if [[ -L "$symlink_target" ]]; then
      current=$(readlink "$symlink_target")
      if [[ "$current" == "$skill_source" ]]; then
        echo "  $skill [$target_dir]: already linked"
        ((already_linked_count += 1))
      else
        ln -sfn "$skill_source" "$symlink_target"
        echo "  $skill [$target_dir]: updated symlink"
        ((updated_count += 1))
      fi
    elif [[ -d "$symlink_target" ]] && looks_like_installed_skill_copy "$symlink_target" "$skill_source"; then
      if $migrate_existing; then
        backup_path=$(next_backup_path "$symlink_target" "$backup_stamp")
        mv "$symlink_target" "$backup_path"
        ln -s "$skill_source" "$symlink_target"
        echo "  $skill [$target_dir]: migrated existing directory to $backup_path"
        ((migrated_count += 1))
      else
        echo "  $skill [$target_dir]: WARNING - existing directory looks like an installed skill copy; rerun with --migrate-existing to back it up and replace it with a symlink"
        ((skipped_count += 1))
        ((migration_hint_count += 1))
      fi
    elif [[ -e "$symlink_target" ]]; then
      echo "  $skill [$target_dir]: WARNING - $symlink_target exists and is not a symlink, skipping"
      ((skipped_count += 1))
    else
      ln -s "$skill_source" "$symlink_target"
      echo "  $skill [$target_dir]: installed"
      ((installed_count += 1))
    fi
  done
done

for target_dir in "${target_dirs[@]}"; do
  prune_dangling_symlinks "$target_dir"
  reconcile_target_companions "$target_dir"
done

echo
if [[ $skipped_count -eq 0 && $missing_count -eq 0 ]]; then
  echo "Done."
else
  echo "Install completed with warnings."
fi
if [[ $explicit_skill_count -eq 0 ]]; then
  echo "Selected ${#skills[@]} skill(s) across ${#target_dirs[@]} target(s)."
else
  echo "Requested $explicit_skill_count skill(s); selected ${#skills[@]} including required companions across ${#target_dirs[@]} target(s)."
fi
echo "Reconciled $reconciled_count missing companion(s) for existing managed skills."
echo "Actions: installed=$installed_count updated=$updated_count migrated=$migrated_count already-linked=$already_linked_count skipped=$skipped_count missing=$missing_count pruned=$pruned_count"
echo "Targets:"
for target_dir in "${target_dirs[@]}"; do
  echo "  - $target_dir"
done
if [[ $migration_hint_count -gt 0 && $migrate_existing == false ]]; then
  echo "Tip: rerun with --migrate-existing to back up and replace existing installer-managed skill directories."
fi
echo "Claude Code: use /<skill-name>."
echo "Codex: mention the skill by name in your request."

if [[ $skipped_count -gt 0 || $missing_count -gt 0 ]]; then
  exit 1
fi
