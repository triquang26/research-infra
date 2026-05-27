---
name: exp-record
description: Record Method / Results / Plots / Conclusion + metrics into the CURRENT experiment node. Auto-detects the node from the current git branch. By default (no args), SCANS the project for training logs, results.json, wandb output, csv, etc., extracts metrics, drafts Method from git diff vs parent branch, drafts Conclusion from metric deltas, and shows everything as a single Preview for you to confirm/edit. You can also pass explicit k=v / --method= / --conclusion= / --from=<file> args.
argument-hint: "[key=value ...] [--node=<id>] [--method=...] [--conclusion=...] [--from=<file>] [--auto] [--ask]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(find *) Bash(ls *) Bash(test *) Bash(cat *) Bash(head *) Bash(tail *) Bash(grep *) Read Write
---

# exp-record — record results (auto-detect by default)

You are running `/exp-record [args]`. Goal: fill in Method / Results / Plots / Conclusion + metrics for the current node and commit.

**Default mode** (`/exp-record` with no args, or with `--auto`): Claude auto-detects everything from local files + git state, then shows a Preview for you to confirm/edit. Saves typing.

**Explicit mode** (`k=v` and/or `--method=` / `--conclusion=` flags): use what's provided, only ask for what's missing.

**Strict ask mode** (`--ask`): never auto-extract; ask field by field.

## 1. Resolve node + load parent context

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

if [[ -n "<NODE_ARG>" ]]; then
  FILE=$(exp_node_path "$VAULT" "<NODE_ARG>")
else
  FILE=$(exp_current_node "$VAULT")
fi
[[ -z "$FILE" ]] && exp_die "no current node. Pass --node=<id> or git checkout exp/<id>-<slug>."

ID=$(exp_fm_get "$FILE" id)
SLUG=$(exp_fm_get "$FILE" slug)
STATUS=$(exp_fm_get "$FILE" status)
PARENT_BRANCH=""
PARENTS_YAML=$(exp_fm_get "$FILE" parents)
echo "FILE=$FILE  ID=$ID  SLUG=$SLUG  STATUS=$STATUS"
echo "PARENTS=$PARENTS_YAML"

# Try to resolve parent's branch for diff/comparison
# (parse parents wikilink → find parent node → read its github-branch)
```

If status is already `completed`, ask: "Already completed. Append new results, overwrite, or abort?" Only proceed on confirmation.

## 2. Decide mode

Look at parsed args:
- `--ask` → strict mode, go to Step 3-ASK
- `k=v` args present AND `--method=` AND `--conclusion=` all given → fully explicit, skip auto-detect
- Else → AUTO mode (default). Even if some `k=v` given, auto-fill the rest.

## 3-AUTO. Auto-detect everything

Run discovery passes (use Bash + Read). For each, capture what you find.

### 3-AUTO.a — Metrics extraction

If user gave `--from=<file>`, read that file as the primary source. Otherwise scan in priority order:

```bash
# Highest-priority files (extension-based)
find . -maxdepth 5 -type f \( \
    -name "results.json" -o -name "metrics.json" -o -name "eval_results.json" \
    -o -name "test_results.json" -o -name "scores.json" \
  \) -not -path './experiments/*' -not -path './.git/*' 2>/dev/null

# Wandb summary
find . -maxdepth 6 -type f -name "wandb-summary.json" 2>/dev/null

# Recent log files (modified < 6h ago)
find . -maxdepth 5 -type f \( -name "*.log" -o -name "train.out" -o -name "eval.out" \) \
    -not -path './experiments/*' -not -path './.git/*' \
    -newermt "$(date -v-6H '+%Y-%m-%d %H:%M:%S')" 2>/dev/null

# Tensorboard event files (just note presence — too binary to parse directly)
find . -maxdepth 5 -type d -name "runs" -o -name "tb_logs" 2>/dev/null
```

For each candidate file:
- If `.json`: `Read` it, extract numeric leaves with short names (acc, loss, latency_ms, f1, bleu, rouge, ppl, success_rate, gpu_hours, etc.). Skip nested giant blobs.
- If `.log` / `.out`: `tail -200` the file, regex for lines like `^.*?(acc|accuracy|loss|f1|score|metric|eval)[\s=:]+([0-9.]+)`. Take last occurrence per metric name.
- Limit to 5–8 metrics total (most informative).

### 3-AUTO.b — Method draft

```bash
# What code changed on this branch vs parent's branch?
# Find parent's github-branch from parent node (parse parents wikilink)
# If parent has a branch and exists locally:
git diff --stat <parent-branch>...HEAD 2>/dev/null | tail -30
git log --oneline <parent-branch>..HEAD 2>/dev/null | head -10
```

Draft 2–3 sentences from the diff:
- "Same as parent except: <key code changes condensed from --stat>"
- If file count > 10: "Refactor across N files, key change: <highest-line-count file>"
- If only config changed: "Hyperparameter tweak: <diff of yaml/json config>"

If can't find parent branch (root node, or parent's branch deleted), draft from `git log` on the current branch since branch creation.

### 3-AUTO.c — Conclusion draft

Compare new metrics to parent's `metrics` frontmatter (from parent node file). Per metric:
- compute delta (sign + magnitude + %)
- judge PASS / FAIL / PARTIAL:
  - "PASS" if primary metric improved by ≥ threshold (acc up, loss down, latency down)
  - "FAIL" if primary metric regressed badly OR target metric not met
  - "PARTIAL" if tradeoff (one up, one down)

Draft 1–3 sentences: "{verdict}. {key metric} went from X to Y ({delta}%). {next-step hint}."

If parent has no metrics (idea node or root), draft Conclusion from absolute values + the hypothesis text: "{verdict} vs hypothesis. {one-liner}."

### 3-AUTO.d — Plots

Scan for image files modified < 6h ago:
```bash
find . -maxdepth 5 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.svg" \) \
    -newermt "$(date -v-6H '+%Y-%m-%d %H:%M:%S')" -not -path './experiments/*' 2>/dev/null | head -5
