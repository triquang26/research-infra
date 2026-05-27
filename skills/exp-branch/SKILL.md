---
name: exp-branch
description: Create a CHILD experiment node that branches off an existing parent node. Use when you want to explore a variation/extension/alternative hypothesis from an existing experiment. Default parent is the current node (inferred from git branch); override with --parent=<id>. Pass --with-branch to also create a git branch off the parent's branch.
argument-hint: "<hypothesis> [--parent=<id>] [--slug=<slug>] [--with-branch]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(test *) Bash(cat *) Read Write
---

# exp-branch — create child node from parent

You are running `/exp-branch <hypothesis> [flags]`. Goal: create a CHILD node whose `parents:` points to the chosen parent.

## 1. Parse args

From `$ARGUMENTS`:
- `hypothesis` — required text describing the child hypothesis
- `--parent=<id>` — explicit parent (else infer from current git branch)
- `--slug=<slug>` — optional kebab-case slug
- `--with-branch` — create git branch from parent's branch and set status=active

## 2. Inspect

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT")
cd "$REPO_ROOT"

# Resolve parent
if [[ -n "<PARENT_ARG>" ]]; then
  PARENT_ID="<PARENT_ARG>"
else
  PARENT_FILE=$(exp_current_node "$VAULT")
  [[ -z "$PARENT_FILE" ]] && exp_die "no current node (not on an exp/<id>-<slug> branch). Pass --parent=<id>."
  PARENT_ID=$(exp_fm_get "$PARENT_FILE" id)
fi

PARENT_FILE=$(exp_node_path "$VAULT" "$PARENT_ID")
[[ -z "$PARENT_FILE" ]] && exp_die "parent id '$PARENT_ID' not found in $VAULT/nodes/"

PARENT_SLUG=$(exp_fm_get "$PARENT_FILE" slug)
PARENT_STATUS=$(exp_fm_get "$PARENT_FILE" status)
PARENT_BRANCH=$(exp_fm_get "$PARENT_FILE" github-branch)
PARENT_WIKI=$(basename "$PARENT_FILE" .md)

CHILD_ID=$(exp_gen_id "$VAULT")
echo "PARENT_ID=$PARENT_ID"
echo "PARENT_FILE=$PARENT_FILE"
echo "PARENT_STATUS=$PARENT_STATUS"
echo "PARENT_BRANCH=$PARENT_BRANCH"
echo "CHILD_ID=$CHILD_ID"
```

If `--with-branch` but parent has `github-branch: null` (parent is still an idea), HARD fail with: "parent is status=idea, cannot inherit a branch. Either /exp-attach the parent first, or create this child without --with-branch."

Derive child slug from `hypothesis` (same logic as `/exp-new`), unless `--slug=` provided.

## 3. Preview

```
About to create child node:
  parent:     <parent-id> (<parent-slug>) [status=<parent-status>, branch=<parent-branch>]
  child id:   <child-id>
  child slug: <child-slug>
  file:       .experiments/nodes/YYYY-MM-<child-id>-<child-slug>.md
  parents:    [[<parent-wiki>]]
  status:     idea     # or "active" if --with-branch
  branch:     null     # or "exp/<child-id>-<child-slug>" from <parent-branch>
  commit msg: "exp(<child-id>): branch from <parent-id> — <child-slug>"

Hypothesis:
  <full child hypothesis>
```

Ask: "Confirm? (y / edit-slug / abort)".

## 4. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault); REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

CHILD_ID="<child-id>"; CHILD_SLUG="<child-slug>"; HYP="<hypothesis>"
PARENT_ID="<parent-id>"; PARENT_WIKI="<parent-wiki>"; PARENT_BRANCH="<parent-branch-or-null>"
WITH_BRANCH="<true|false>"

FILE_ABS="$VAULT/nodes/$(exp_filename "$CHILD_ID" "$CHILD_SLUG")"
CHILD_BRANCH="exp/${CHILD_ID}-${CHILD_SLUG}"

STATUS="idea"; BRANCH_FIELD="null"; DATE_STARTED="null"
if [[ "$WITH_BRANCH" == "true" ]]; then
  STATUS="active"; BRANCH_FIELD="$CHILD_BRANCH"; DATE_STARTED="$(exp_today)"
fi

REPO_URL=$(exp_outer_repo_url)
exp_render_node \
  "id=$CHILD_ID" \
  "slug=$CHILD_SLUG" \
  "hypothesis=$HYP" \
  "parents_yaml=[\"[[${PARENT_WIKI}]]\"]" \
  "parents_body=- [[${PARENT_WIKI}]]" \
  "repo_url=$REPO_URL" \
  "branch=$BRANCH_FIELD" \
  "status=$STATUS" \
  "today=$(exp_today)" \
  "date_started=$DATE_STARTED" \
  >"$FILE_ABS"

if [[ "$WITH_BRANCH" == "true" ]]; then
  exp_require_clean
  exp_create_branch "$CHILD_BRANCH" "$PARENT_BRANCH"
  exp_checkout "$CHILD_BRANCH"
fi

exp_vault_commit "$VAULT" "exp(${CHILD_ID}): branch from ${PARENT_ID} — ${CHILD_SLUG}" "$FILE_ABS"
```

## 5. Report

- Child node path, parent wikilink
- New branch (if created) or "status=idea, no branch"
- Commit SHA
- Suggested next: edit code on this branch, then `/exp-record`.
