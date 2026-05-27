#!/usr/bin/env bash
# install.sh — set up research-infra skills for Claude Code.
#
# Usage:
#   # local (after git clone):
#   ./install.sh
#
#   # one-shot from anywhere (clones first if needed):
#   curl -fsSL https://raw.githubusercontent.com/triquang26/research-infra/main/install.sh | bash
#
# Env:
#   RESEARCH_INFRA_DIR   — where to clone repo (default: $HOME/research-infra)
#   RESEARCH_INFRA_REPO  — repo URL (default: github.com/triquang26/research-infra)
#   COPY_MODE=1          — copy skills instead of symlinking (useful when repo lives
#                          on a non-persistent filesystem)

set -euo pipefail

REPO_URL="${RESEARCH_INFRA_REPO:-https://github.com/triquang26/research-infra.git}"
INSTALL_DIR="${RESEARCH_INFRA_DIR:-$HOME/research-infra}"
SKILLS_DEST="$HOME/.claude/skills"
COPY_MODE="${COPY_MODE:-0}"

color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
ok()    { echo "$(color '0;32' '[OK]') $*"; }
warn()  { echo "$(color '1;33' '[!!]') $*" >&2; }
err()   { echo "$(color '0;31' '[XX]') $*" >&2; exit 1; }
info()  { echo "$(color '0;34' '[..]') $*"; }

# ----- 1. Resolve repo source -----
# If we're invoked from within an already-cloned repo, prefer that.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$SELF_DIR/skills/_shared/lib.sh" ]]; then
  REPO_DIR="$SELF_DIR"
  info "Using local repo at $REPO_DIR"
else
  REPO_DIR="$INSTALL_DIR"
  if [[ -d "$REPO_DIR/.git" ]]; then
    info "Updating existing clone at $REPO_DIR..."
    git -C "$REPO_DIR" pull --ff-only --quiet || warn "git pull failed (continuing with existing checkout)"
  else
    info "Cloning $REPO_URL → $REPO_DIR..."
    git clone --depth 1 "$REPO_URL" "$REPO_DIR" || err "git clone failed"
  fi
fi

# ----- 2. Verify dependencies -----
command -v git     >/dev/null 2>&1 || err "git not found (required)"
command -v python3 >/dev/null 2>&1 || err "python3 not found (required)"

if ! python3 -c "import yaml" 2>/dev/null; then
  info "PyYAML missing — attempting install..."
  if python3 -m pip install --user pyyaml >/dev/null 2>&1; then
    ok "PyYAML installed"
  elif command -v pipx >/dev/null 2>&1; then
    pipx install pyyaml >/dev/null 2>&1 && ok "PyYAML installed via pipx"
  else
    warn "could not auto-install PyYAML. Run manually: python3 -m pip install --user pyyaml"
    warn "skills using frontmatter ops (most of them) will fail until this is fixed."
  fi
else
  ok "PyYAML available"
fi

# ----- 3. Install skills (symlink or copy) -----
mkdir -p "$SKILLS_DEST"

installed=0; skipped=0
for d in "$REPO_DIR"/skills/*/; do
  d="${d%/}"  # strip trailing slash
  name="$(basename "$d")"
  link="$SKILLS_DEST/$name"

  if [[ -L "$link" ]]; then
    target="$(readlink "$link")"
    if [[ "$target" == "$d" ]]; then
      ok "$name already linked"
      ((skipped++))
      continue
    else
      warn "$name → $target (different target); replacing"
      rm "$link"
    fi
  elif [[ -e "$link" ]]; then
    warn "$name exists as real file/dir at $link — skipping (rm it first to install)"
    ((skipped++))
    continue
  fi

  if [[ "$COPY_MODE" == "1" ]]; then
    cp -R "$d" "$link"
    ok "$name copied"
  else
    ln -s "$d" "$link"
    ok "$name linked → $d"
  fi
  ((installed++))
done

# ----- 4. Make Python helper executable -----
chmod +x "$REPO_DIR/skills/_shared/fm.py" 2>/dev/null || true

# ----- 5. Report -----
echo
ok "Done. Installed $installed, skipped $skipped."
echo
echo "Next steps:"
echo "  1. cd into any git repo where you want to track experiments"
echo "  2. Start Claude Code, type:   /exp-init"
echo "  3. Then:                       /exp-new \"<your first hypothesis>\""
echo
echo "Need help? Type   /exp-help"
echo "Docs:             $REPO_DIR/README.md"
