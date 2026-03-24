#!/usr/bin/env bash
set -euo pipefail

# skills installer
# Clones (or updates) the repo and symlinks skills into ~/.claude/skills/

REPO_URL="https://github.com/douglaz/skills.git"
DEFAULT_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-skills"
SKILLS_DIR="$HOME/.claude/skills"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [SKILL_NAME...]

Install Claude Code skills from douglaz/skills.

If no skill names are given, all skills are installed.
If skill names are given, only those skills are installed.

Options:
  --dir DIR    Install to DIR instead of $DEFAULT_INSTALL_DIR
  --uninstall  Remove skill symlinks and optionally the cloned repo
  -h, --help   Show this help

Examples:
  $(basename "$0")                    # install all skills
  $(basename "$0") codex-review-loop  # install only codex-review-loop
  $(basename "$0") --uninstall        # remove all skills
EOF
}

install_dir="$DEFAULT_INSTALL_DIR"
uninstall=false
skills=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)       install_dir="$2"; shift 2 ;;
    --uninstall) uninstall=true; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)           skills+=("$1"); shift ;;
  esac
done

# Discover available skills in the repo
discover_skills() {
  local base="$1"
  local found=()
  for d in "$base"/skills/*/; do
    [[ -f "$d/SKILL.md" ]] && found+=("$(basename "$d")")
  done
  printf '%s\n' "${found[@]}"
}

if $uninstall; then
  # Find all symlinks in SKILLS_DIR that point into install_dir
  removed=0
  if [[ -d "$SKILLS_DIR" ]]; then
    for link in "$SKILLS_DIR"/*/; do
      link="${link%/}"
      [[ -L "$link" ]] || continue
      target=$(readlink "$link")
      if [[ "$target" == "$install_dir"* ]]; then
        rm "$link"
        echo "Removed symlink: $link"
        ((removed++))
      fi
    done
  fi
  [[ $removed -eq 0 ]] && echo "No symlinks found pointing to $install_dir"

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

# Ensure target directory exists
mkdir -p "$SKILLS_DIR"

# Symlink each skill
for skill in "${skills[@]}"; do
  skill_source="$install_dir/skills/$skill"
  symlink_target="$SKILLS_DIR/$skill"

  if [[ ! -d "$skill_source" ]]; then
    echo "WARNING: skill '$skill' not found at $skill_source, skipping"
    continue
  fi

  if [[ -L "$symlink_target" ]]; then
    current=$(readlink "$symlink_target")
    if [[ "$current" == "$skill_source" ]]; then
      echo "  $skill: already linked"
    else
      ln -sfn "$skill_source" "$symlink_target"
      echo "  $skill: updated symlink"
    fi
  elif [[ -e "$symlink_target" ]]; then
    echo "  $skill: WARNING - $symlink_target exists and is not a symlink, skipping"
  else
    ln -s "$skill_source" "$symlink_target"
    echo "  $skill: installed"
  fi
done

echo ""
echo "Done! Installed ${#skills[@]} skill(s). Use /<skill-name> in Claude Code."
