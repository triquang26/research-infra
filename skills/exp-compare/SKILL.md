---
name: exp-compare
description: READ-ONLY side-by-side comparison of two experiment nodes. Shows hypothesis, status, metrics, and (if both nodes are active/completed and have branches) the git diff between their branches. Use when deciding which of two parallel branches to extend, or to spot the trade-off between two siblings.
argument-hint: "<node-a-id> <node-b-id>"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(diff *) Read
---

# exp-compare — side-by-side two nodes

Read-only. No writes.

## 1. Resolve

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

A_ID="<a>"; B_ID="<b>"
A_FILE=$(exp_node_path "$VAULT" "$A_ID") || exp_die "no node '$A_ID'"
B_FILE=$(exp_node_path "$VAULT" "$B_ID") || exp_die "no node '$B_ID'"

for k in id slug status github-branch github-commit hypothesis metrics tags date-created date-completed; do
  echo "A.$k=$(exp_fm_get "$A_FILE" "$k")"
  echo "B.$k=$(exp_fm_get "$B_FILE" "$k")"
done
```

Read both files' Results and Conclusion sections (use Read with offset/limit, or grep `## Results` to `## ` boundary).

## 2. Build table

Render a markdown table with rows: id, slug, status, branch, hypothesis (truncated), each metric key (union of both `metrics` maps), Results 1-line summary, Conclusion 1-line summary, date-completed.

Highlight differences (use `Δ` marker in a 3rd column when both have numeric metric, computing `B - A`).

## 3. Git diff (if applicable)

```bash
A_BR=$(exp_fm_get "$A_FILE" github-branch)
B_BR=$(exp_fm_get "$B_FILE" github-branch)
if [[ "$A_BR" != "null" && -n "$A_BR" && "$B_BR" != "null" && -n "$B_BR" ]]; then
  if git show-ref --verify --quiet "refs/heads/$A_BR" && git show-ref --verify --quiet "refs/heads/$B_BR"; then
    echo "--- Files changed between branches ($A_BR ... $B_BR) ---"
    git diff --stat "${A_BR}...${B_BR}" || true
    echo
    echo "--- Commit log on B not in A ---"
    git log --oneline "${A_BR}..${B_BR}" 2>/dev/null | head -20
  else
    echo "(one of the branches does not exist locally — skipping git diff)"
  fi
else
  echo "(at least one node has no git branch — skipping git diff)"
fi
```

## 4. Present

Print the table + git output as one clean block. End with a one-line observation if obvious:
- if A and B have similar accuracy but different latency → flag the speed-acc trade-off
- if one is contradicted (e.g., much lower accuracy) → suggest `/exp-link <a> <b> contradicts`
- if no clear winner → suggest `/exp-plan` on whichever has more headroom

Do NOT propose links / branches automatically. Just suggest skills the user could run next.
