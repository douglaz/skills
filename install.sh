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

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [SKILL_NAME...]

Install Claude Code and Codex skills from douglaz/skills.

If no skill names are given, all skills are installed.
If skill names are given, only those skills are installed.

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
  local base="$1"
  local found=()
  for d in "$base"/skills/*/; do
    [[ -f "$d/SKILL.md" ]] && found+=("$(basename "$d")")
  done
  printf '%s\n' "${found[@]}"
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
    if [[ "$target_path" == "$install_dir"* ]]; then
      rm "$link"
      echo "Removed symlink: $link"
      ((removed += 1))
    fi
  done

  [[ $removed -eq 0 ]] && echo "No symlinks found in $dir pointing to $install_dir"
}

if $uninstall; then
  for target_dir in "${target_dirs[@]}"; do
    remove_symlinks_from_dir "$target_dir"
  done

  if [[ -d "$install_dir" ]]; then
    read -rp "Also remove cloned repo at $install_dir? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      rm -rf "$install_dir"
      echo "Removed: $install_dir"
    fi
  fi
  exit 0
fi

# Clone or update
if [[ -d "$install_dir/.git" ]]; then
  echo "Updating existing install at $install_dir ..."
  git -C "$install_dir" pull --ff-only
else
  echo "Cloning $REPO_URL to $install_dir ..."
  mkdir -p "$(dirname "$install_dir")"
  git clone "$REPO_URL" "$install_dir"
fi

# Determine which skills to install
if [[ ${#skills[@]} -eq 0 ]]; then
  mapfile -t skills < <(discover_skills "$install_dir")
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

echo
if [[ $skipped_count -eq 0 && $missing_count -eq 0 ]]; then
  echo "Done."
else
  echo "Install completed with warnings."
fi
echo "Requested ${#skills[@]} skill(s) across ${#target_dirs[@]} target(s)."
echo "Actions: installed=$installed_count updated=$updated_count migrated=$migrated_count already-linked=$already_linked_count skipped=$skipped_count missing=$missing_count"
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
