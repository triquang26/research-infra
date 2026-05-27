#!/usr/bin/env bash
# examples/ctrl-world-build.sh — reproduce the 11-node Ctrl-World case study.
# Usage: ./ctrl-world-build.sh [target-dir]
#   default target: /tmp/ctrl-world-exp
#
# Requires: research-infra installed (skills/_shared/lib.sh reachable).

set -euo pipefail

TEST="${1:-/tmp/ctrl-world-exp}"
LIB="${RESEARCH_INFRA_DIR:-$HOME/research-infra}/skills/_shared/lib.sh"
[[ -f "$LIB" ]] || {
  # Fallback: derive from this script's location
  LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/_shared" && pwd)/lib.sh"
}
[[ -f "$LIB" ]] || { echo "ERROR: cannot find lib.sh. Re-run install.sh first." >&2; exit 1; }

rm -rf "$TEST"; mkdir -p "$TEST"; cd "$TEST"
git init -q -b main
git config user.email "researcher@local"; git config user.name "Researcher"
mkdir -p src
echo "# Ctrl-World Reproduction & Ablation" >README.md
echo "placeholder" >src/.gitkeep
git add . && git commit -q -m "initial: project scaffold"

. "$LIB"

# Init vault
mkdir -p experiments/nodes experiments/attachments experiments/.obsidian
touch experiments/nodes/.gitkeep experiments/attachments/.gitkeep
cat >experiments/.obsidian/app.json <<'JSON'
{"newFileLocation":"folder","newFileFolderPath":"nodes","attachmentFolderPath":"attachments","alwaysUpdateLinks":true,"useMarkdownLinks":false,"showLineNumber":true}
JSON
cat >experiments/.gitignore <<'GI'
.obsidian/workspace*
.obsidian/cache
.trash/
GI
cat >experiments/INDEX.md <<'MD'
# Experiments — Index

## Roots

<!-- ROOTS_START -->
(none yet)
<!-- ROOTS_END -->
MD
(cd experiments && git init -q -b main && git config user.email "researcher@local" && git config user.name "Researcher" && git add . && git commit -q -m "experiments: bootstrap vault")
printf '\n# Vault\nexperiments/\n' >>.gitignore
git add .gitignore && git commit -q -m "experiments: gitignore experiments/"

VAULT=$(exp_find_vault)
det_id() { echo "$1" | shasum | cut -c1-6; }

make_node() {
  local id=$1 slug=$2 hyp=$3 nstatus=$4 parent_branch=$5 parent_wiki=$6 with_branch=$7
  local file="$VAULT/nodes/$(exp_filename "$id" "$slug")"
  local branch="exp/${id}-${slug}"
  local branch_field="null" date_started="null" nstatus_eff="$nstatus"
  if [[ "$with_branch" == "true" ]]; then
    branch_field="$branch"; date_started="$(exp_today)"; nstatus_eff="active"
    exp_create_branch "$branch" "${parent_branch:-main}"
    exp_checkout "$branch"
  fi
  if [[ -z "$parent_wiki" ]]; then
    exp_render_node "id=$id" "slug=$slug" "hypothesis=$hyp" \
      "parents_yaml=[]" "parents_body=(none — root)" \
      "branch=$branch_field" "status=$nstatus_eff" \
      "today=$(exp_today)" "date_started=$date_started" >"$file"
    local wiki="$(exp_wikiname "$id" "$slug")"
    python3 - "$VAULT/INDEX.md" "$wiki" "$slug" <<'PY'
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
    exp_vault_commit "$VAULT" "exp(${id}): new root — ${slug}" "$file" "$VAULT/INDEX.md"
  else
    exp_render_node "id=$id" "slug=$slug" "hypothesis=$hyp" \
      "parents_yaml=[\"[[${parent_wiki}]]\"]" "parents_body=- [[${parent_wiki}]]" \
      "branch=$branch_field" "status=$nstatus_eff" \
      "today=$(exp_today)" "date_started=$date_started" >"$file"
    exp_vault_commit "$VAULT" "exp(${id}): branch — ${slug}" "$file"
  fi
  echo "$file"
}

