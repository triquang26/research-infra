---
name: exp-plan
description: Brainstorm k=2-3 candidate child hypotheses for the current node, presented as DRAFTS only (no files created, no git ops). User picks one (or zero) to promote — promotion delegates to /exp-branch. Use when you finished a node and want a structured next-step menu instead of committing to one direction blindly.
argument-hint: "[k=3] [--node=<id>]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Read
---

# exp-plan — draft next-step hypotheses

You are running `/exp-plan [k=3] [--node=<id>]`. Goal: propose k candidate child hypotheses for the user to pick from. **DO NOT write any files or run git ops in this skill. Promotion happens by invoking `/exp-branch` after the user picks.**

## 1. Resolve target

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

if [[ -n "<NODE_ARG>" ]]; then
  FILE=$(exp_node_path "$VAULT" "<NODE_ARG>")
else
  FILE=$(exp_current_node "$VAULT")
fi
[[ -z "$FILE" ]] && exp_die "no current node. Pass --node=<id> or checkout an exp/ branch."

ID=$(exp_fm_get "$FILE" id)
SLUG=$(exp_fm_get "$FILE" slug)
STATUS=$(exp_fm_get "$FILE" status)
HYP=$(exp_fm_get "$FILE" hypothesis)
METRICS=$(exp_fm_get "$FILE" metrics)
echo "TARGET=$FILE  STATUS=$STATUS"
echo "HYPOTHESIS: $HYP"
echo "METRICS: $METRICS"
```

Also Read the full node file to get Results and Conclusion sections (you'll use these as context).

Walk up 2 ancestors (use the parent-chain logic from `/exp-status`) to gather lineage context — you need this to propose *non-redundant* directions.

## 2. Draft k candidates (NO writes)

Default `k=3`. Generate k DRAFTS that are genuinely different along at least one trade-off axis (e.g., accuracy-vs-speed, scale-up vs ablate, alternative architecture, robustness test, sanity-check / replication). Each draft must include:
- a 1-sentence **hypothesis**
- a proposed **slug** (kebab-case, ≤30 chars)
- an **expected-cost** rough estimate (one of: minutes / hours / overnight)
- a **why** line — why this is worth trying given the parent's metrics/conclusion

Present them as:

```
DRAFTS for child of <ID> (<SLUG>):

[1] hypothesis: "..."
    slug:        kebab-slug-1
    cost:        ~2h
    why:         <one line>

[2] hypothesis: "..."
    slug:        kebab-slug-2
    cost:        overnight
    why:         <one line>

[3] hypothesis: "..."
    slug:        kebab-slug-3
    cost:        ~15min
    why:         <one line>
```

## 3. Ask user

Ask: "Pick 1/2/3 to promote (creates child node + optional branch), or `edit <n>` to rewrite a draft, or `all` to promote all 3, or `skip` to discard all."

Wait for response. **Discarded drafts are not saved anywhere.**

## 4. Promote

For each chosen draft:
- Ask user: "promote DRAFT [n] with --with-branch? (Y/n)"
- Then literally invoke `/exp-branch` with the prepared args:

```
/exp-branch "<hypothesis from draft n>" --parent=<ID> --slug=<slug-from-draft-n> [--with-branch]
```

The `/exp-branch` skill will run its own preview/confirm/execute cycle.

## 5. Report

- Which drafts were promoted (with resulting child ids)
- Which drafts were discarded
- Suggested next: `/exp-status` to see the updated graph.
