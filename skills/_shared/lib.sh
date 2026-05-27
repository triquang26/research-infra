#!/usr/bin/env bash
# Shared helpers for exp-* skills. Source from a skill's bash block:
#   source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
# Works under both bash and zsh. Caller should set their own `set -e` etc.

# Resolve own directory portably (bash uses BASH_SOURCE, zsh uses $0).
if [ -n "${BASH_SOURCE+x}" ] && [ -n "${BASH_SOURCE[0]}" ]; then
  __exp_self="${BASH_SOURCE[0]}"
elif [ -n "${0:-}" ] && [ -f "${0:-}" ]; then
  __exp_self="$0"
else
  __exp_self=""
fi
if [ -n "$__exp_self" ] && [ -f "$__exp_self" ]; then
  EXP_SHARED_DIR="$(cd "$(dirname "$__exp_self")" && pwd)"
else
  EXP_SHARED_DIR="$HOME/.claude/skills/_shared"
fi
unset __exp_self
EXP_FM_PY="$EXP_SHARED_DIR/fm.py"
EXP_TEMPLATE="$EXP_SHARED_DIR/node_template.md"

# ---------- id / slug ----------

# Random 6-char base36 id. Reject collisions within the vault.
exp_gen_id() {
  local vault=${1:-}
  local id
  while true; do
    id=$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c6)
    if [[ -z "$vault" ]] || [[ ! -d "$vault/nodes" ]]; then
      echo "$id"; return
    fi
    if ! ls "$vault/nodes/" 2>/dev/null | grep -q -- "-${id}-"; then
      echo "$id"; return
    fi
  done
}

# Sluggify: lowercase, replace non-alnum with -, trim.
exp_slugify() {
  local s=$1
  echo "$s" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-50
}

# ---------- vault discovery ----------

# Walk up from $1 (default PWD) to find .experiments/.
# Echoes absolute vault path on stdout, or returns 1.
exp_find_vault() {
  local dir=${1:-$PWD}
  dir=$(cd "$dir" && pwd)
  while [[ "$dir" != "/" ]]; do
    # Prefer visible `experiments/` (Obsidian-friendly); fall back to dot-folder
    if [[ -d "$dir/experiments/nodes" ]]; then
      echo "$dir/experiments"
      return 0
    fi
    if [[ -d "$dir/.experiments/nodes" ]]; then
      echo "$dir/.experiments"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  echo "ERROR: no experiments/ or .experiments/ vault found above $PWD. Run /exp-init first." >&2
  return 1
}

# Echoes the code repo root (the parent of the vault).
exp_repo_root() {
  local vault=$1
  dirname "$vault"
}

# ---------- git state ----------

exp_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

# Extract node id from branch name like "exp/<id>-<slug>".
# Echoes id or empty string. Pure case/glob, portable across bash and zsh.
exp_branch_to_id() {
  local branch=$1
  case "$branch" in
    exp/[a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9][a-z0-9]-*)
      local id=${branch#exp/}
      echo "${id:0:6}"
      ;;
    *) echo "" ;;
  esac
}

exp_current_commit() {
  git rev-parse HEAD 2>/dev/null || echo ""
}

# ---------- node lookup ----------

# Find node file by id. Echoes path or empty.
# Uses find (not glob) so zsh `nomatch` doesn't trip.
exp_node_path() {
  local vault=$1
  local id=$2
  find "$vault/nodes" -maxdepth 1 -type f -name "*-${id}-*.md" 2>/dev/null | head -1
}

# Current node = node mapped from current git branch.
# Echoes path or empty (caller must handle).
exp_current_node() {
  local vault=$1
  local id
  id=$(exp_branch_to_id "$(exp_current_branch)")
  [[ -z "$id" ]] && return 0
  exp_node_path "$vault" "$id"
}

# Get a frontmatter field. Empty stdout if missing.
exp_fm_get() {
  local file=$1
  local key=$2
  python3 "$EXP_FM_PY" get "$file" "$key" 2>/dev/null || true
}

