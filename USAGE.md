# USAGE — daily driving guide

> **You cloned `research-infra`, ran `./install.sh`, and forgot how to use it.** Read this file (5 min) and you're back in business.
>
> Prereqs: `./install.sh` ran successfully. Skills live at `~/.claude/skills/exp-*` (symlinked to this repo). You're in a code repo + Claude Code is open.

---

## 30-second mental model

- 1 **experiment** = 1 markdown node (file in `<project>/experiments/nodes/`)
- 1 **active experiment** = 1 git branch `exp/<id>-<slug>` in your code repo
- **Vault** (`experiments/`) is a nested git repo — its own history, single source of truth across all your code branches
- Every state-changing skill = **Inspect → Preview → Confirm → Execute**. Never runs without your `y`.

---

## TL;DR — 6 commands you'll actually type

```
/exp-init                                            # ONCE per project: bootstrap vault
/exp-publish                                         # ONCE per project: wire GitHub auto-sync
/exp-new "<hyp>" --slug=... --with-branch            # new root experiment
/exp-branch "<hyp>" --slug=... --with-branch         # new child of current node
/exp-record                                          # auto-detect metrics + draft Method/Conclusion
/exp-traverse                                        # see the whole DAG
```

If you forget anything, type `/exp-help` in Claude Code → cheatsheet inline.

---

## How to prompt Claude (3 styles)

Worked example: you're on branch `exp/a87147-baseline` and want to test "use 10 cameras with skiplag".

### Style 1 — slash command (most precise)

```
/exp-branch "Dùng 10 cam + skiplag" --slug=10cam-skiplag --with-branch
```

### Style 2 — natural language with skill keywords (Claude auto-invokes)

```
Tạo experiment con từ node hiện tại, hypothesis "dùng 10 cam + skiplag",
slug 10cam-skiplag, kèm branch
```

Keywords `experiment / hypothesis / branch` make Claude pick `/exp-branch`.

### Style 3 — vague (Claude asks back, then confirms)

```
Thử 10 cam với skiplag
```

Claude responds: "Tạo child node từ current `a87147`? Slug `10cam-skiplag`? `--with-branch`?". You answer, Claude proceeds.

**All 3 end at the same Preview step before any write.**

---

## Info each skill needs

What you must give vs what Claude auto-detects from context.

| Skill | You must give | Optional | Auto-detected |
|---|---|---|---|
| `/exp-init` | (nothing) | — | repo root, `origin` URL, git user.email/name |
| `/exp-publish` | (nothing) | `--name=<repo>`, `--public`, `--org=<org>` | gh user, default `<project>-vault`, private |
| `/exp-new` | hypothesis | `--slug=<slug>`, `--with-branch`, `--from=<base>` | id (random), slug (proposed from hypothesis), `github-repo` |
| `/exp-attach <id>` | node id | `--from=<base>` | slug, `github-repo` backfill |
| `/exp-branch` | hypothesis | `--parent=<id>`, `--slug`, `--with-branch` | parent id (from current branch), parent's branch |
| `/exp-record` | (nothing — AUTO mode default) | `k=v` pairs, `--method=...`, `--conclusion=...`, `--from=<file>`, `--ask` | scans `results.json`, `metrics.json`, `wandb-summary.json`, recent `*.log`, image files; drafts Method from git diff parent..HEAD; drafts Conclusion from metric deltas vs parent |
| `/exp-status` | — | `<node-id>` | current node, parents, siblings, children, links |
| `/exp-traverse` | — | `--from=<id>`, `--to=<id>`, `--direction=<d>`, `--depth=N`, `--filter=<f>`, `--format=<f>` | full DAG, verdicts, cross-links |
| `/exp-plan` | — | `k=3`, `--node=<id>` | current node + 2 ancestors for context |
| `/exp-link` | `<a-id> <b-id> <relation>` | — | wiki names |
| `/exp-compare` | `<a-id> <b-id>` | — | metrics, branches, git diff |
| `/exp-help` | (nothing) | — | — |

