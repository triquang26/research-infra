---
name: exp-record
description: Record method, results, plots, conclusion into the CURRENT experiment node. Auto-detects the node from the current git branch (exp/<id>-<slug>). Accepts inline metrics as k=v args (e.g. acc=0.91 latency_ms=58). Updates status to completed when fields are filled.
argument-hint: "[key=value ...] [--node=<id>] [--method=...] [--conclusion=...]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(test *) Bash(cat *) Read Write
---

# exp-record — record results into current node

You are running `/exp-record [k=v ...]`. Goal: fill in Method, Results, Plots, Conclusion of a node and commit.

## 1. Resolve node

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

if [[ -n "<NODE_ARG>" ]]; then
  FILE=$(exp_node_path "$VAULT" "<NODE_ARG>")
else
  FILE=$(exp_current_node "$VAULT")
fi
[[ -z "$FILE" ]] && exp_die "no current node (not on exp/<id>-<slug>). Pass --node=<id> or git checkout the right branch."

ID=$(exp_fm_get "$FILE" id)
SLUG=$(exp_fm_get "$FILE" slug)
STATUS=$(exp_fm_get "$FILE" status)
echo "FILE=$FILE  ID=$ID  SLUG=$SLUG  STATUS=$STATUS"
```

If status is already `completed`, ask: "Node already completed. Append new results or abort?" — only proceed if user says append.

## 2. Inspect current empty sections

Read the file and report which of these sections still contain the placeholder `<điền khi /exp-record>`:
- `## Method`
- `## Results`
- `## Plots`
- `## Conclusion`

## 3. Gather input

Parse `$ARGUMENTS`:
- Any `key=value` pairs → these go into Results bullets AND `metrics:` frontmatter (numeric values stay numeric).
- `--method="..."` → Method section
- `--conclusion="..."` → Conclusion section

If after parsing there are sections still empty, **ASK the user** field-by-field — do not invent content. Allowed answers per section: actual text, `skip` (leave placeholder), or `propose` (you write a draft from metrics + parent context, user approves before save).

For Plots, ask "any plots/csv to attach? Provide relative paths under attachments/, or `skip`."

## 4. Preview

Show a full diff-style preview of what will be written to the file: new frontmatter values, new section bodies, new status (`completed` if all 4 sections filled and at least one metric present, else `active`), and the commit message: `exp(<id>): record results — <slug>`.

Ask: "Confirm? (y/n)".

## 5. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault); REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"
FILE="<file>"; ID="<id>"; SLUG="<slug>"

# Metrics: build a YAML inline map string like {acc: 0.91, latency_ms: 58}
exp_fm_set "$FILE" metrics "<metrics-yaml>"

# Sections — write each one's new body to a temp file then body-replace
for section in Method Results Plots Conclusion; do
  # only if user provided content for this section
  printf '%s\n' "<section-body>" | exp_body_replace "$FILE" "$section"
done

# Status + dates
if [[ "<all-filled>" == "true" ]]; then
  exp_fm_set "$FILE" status completed
  exp_fm_set "$FILE" date-completed "$(exp_today)"
  HEAD_SHA=$(exp_current_commit)
  [[ -n "$HEAD_SHA" ]] && exp_fm_set "$FILE" github-commit "$HEAD_SHA"
fi

exp_vault_commit "$VAULT" "exp(${ID}): record results — ${SLUG}" "$FILE"
```

## 6. Report

- Updated sections
- New status, metrics, github-commit (if applicable)
- Commit SHA
- Suggested next: `/exp-status` to see neighborhood, or `/exp-plan` to brainstorm next direction.
