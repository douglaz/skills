#!/usr/bin/env bash
set -euo pipefail

# codex-review-loop installer
# Clones (or updates) the repo and symlinks the skill into ~/.claude/skills/

SKILL_NAME="codex-review-loop"
REPO_URL="https://github.com/douglaz/codex-review-loop.git"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-skills/$SKILL_NAME"
SKILLS_DIR="$HOME/.claude/skills"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install the $SKILL_NAME skill for Claude Code.

Options:
  --dir DIR    Install to DIR instead of $DEFAULT_INSTALL_DIR
  --uninstall  Remove the skill symlink and optionally the cloned repo
  -h, --help   Show this help
EOF
}

install_dir="$DEFAULT_INSTALL_DIR"
uninstall=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)      install_dir="$2"; shift 2 ;;
    --uninstall) uninstall=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

symlink_target="$SKILLS_DIR/$SKILL_NAME"

if $uninstall; then
  if [[ -L "$symlink_target" ]]; then
    rm "$symlink_target"
    echo "Removed symlink: $symlink_target"
  else
    echo "No symlink found at $symlink_target"
  fi
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

# Ensure skills directory exists
mkdir -p "$SKILLS_DIR"

# Create symlink
skill_source="$install_dir/skills/$SKILL_NAME"

if [[ -L "$symlink_target" ]]; then
  current=$(readlink "$symlink_target")
  if [[ "$current" == "$skill_source" ]]; then
    echo "Symlink already correct: $symlink_target -> $skill_source"
  else
    ln -sfn "$skill_source" "$symlink_target"
    echo "Updated symlink: $symlink_target -> $skill_source"
  fi
elif [[ -e "$symlink_target" ]]; then
  echo "WARNING: $symlink_target already exists and is not a symlink."
  echo "Back it up or remove it, then re-run this script."
  exit 1
else
  ln -s "$skill_source" "$symlink_target"
  echo "Created symlink: $symlink_target -> $skill_source"
fi

echo ""
echo "Installed! Use /codex-review-loop in Claude Code."