**Defaults worth remembering:**
- No `--with-branch` → status is `idea`, no git branch. Use `/exp-attach <id>` later.
- No `--slug=` → Claude proposes (you can edit at Preview).
- No `--parent=` for `/exp-branch` → parent inferred from current git branch.
- No `--node=` for `/exp-record`, `/exp-status` → current node from current git branch.
- No args at all for `/exp-record` → AUTO mode (scan logs, draft everything, you confirm).

**Relations** for `/exp-link`: `extends` | `contradicts` | `replicates`.

**Directions** for `/exp-traverse`: `down` | `up` | `both` | `siblings` | `neighborhood` | `path` | `orphans` | `all`.

---

## Force confirm — 4 layers (use as many as you want)

| Layer | What it does | When to use |
|---|---|---|
| **1 — built-in HITL** | Every skill has Preview → Confirm step | always on, no config |
| **2 — CLAUDE.md pin** | Drop `CLAUDE.md` into project root → Claude tightens behavior every session | recommended; 1 file copy |
| **3 — `--dry-run` flag** | Skill stops after Preview, never executes | when nervous about a big op |
| **4 — permission mode** | Claude asks per-tool-use permission | most aggressive, slows you down |

### Layer 2 — drop the CLAUDE.md template into your project

```bash
cp ~/research-infra/CLAUDE.md.template ~/my-project/CLAUDE.md
```

Template content (in `<repo>/CLAUDE.md.template`):
- Tells Claude to ALWAYS print Preview block + wait for explicit `y/ok/confirm`
- If user reply unclear → ASK BACK, don't assume
- `--dry-run` → STOP after Preview no matter what user says next
- Defaults vague user intent ("test X", "log Y") to invoking `/exp-*` skill instead of writing markdown inline

### Layer 3 — `--dry-run`

```
/exp-branch "..." --slug=10cam-skiplag --with-branch --dry-run
```

Claude shows Preview + reports "would create...", **never executes**. Re-run without `--dry-run` to actually do it.

### Layer 4 — permission mode

Edit `~/.claude/settings.json`:
```json
{ "permissions": { "defaultMode": "default" } }
```

Claude prompts for permission on every Bash / Edit / Write. Strictest. Use for shared infra.

---

## 10 common patterns (copy-paste)

### A. Start a new project

```bash
cd ~/my-project
claude
```
```
/exp-init
/exp-publish                                              # if you want GitHub sync
/exp-new "first hypothesis" --slug=baseline --with-branch
```

### B. Resume work next day

```bash
cd ~/my-project
git status                                                # see what branch you're on
claude
```
```
/exp-status                                               # current node neighborhood
/exp-traverse --direction=orphans                         # what's still open
```

### C. Branch an ablation from current node

```
/exp-branch "drop layer norm" --slug=no-layernorm --with-branch
```
Edit code, train, eval.

### D. Record results (auto-detect — recommended)

```
/exp-record
```

Claude scans for logs/json/wandb output, extracts metrics, drafts Method from git diff, drafts Conclusion from metric deltas vs parent. Shows full Preview. You `y`, `edit`, or `skip-field <name>`.

### D'. Record results explicitly (manual)

```
/exp-record acc=0.91 latency_ms=58 --method="6L transformer" --conclusion="PASS, +0.04 acc"
```

### E. Brainstorm 3 next directions

```
/exp-plan k=3
```

Claude drafts 3 candidates (hypothesis + slug + est cost + why). Pick 1 → it auto-invokes `/exp-branch`. Unpicked drafts discarded.

### F. Traverse the graph in any direction

```
/exp-traverse                                             # full DAG
/exp-traverse --from=<id> --direction=up                  # lineage to root
/exp-traverse --from=<id> --direction=down                # subtree
/exp-traverse --from=<id> --direction=both                # ancestors + descendants
/exp-traverse --from=<id> --direction=siblings            # same-parent peers
/exp-traverse --from=<id> --direction=neighborhood        # parents+sibs+kids
/exp-traverse --from=<a> --to=<b> --direction=path        # shortest a↔b
/exp-traverse --direction=orphans                         # open threads
/exp-traverse --filter=fail                               # mark FAIL nodes
```