record() {
  local file=$1 metrics=$2 method=$3 results=$4 conclusion=$5
  local id slug
  id=$(exp_fm_get "$file" id); slug=$(exp_fm_get "$file" slug)
  exp_fm_set "$file" metrics "$metrics"
  printf '%s\n' "$method"     | exp_body_replace "$file" "Method"
  printf '%s\n' "$results"    | exp_body_replace "$file" "Results"
  printf '%s\n' "$conclusion" | exp_body_replace "$file" "Conclusion"
  exp_fm_set "$file" status completed
  exp_fm_set "$file" date-completed "$(exp_today)"
  exp_vault_commit "$VAULT" "exp(${id}): record results — ${slug}" "$file"
}

N0=$(det_id "ctrl-world-reproduce")
N1A=$(det_id "ablate-memory-k0"); N1B=$(det_id "ablate-wristcam")
N1C=$(det_id "ablate-action-cond"); N1D=$(det_id "scale-down-10k")
N2A=$(det_id "memory-k8"); N2B=$(det_id "two-cam-front-wrist"); N2D=$(det_id "scale-down-1k")
N3A=$(det_id "memory-k8-lowres"); N3D=$(det_id "scale-down-5k")
N4A=$(det_id "edge-cases-12cam")

git checkout -q main
F0=$(make_node "$N0" "ctrl-world-reproduce" "Reproduce Ctrl-World on DROID: 20s coherent rollouts and +44.7% pi-0.5-DROID success." active "main" "" true)
record "$F0" "{coherent_seconds: 18.5, policy_uplift_pct: 41.2}" "Train Ctrl-World on DROID (95k traj). 1.5B SVD backbone. 3-view + k=4 memory + action cond." "- coherent_seconds: 18.5 (paper: 20s)
- policy_uplift_pct: 41.2 (paper: 44.7)" "Reproduction PASS."
ROOT_BRANCH=$(exp_fm_get "$F0" github-branch); ROOT_WIKI=$(basename "$F0" .md)

F1A=$(make_node "$N1A" "ablate-memory-k0" "k=0. Expect FAIL." active "$ROOT_BRANCH" "$ROOT_WIKI" true)
record "$F1A" "{coherent_seconds: 5.8, policy_uplift_pct: 12.3}" "k=0." "- coherent 5.8, uplift 12.3" "FAIL."
exp_checkout "$ROOT_BRANCH"

F1B=$(make_node "$N1B" "ablate-wristcam" "Drop wrist cam." active "$ROOT_BRANCH" "$ROOT_WIKI" true)
record "$F1B" "{coherent_seconds: 12.4, policy_uplift_pct: 22.1, hallucination_per_min: 4.2}" "2 view." "- coherent 12.4, uplift 22.1, halluc 4.2/min" "FAIL."
exp_checkout "$ROOT_BRANCH"

F1C=$(make_node "$N1C" "ablate-action-cond" "No frame-level action." active "$ROOT_BRANCH" "$ROOT_WIKI" true)
record "$F1C" "{coherent_seconds: 16.2, policy_uplift_pct: 8.9, iou: 0.31}" "Text-only cond." "- coherent 16.2, uplift 8.9, iou 0.31" "FAIL."
exp_checkout "$ROOT_BRANCH"

F1D=$(make_node "$N1D" "scale-down-10k" "10k trajectories." active "$ROOT_BRANCH" "$ROOT_WIKI" true)
record "$F1D" "{coherent_seconds: 16.8, policy_uplift_pct: 36.4}" "10% data." "- coherent 16.8, uplift 36.4" "PASS."

