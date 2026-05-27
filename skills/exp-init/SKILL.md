---
name: exp-init
description: Bootstrap a .experiments/ Obsidian-style vault inside the current code repo. Use once per project before any other /exp-* skill. The vault is a NESTED git repo (its own history, single source of truth for the DAG); the outer code repo gitignores it. Creates .experiments/{nodes,attachments}, .obsidian/ defaults, INDEX.md, vault repo, and outer .gitignore entry.
allowed-tools: Bash(git *) Bash(mkdir *) Bash(touch *) Bash(cp *) Bash(test *) Bash(source *) Read Write
---

# exp-init — bootstrap experiment vault

You are running `/exp-init`. Goal: create a `.experiments/` vault as a nested git repo, so the vault is global (no per-branch divergence in the outer repo).

## 1. Inspect

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
PWD_NOW=$(pwd)
echo "PWD: $PWD_NOW"
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  exp_die "not inside a git repo. cd into your project root and re-run."
fi
REPO_ROOT=$(git rev-parse --show-toplevel)
echo "REPO_ROOT: $REPO_ROOT"
if [[ -d "$REPO_ROOT/.experiments" ]]; then
  exp_die ".experiments/ already exists at $REPO_ROOT/.experiments. Vault is already initialized."
fi
echo "Status: clean to init."
```

If the inspect block errors, STOP and report verbatim. Do not proceed.

## 2. Preview

Tell the user:

> Will bootstrap a vault at `<REPO_ROOT>/.experiments/`:
> - `.experiments/.git/` — nested git repo (vault has its own history; one commit per vault change)
> - `.experiments/nodes/` (empty; one markdown file per experiment)
> - `.experiments/attachments/` (empty; plots / csv / screenshots)
> - `.experiments/INDEX.md` (auto-maintained list of root nodes)
> - `.experiments/.obsidian/app.json` (graph-view friendly defaults)
> - `.experiments/.gitignore` (excludes Obsidian workspace state)
>
> And in the outer repo: append `.experiments/` to `.gitignore` (vault is ignored by outer repo so code branches stay clean).
>
> Vault commit: `experiments: bootstrap vault`.

## 3. Confirm

Ask: "Proceed? (y/n)". Abort on anything but y/yes.

## 4. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

mkdir -p .experiments/nodes .experiments/attachments .experiments/.obsidian
touch .experiments/nodes/.gitkeep .experiments/attachments/.gitkeep

cat >.experiments/.obsidian/app.json <<'JSON'
{
  "newFileLocation": "folder",
  "newFileFolderPath": "nodes",
  "attachmentFolderPath": "attachments",
  "alwaysUpdateLinks": true,
  "useMarkdownLinks": false,
  "showLineNumber": true
}
JSON

cat >.experiments/.gitignore <<'GI'
.obsidian/workspace*
.obsidian/cache
.trash/
GI

cat >.experiments/INDEX.md <<'MD'
# Experiments — Index

Root nodes (no parent) appear here automatically when you run `/exp-new`.

## Roots

<!-- ROOTS_START -->
(none yet)
<!-- ROOTS_END -->

## Conventions

- One markdown file per experiment node, in `nodes/`, named `YYYY-MM-<id>-<slug>.md`
- Edges via Obsidian wikilinks: `[[YYYY-MM-<id>-<slug>]]`
- Branch naming (outer repo): `exp/<id>-<slug>` (1:1 when status=active)
- Statuses: `idea` → `active` → `completed` → `archived`
- Vault is a nested git repo (its own history); outer repo gitignores `.experiments/`

Open this folder in Obsidian to see the graph view.
MD

# Initialize nested git repo in the vault
(
  cd .experiments
  git init -q -b main
  # If outer repo has user/email set, inherit them; else nudge user
  if [[ -z "$(git config user.email)" ]]; then
    OUTER_EMAIL=$(cd .. && git config user.email)
    OUTER_NAME=$(cd .. && git config user.name)
    [[ -n "$OUTER_EMAIL" ]] && git config user.email "$OUTER_EMAIL"
    [[ -n "$OUTER_NAME" ]] && git config user.name "$OUTER_NAME"
  fi
  git add nodes/.gitkeep attachments/.gitkeep .obsidian/app.json .gitignore INDEX.md
  git commit -q -m "experiments: bootstrap vault"
)

# Add .experiments/ to outer repo's .gitignore (idempotent)
if ! grep -qx '^\.experiments/$' .gitignore 2>/dev/null; then
  printf '\n# Experiments vault — nested git repo, ignored from outer repo\n.experiments/\n' >>.gitignore
  git add .gitignore
  git commit -q -m "experiments: gitignore .experiments/ (nested vault repo)"
fi
```

## 5. Report

- Vault path: `<REPO_ROOT>/.experiments/`
- Vault HEAD commit (from nested repo)
- Outer commit hash (the .gitignore update)
- Next step: `/exp-new "<your first hypothesis>"`
- View graph: `open -a Obsidian <REPO_ROOT>/.experiments` (or another markdown viewer)