```

For each found plot, propose copying it to `experiments/attachments/<id>-<basename>` and referencing as `![[attachments/<id>-<basename>]]` in the Plots section. Don't copy yet — just propose.

## 3-ASK. Strict ask mode (only if user passed --ask)

Skip auto-detection. Ask field-by-field:
- "Method (or `skip`)?"
- "Metrics as k=v list (or `skip`)?"
- "Plots paths (or `skip`)?"
- "Conclusion (or `skip` / `propose`)?"

## 4. Preview

Show ALL of this in a single block:

```
About to update node <ID>:
  status: <current> → completed

Metrics (from <source>):
  acc: 0.91   (parent: 0.87, +0.04)
  latency_ms: 58   (parent: 45, +13ms +29%)
  loss: 0.31   (parent: 0.38, -0.07)

Method (from git diff <parent-branch>...HEAD):
  Same as parent except: num_layers 4→6 (src/model.py +12/-3),
  config yaml lr 1e-4 unchanged. 3 commits ahead.

Conclusion (drafted from metric deltas):
  PARTIAL. accuracy +0.04 (target met) but latency +29% — too slow for
  prod path. Recommend keeping baseline-4l for prod, this branch for
  high-acc setting.

Plots:
  - copy outputs/run-3/loss_curve.png → attachments/<id>-loss-curve.png
  - copy outputs/run-3/attention.png  → attachments/<id>-attention.png

github-commit: <HEAD SHA>
date-completed: 2026-05-28

commit msg: "exp(<id>): record results — <slug>"
```

Ask: "Confirm? (y / edit / skip-field <name> / abort)".

- `y`: write all
- `edit`: re-show with prompts to edit each field
- `skip-field plots`: don't write Plots section
- `skip-field method`: keep placeholder for Method
- `abort`: no changes

## 5. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault); REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"
FILE="<file>"; ID="<id>"; SLUG="<slug>"

# 5.a — copy plot files (if any), then write Plots section
# mkdir -p "$VAULT/attachments"
# cp <src> "$VAULT/attachments/<id>-<basename>"

# 5.b — set metrics frontmatter
exp_fm_set "$FILE" metrics "<metrics-yaml>"

# 5.c — body sections (only for confirmed fields)
for section in Method Results Plots Conclusion; do
  [[ <was-confirmed-for-this-section> ]] || continue
  printf '%s\n' "<section-body>" | exp_body_replace "$FILE" "$section"
done

# 5.d — status + dates + commit ref
ALL_FILLED=<true|false>
if [[ "$ALL_FILLED" == "true" ]]; then
  exp_fm_set "$FILE" status completed
  exp_fm_set "$FILE" date-completed "$(exp_today)"
  HEAD_SHA=$(exp_current_commit)
  [[ -n "$HEAD_SHA" ]] && exp_fm_set "$FILE" github-commit "$HEAD_SHA"
fi

# 5.e — atomic commit (vault includes any newly copied attachments)
exp_vault_commit "$VAULT" "exp(${ID}): record results — ${SLUG}" \
  "$FILE" "$VAULT/attachments/<copied-file>" 2>/dev/null || \
exp_vault_commit "$VAULT" "exp(${ID}): record results — ${SLUG}" "$FILE"
```

## 6. Report

- Updated sections (which ones)
- Source files used for auto-detection (if AUTO mode)
- New status / metrics / github-commit
- Vault commit SHA
- Next: `/exp-status` to see graph, `/exp-plan` to brainstorm, or `/exp-branch` for next experiment.

## What auto-detection WILL and WON'T do

**Will** scan and propose:
- numeric metrics from json files (results.json, metrics.json, wandb-summary.json)
- numeric metrics from recent log files (`grep` for keywords)
- method summary from git diff parent..HEAD (file/line stats)
- conclusion verdict from metric deltas vs parent's metrics
- plots from recent image files

**Will NOT** silently write anything. Even in `--auto` mode, the Preview step at #4 is mandatory and waits for `y`.

**Will NOT guess** if:
- no metric files found → ask user to provide `k=v` or `--from=<file>`
- conflicting metric sources → list candidates, ask user to pick
- metric name ambiguous (e.g. `loss` in 3 different files) → list all, ask user to pick

This is HITL — you stay in control of the final wording, Claude just removes the typing.