### G. Cross-link findings between distant nodes

```
/exp-link <a-id> <b-id> contradicts
```

Other relations: `extends`, `replicates`.

### H. Compare two siblings to pick which to extend

```
/exp-compare <a-id> <b-id>
```

Side-by-side metrics table + `git diff exp/A...exp/B`.

### I. Idea-only brainstorm (no code yet)

```
/exp-new "wild idea I might try later" --slug=wild-idea
# ... later, when ready:
/exp-attach <id>                                          # creates branch, idea→active
```

### J. Look up a skill / forget how to use

```
/exp-help                                                 # inline cheatsheet
```

Or:
```
Đọc ~/research-infra/USAGE.md rồi tóm tắt cách dùng cho t
```

---

## Switching between experiments

The skill suite uses **current git branch → current node** as the mapping. To work on an existing experiment:

```bash
git checkout exp/<id>-<slug>                              # outer code repo
```

Now `/exp-record`, `/exp-status`, `/exp-branch` default to this node.

List all your experiment branches:
```bash
git branch | grep '^  exp/'
```

Or open Obsidian on the vault to navigate visually.

---

## Where things live (file map)

```
~/research-infra/                                # the tool (clone once anywhere)
├── README.md  USAGE.md  CLAUDE.md.template
├── install.sh
├── skills/_shared/{lib.sh, fm.py, node_template.md}
└── skills/exp-{init,publish,new,attach,branch,record,
              status,traverse,plan,link,compare,help}/SKILL.md

~/.claude/skills/                                # Claude Code reads skills here
└── exp-*  →  symlinks  →  ~/research-infra/skills/exp-*

~/my-project/                                    # YOUR code project
├── .git/                                        # branches: main, exp/<id>-<slug>
├── .gitignore                                   # includes: experiments/
├── CLAUDE.md                                    # (recommended) — copy of template
├── src/
└── experiments/                                 # YOUR vault — nested git repo
    ├── .git/                                    # vault's own history
    ├── INDEX.md
    ├── nodes/                                   # 1 file per experiment
    │   └── 2026-05-<id>-<slug>.md
    └── attachments/                             # plots, csv

~/vaults/                                        # on LAPTOP: vault clones for Obsidian
├── my-project/                                  # git clone of <project>-vault GitHub repo
└── another-project/
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `no vault found` | Run `/exp-init` in your project root |
| `PyYAML required` | `python3 -m pip install --user pyyaml` |
| `not on an exp/ branch` (record/status) | `git checkout exp/<id>-<slug>` or pass `--node=<id>` |
| `branch X already exists` | Pick a different slug, or `git branch -d X` first |
| `working tree has uncommitted changes` | Commit/stash code changes first |
| `/exp-record` finds nothing in auto mode | Pass `--from=<results.json>` or use explicit `k=v` |
| Obsidian shows empty | Open `<project>/experiments/` as vault. `Cmd+R` reload. `Cmd+G` for graph. |
| Vault commit: `user.email not set` | `git config --global user.email "..."` |
| `gh: command not found` (for /exp-publish) | `brew install gh && gh auth login` |
| `github-repo: null` in old nodes | Run `/exp-attach <id>` to backfill |
| Claude executed without confirming | Add CLAUDE.md (Layer 2) + use `--dry-run` (Layer 3) |
| Outer branches list grows huge | `git branch | grep '^  exp/'` to filter, or `git branch -d` archived ones |

---

## What to read next

- [`README.md`](README.md) — install, architecture overview, end-to-end Ctrl-World tutorial
- [`CLAUDE.md.template`](CLAUDE.md.template) — drop into project root for stricter HITL
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — why nested vault repo, design rationale
- [`docs/SYNC.md`](docs/SYNC.md) — sync vault from server to laptop Obsidian (3 options)
- [`docs/CASE-STUDY-ctrl-world.md`](docs/CASE-STUDY-ctrl-world.md) — worked example, 11 nodes, 5 hops
- `/exp-help` — type in Claude Code anytime for inline cheatsheet
