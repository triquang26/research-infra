---
name: exp-new
description: Create a NEW ROOT experiment node (no parent). Use when starting a brand-new research thread/hypothesis that does not extend any existing node. For a node that branches off an existing experiment, use /exp-branch instead. Default status=idea (no git branch yet); pass --with-branch to also create exp/<id>-<slug>.
argument-hint: "<hypothesis> [--slug=<slug>] [--with-branch] [--from=<base-branch>]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(echo *) Bash(cat *) Bash(test *) Bash(sed *) Read Write
---

# exp-new — create root node

You are running `/exp-new <hypothesis> [flags]`. Goal: create a new ROOT node (no parent) in the vault, optionally with a matching git branch.

The user's raw input is in `$ARGUMENTS`.

## 1. Parse args

From `$ARGUMENTS` extract:
- `hypothesis` — the unquoted main text (required, non-empty)
- `--slug=<slug>` — optional user-supplied slug (kebab-case)
- `--with-branch` — if present, create git branch and set status=active
- `--from=<base-branch>` — optional base branch (default `main`; fall back to current branch if `main` doesn't exist)

If `hypothesis` is empty/missing, ask the user to provide it and stop.

## 2. Inspect

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT")
cd "$REPO_ROOT"
ID=$(exp_gen_id "$VAULT")
CUR_BRANCH=$(exp_current_branch)
echo "VAULT=$VAULT"
echo "REPO_ROOT=$REPO_ROOT"
echo "ID=$ID"
echo "CUR_BRANCH=$CUR_BRANCH"
```

Derive slug:
- If user passed `--slug=`, use it (run it through your own kebab-case check).
- Otherwise propose a slug by taking 2–4 keywords from `hypothesis`, kebab-case, ≤30 chars.

Pick base branch (if --with-branch):
- If user passed `--from=X`, use X.
- Else if `git show-ref --verify --quiet refs/heads/main`, use `main`.
- Else use current branch.

## 3. Preview

Show the user EXACTLY this block (substitute values):

```
About to create root node:
  id:         <ID>
  slug:       <SLUG>
  file:       .experiments/nodes/YYYY-MM-<ID>-<SLUG>.md
  status:     idea          # or "active" if --with-branch
  branch:     null          # or "exp/<ID>-<SLUG>" (from <BASE>)
  commit msg: "exp(<ID>): new root — <SLUG>"

Hypothesis:
  <full hypothesis text>
```

Ask: "Confirm? (y / edit-slug / abort)"
- `y` → execute step 4
- `edit-slug <new>` → re-preview with new slug
- anything else → abort, no changes

## 4. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault)
REPO_ROOT=$(exp_repo_root "$VAULT")
cd "$REPO_ROOT"

# Substitute the confirmed values:
ID="<id>"
SLUG="<slug>"
HYP="<hypothesis>"
WITH_BRANCH="<true|false>"
BASE="<base-branch-or-empty>"

FILE_ABS="$VAULT/nodes/$(exp_filename "$ID" "$SLUG")"
BRANCH_NAME="exp/${ID}-${SLUG}"

STATUS="idea"; BRANCH_FIELD="null"; DATE_STARTED="null"
if [[ "$WITH_BRANCH" == "true" ]]; then
  STATUS="active"; BRANCH_FIELD="$BRANCH_NAME"; DATE_STARTED="$(exp_today)"
fi

REPO_URL=$(exp_outer_repo_url)
exp_render_node \
  "id=$ID" "slug=$SLUG" "hypothesis=$HYP" \
  "parents_yaml=[]" "parents_body=(none — root)" \
  "repo_url=$REPO_URL" \
  "branch=$BRANCH_FIELD" "status=$STATUS" \
  "today=$(exp_today)" "date_started=$DATE_STARTED" \
  >"$FILE_ABS"

# Update INDEX.md ROOTS section
WIKINAME=$(exp_wikiname "$ID" "$SLUG")
python3 - "$VAULT/INDEX.md" "$WIKINAME" "$SLUG" <<'PY'
import re, pathlib, sys
p, wiki, slug = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
entry = f"- [[{wiki}]] — {slug}"
text = p.read_text()
pat = re.compile(r"(<!-- ROOTS_START -->\n)(.*?)(\n<!-- ROOTS_END -->)", re.DOTALL)
def repl(m):
    b = m.group(2)
    b = entry if b.strip()=="(none yet)" else b.rstrip()+"\n"+entry
    return m.group(1)+b+m.group(3)
p.write_text(pat.sub(repl, text, count=1))
PY

# Create code branch in OUTER repo if requested (no commit — vault is gitignored)
if [[ "$WITH_BRANCH" == "true" ]]; then
  exp_require_clean
  exp_create_branch "$BRANCH_NAME" "$BASE"
  exp_checkout "$BRANCH_NAME"
fi

# Commit to NESTED vault repo (not outer)
exp_vault_commit "$VAULT" "exp(${ID}): new root — ${SLUG}" \
  "$FILE_ABS" "$VAULT/INDEX.md"
```

If any step fails, report the error verbatim and tell the user what state things are in (file created? branch created? commit done?).

## 5. Report

Output:
- Node file path (relative)
- Branch (or "no branch — status=idea, run /exp-attach when ready")
- Commit SHA
- Suggested next step: `/exp-record` after running experiment, or `/exp-branch` to fork a hypothesis from here.