exp_checkout "$(exp_fm_get "$F1A" github-branch)"
F2A=$(make_node "$N2A" "memory-k8" "k=8." active "$(exp_fm_get "$F1A" github-branch)" "$(basename "$F1A" .md)" true)
record "$F2A" "{coherent_seconds: 22.1, policy_uplift_pct: 43.0}" "k=8." "- coherent 22.1, uplift 43.0" "PASS."

exp_checkout "$(exp_fm_get "$F1B" github-branch)"
F2B=$(make_node "$N2B" "two-cam-front-wrist" "Front+wrist." active "$(exp_fm_get "$F1B" github-branch)" "$(basename "$F1B" .md)" true)
record "$F2B" "{coherent_seconds: 17.2, policy_uplift_pct: 38.7, hallucination_per_min: 1.1}" "Front+wrist." "- coherent 17.2, uplift 38.7, halluc 1.1/min" "PARTIAL PASS."

exp_checkout "$(exp_fm_get "$F1D" github-branch)"
F2D=$(make_node "$N2D" "scale-down-1k" "1k traj." active "$(exp_fm_get "$F1D" github-branch)" "$(basename "$F1D" .md)" true)
record "$F2D" "{coherent_seconds: 9.4, policy_uplift_pct: 11.2}" "1k." "- coherent 9.4, uplift 11.2" "FAIL."

exp_checkout "$(exp_fm_get "$F2A" github-branch)"
F3A=$(make_node "$N3A" "memory-k8-lowres" "k=8 + res 192." active "$(exp_fm_get "$F2A" github-branch)" "$(basename "$F2A" .md)" true)
record "$F3A" "{coherent_seconds: 21.4, policy_uplift_pct: 42.1, gpu_hours: 142}" "k=8, 192x192." "- coherent 21.4, uplift 42.1, gpu 142" "PASS. Pareto."

exp_checkout "$(exp_fm_get "$F2D" github-branch)"
F3D=$(make_node "$N3D" "scale-down-5k" "5k traj." active "$(exp_fm_get "$F2D" github-branch)" "$(basename "$F2D" .md)" true)
record "$F3D" "{coherent_seconds: 15.9, policy_uplift_pct: 33.8}" "5k." "- coherent 15.9, uplift 33.8" "PASS."

exp_checkout "$(exp_fm_get "$F3A" github-branch)"
F4A=$(make_node "$N4A" "edge-cases-12cam" "Stress test 12-cam." active "$(exp_fm_get "$F3A" github-branch)" "$(basename "$F3A" .md)" true)
record "$F4A" "{coherent_seconds_edge: 8.2, hallucination_per_min: 5.1}" "Edge: 12 view, low-light." "- coherent_edge 8.2, halluc 5.1/min" "FAIL on edge."

exp_checkout main
link_nodes() {
  local a=$1 b=$2 rel=$3
  local aw=$(basename "$a" .md) bw=$(basename "$b" .md)
  exp_fm_append "$a" links "{to: '[[${bw}]]', relation: ${rel}}"
  exp_fm_append "$b" links "{to: '[[${aw}]]', relation: ${rel}}"
  local aid=$(exp_fm_get "$a" id); local bid=$(exp_fm_get "$b" id)
  exp_vault_commit "$VAULT" "exp: link ${rel} ${aid} ↔ ${bid}" "$a" "$b"
}
link_nodes "$F2A" "$F1A" extends
link_nodes "$F3D" "$F0"  contradicts
link_nodes "$F3A" "$F2A" replicates

echo
echo "===== DONE — $TEST ====="
echo "Vault commits: $(cd "$VAULT" && git rev-list --count HEAD)"
echo "Outer branches: $(git branch | wc -l | tr -d ' ')"
echo "Nodes: $(ls "$VAULT/nodes/" | grep -v gitkeep | wc -l | tr -d ' ')"
echo
echo "Open in Obsidian: open -a Obsidian '$VAULT'"
