---
name: exp-attach
description: Attach a git branch to a node that is currently in status=idea, transitioning it to status=active. Use when you decided to actually start coding an idea-only node. Creates branch exp/<id>-<slug> from a base (default main).
argument-hint: "<node-id> [--from=<base-branch>]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(test *) Read
---

# exp-attach — attach git branch to an idea node

You are running `/exp-attach <node-id> [--from=<base>]`.

## 1. Parse args

From `$ARGUMENTS`:
- `node-id` — the 6-char id of an existing node (required)
- `--from=<base>` — base branch to fork from (default `main`, fall back to current branch)

If `node-id` missing, ask user and stop.

## 2. Inspect

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT")
cd "$REPO_ROOT"

ID="<node-id>"
FILE=$(exp_node_path "$VAULT" "$ID")
[[ -z "$FILE" ]] && exp_die "no node with id '$ID' found in $VAULT/nodes/"

STATUS=$(exp_fm_get "$FILE" status)
SLUG=$(exp_fm_get "$FILE" slug)
CUR_BRANCH_FIELD=$(exp_fm_get "$FILE" github-branch)

echo "FILE=$FILE"
echo "STATUS=$STATUS"
echo "SLUG=$SLUG"
echo "CUR_BRANCH_FIELD=$CUR_BRANCH_FIELD"

if [[ "$STATUS" != "idea" ]]; then
  exp_die "node $ID has status='$STATUS' (not 'idea'). Already attached or completed. Use /exp-status to inspect."
fi
```

Pick base branch the same way as `/exp-new`.

## 3. Preview

```
About to attach branch to node <id>:
  file:       <relative path>
  current:    status=idea, github-branch=null
  after:      status=active, github-branch="exp/<id>-<slug>"
  new branch: git branch exp/<id>-<slug> <base>  (then checkout)
  commit msg: "exp(<id>): attach branch — <slug>"
```

Ask: "Confirm? (y/n)". Abort on anything but yes.

## 4. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault); REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"
ID="<id>"; SLUG="<slug>"; BASE="<base>"
FILE=$(exp_node_path "$VAULT" "$ID")
BRANCH="exp/${ID}-${SLUG}"

exp_require_clean
exp_create_branch "$BRANCH" "$BASE"
exp_checkout "$BRANCH"

exp_fm_set "$FILE" status active
exp_fm_set "$FILE" github-branch "$BRANCH"
exp_fm_set "$FILE" date-started "$(exp_today)"

exp_vault_commit "$VAULT" "exp(${ID}): attach branch — ${SLUG}" "$FILE"
```

## 5. Report

- New branch (and current HEAD)
- Updated node file path
- Commit SHA
- Next step: edit code, then `/exp-record <results>`