# Set a frontmatter field. Value parsed as YAML.
exp_fm_set() {
  local file=$1
  local key=$2
  local val=$3
  python3 "$EXP_FM_PY" set "$file" "$key" "$val"
}

# Append item to a list field. Item parsed as YAML.
exp_fm_append() {
  local file=$1
  local key=$2
  local item=$3
  python3 "$EXP_FM_PY" append-list "$file" "$key" "$item"
}

# Render the node template with k=v substitutions. Writes to stdout.
exp_render_node() {
  python3 "$EXP_FM_PY" render "$EXP_TEMPLATE" "$@"
}

# Replace a markdown section body. Pass content via stdin.
exp_body_replace() {
  local file=$1
  local section=$2
  local tmp
  tmp=$(mktemp)
  cat >"$tmp"
  python3 "$EXP_FM_PY" body-replace "$file" "$section" "$tmp"
  rm -f "$tmp"
}

# ---------- filename / date ----------

exp_yyyymm() { date +%Y-%m; }
exp_today()  { date +%Y-%m-%d; }

# Echo full filename: YYYY-MM-<id>-<slug>.md
exp_filename() {
  local id=$1
  local slug=$2
  echo "$(exp_yyyymm)-${id}-${slug}.md"
}

# Echo basename without extension (used as wikilink target).
exp_wikiname() {
  local id=$1
  local slug=$2
  echo "$(exp_yyyymm)-${id}-${slug}"
}

# ---------- git atomic ops ----------
# The vault is a NESTED git repo at $VAULT (= <repo>/.experiments).
# Vault files are committed in the vault repo, not the outer code repo.
# Code branches (exp/<id>-<slug>) live in the OUTER repo.

# Commit vault files. Accepts file paths either absolute (under $vault) or
# relative-to-vault — both forms get normalized to vault-relative before `git add`.
# Usage: exp_vault_commit <vault> "msg" file1 [file2 ...]
exp_vault_commit() {
  local vault=$1
  local msg=$2
  shift 2
  local rels=()
  local f
  for f in "$@"; do
    case "$f" in
      "$vault"/*) rels+=("${f#$vault/}") ;;
      /*) echo "ERROR: '$f' is not inside vault '$vault'" >&2; return 1 ;;
      *)  rels+=("$f") ;;
    esac
  done
  (
    cd "$vault" || exit 1
    git add -- "${rels[@]}" || { echo "ERROR: vault git add failed: ${rels[*]}" >&2; exit 1; }
    git commit -m "$msg" --quiet || {
      git restore --staged -- "${rels[@]}" 2>/dev/null || true
      echo "ERROR: vault git commit failed" >&2; exit 1
    }
  )
}

# Get last commit SHA of vault repo.
exp_vault_head() {
  local vault=$1
  (cd "$vault" && git rev-parse HEAD 2>/dev/null) || echo ""
}

# Create a new branch in the OUTER (code) repo from a base.
# Usage: exp_create_branch <new-branch> <base-branch>
exp_create_branch() {
  local new=$1
  local base=$2
  if git show-ref --verify --quiet "refs/heads/$new"; then
    echo "ERROR: branch '$new' already exists" >&2
    return 1
  fi
  if ! git show-ref --verify --quiet "refs/heads/$base"; then
    echo "ERROR: base branch '$base' does not exist" >&2
    return 1
  fi
  git branch "$new" "$base"
}

# Checkout an existing branch in the outer repo (no-op if already there).
exp_checkout() {
  local branch=$1
  if [[ "$(exp_current_branch)" != "$branch" ]]; then
    git checkout --quiet "$branch"
  fi
}

# Refuse to act if outer working tree has uncommitted changes that would clash.
# (Vault changes don't count — they're in a separate nested repo.)
exp_require_clean() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: working tree has uncommitted changes. Commit or stash first." >&2
    return 1
  fi
}

# ---------- formatting ----------

exp_die() { echo "ERROR: $*" >&2; exit 1; }
