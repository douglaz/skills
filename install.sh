#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# skills installer
# Clones (or updates) the repo and symlinks skills into Claude and/or Codex.

REPO_URL="https://github.com/douglaz/skills.git"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-skills"
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
  --target T   Install into claude, codex, or both (default: claude)
  --uninstall  Remove skill symlinks and optionally the cloned repo
  -h, --help   Show this help

Examples:
  $(basename "$0")                                 # install all skills to Claude
  $(basename "$0") --target codex plan-to-beads-transfer
  $(basename "$0") --target both bead-polish-loop second-model-bead-audit
  $(basename "$0") --target both --uninstall       # remove installed symlinks
EOF
}

install_dir="$DEFAULT_INSTALL_DIR"
uninstall=false
target="claude"
skills=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)       install_dir="$2"; shift 2 ;;
    --target)    target="$2"; shift 2 ;;
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

# Ensure target directories exist
for target_dir in "${target_dirs[@]}"; do
  mkdir -p "$target_dir"
done

# Symlink each skill into each selected target
for skill in "${skills[@]}"; do
  skill_source="$install_dir/skills/$skill"

  if [[ ! -d "$skill_source" ]]; then
    echo "WARNING: skill '$skill' not found at $skill_source, skipping"
    continue
  fi

  for target_dir in "${target_dirs[@]}"; do
    symlink_target="$target_dir/$skill"

    if [[ -L "$symlink_target" ]]; then
      current=$(readlink "$symlink_target")
      if [[ "$current" == "$skill_source" ]]; then
        echo "  $skill [$target_dir]: already linked"
      else
        ln -sfn "$skill_source" "$symlink_target"
        echo "  $skill [$target_dir]: updated symlink"
      fi
    elif [[ -e "$symlink_target" ]]; then
      echo "  $skill [$target_dir]: WARNING - $symlink_target exists and is not a symlink, skipping"
    else
      ln -s "$skill_source" "$symlink_target"
      echo "  $skill [$target_dir]: installed"
    fi
  done
done

echo ""
echo "Done! Installed ${#skills[@]} skill(s) to:"
for target_dir in "${target_dirs[@]}"; do
  echo "  - $target_dir"
done
echo "Claude Code: use /<skill-name>."
echo "Codex: mention the skill by name in your request."
