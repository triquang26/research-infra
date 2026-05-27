# USAGE — driving guide

> **You cloned this repo and forgot how to use it.** Read this file end-to-end (~5 min) and you'll be productive again.
>
> Prereq: ran `./install.sh` once. Skills are at `~/.claude/skills/exp-*` (symlinks into this repo).

---

## 30-second mental model

- Each **experiment** = one markdown node in `<project>/experiments/nodes/`.
- Each **active experiment** = one git branch `exp/<id>-<slug>` in your code repo.
- **Vault** (`experiments/`) is a nested git repo (its own history, single source of truth).
- Every state-changing skill follows: **Inspect → Preview → Confirm → Execute**. Never executes without your `y`.

---

## TL;DR — the 5 commands you'll actually type

```
/exp-init                                          # once per project
/exp-new "<hyp>" --slug=... --with-branch          # new root
/exp-branch "<hyp>" --slug=... --with-branch       # new child of current
/exp-record k=v k=v                                # ghi kết quả vào current
/exp-status                                        # mình đang ở đâu trong DAG?
/exp-help                                          # full cheatsheet
```

90% of daily use is just these.

---

## 3 prompting styles (worked example: "10 cam + skiplag")

You're in `~/ctrl-world` on branch `exp/a87147-ctrl-world-reproduce` and want to fork a child experiment.

### Style 1 — slash command (most precise, Claude doesn't have to guess)

```
/exp-branch "Dùng 10 cam thay 3, áp dụng skiplag để giảm latency" --slug=10cam-skiplag --with-branch
```

### Style 2 — natural language with keywords (Claude auto-invokes the skill)

```
Tạo experiment con từ node hiện tại, hypothesis "dùng 10 cam + skiplag",
slug 10cam-skiplag, kèm git branch luôn
```

Keywords `experiment`, `hypothesis`, `branch` make Claude pick `/exp-branch`.

### Style 3 — vague (Claude asks back)

```
Tôi muốn thử dùng 10 cam với skiplag
```

→ Claude responds with:
> Tạo child node từ current `a87147` hay root mới? Slug đề xuất `10cam-skiplag`, OK? `--with-branch`?

You answer, then Claude proceeds with the standard Preview → Confirm flow.

**All three end at the same Preview step before any write.**

---

## What info you provide for each skill

| Skill | You must give | Optional | Auto-detected |
|---|---|---|---|
| `/exp-init` | (nothing) | — | repo root, `origin` URL, git user.email/name |
| `/exp-new` | hypothesis | `--slug=<slug>`, `--with-branch`, `--from=<base>` | id, slug (proposed), `github-repo` |
| `/exp-attach <id>` | node id | `--from=<base>` | slug, github-repo backfill |
| `/exp-branch` | hypothesis | `--parent=<id>`, `--slug`, `--with-branch` | parent from current branch, parent's branch |
| `/exp-record` | metric `k=v` and/or text for Method/Conclusion | `--method=...`, `--conclusion=...`, `--node=<id>` | current node from git branch, commit SHA, date |
| `/exp-status` | — | node id | current node, parents, siblings, children, links |
| `/exp-plan` | — | `k=3`, `--node=<id>` | ancestor context for drafting |
| `/exp-link` | `<a-id> <b-id> <relation>` | — | wiki names |
| `/exp-compare` | `<a-id> <b-id>` | — | metrics, branches, diff |
| `/exp-help` | (nothing) | — | — |

**Relations** for `/exp-link`: `extends` | `contradicts` | `replicates`.

**Defaults you should know:**
- No `--with-branch` → status is `idea`, no git branch created. Use `/exp-attach <id>` later to promote.
- No `--slug=` → Claude proposes from your hypothesis (you can edit at Preview step).
- No `--parent=` for `/exp-branch` → parent is whatever node maps to your current git branch. If you're on `main`, skill fails — pass `--parent=` or `git checkout` an exp/ branch.
- No `--node=` for `/exp-record`, `/exp-status`, `/exp-plan` → current node from git branch.

---

## Force confirmation — 4 layers

In order of strength (use as many as you want):

### Layer 1 — built-in HITL (default, always on)

Every state-changing skill has a `Confirm? (y/n/...)` step before executing. Claude reads this from SKILL.md and pauses. ~95% reliable on its own.

### Layer 2 — pin in CLAUDE.md (recommended)

Copy `CLAUDE.md.template` from this repo into the root of your code project (`~/ctrl-world/CLAUDE.md`). Claude reads it every session and tightens behavior. Template:

```markdown
# Project rules — research-infra skills

CRITICAL: Before invoking ANY /exp-* skill that writes to files or runs git ops:
1. Print the full Preview block (file paths, branch ops, commit msg, frontmatter values).
2. Wait for explicit user reply "y" / "ok" / "confirm".
3. If user reply is unclear, ASK BACK (don't assume).
4. Only proceed to Execute step after explicit confirmation.

Never auto-execute /exp-new, /exp-branch, /exp-attach, /exp-record, /exp-link
without showing the preview and getting a "y" first.

The vault lives in experiments/ (nested git repo). All skills handle git +
commit atomically; you don't need to git add/commit vault changes manually.
```

A copy of this template is at `<repo-root>/CLAUDE.md.template` — `cp` it into any project.

### Layer 3 — `--dry-run` flag (preview-only, never execute)

```
/exp-branch "..." --slug=10cam-skiplag --with-branch --dry-run
```

Forces Claude to STOP after Preview and report what *would* happen. Re-run without `--dry-run` to actually execute. Useful when you're nervous about a large commit-burning op.

### Layer 4 — permission mode (most aggressive)

Edit `~/.claude/settings.json`:
```json
{ "permissions": { "defaultMode": "default" } }
```

Now Claude asks per-tool-use permission (every Bash, every Edit). Confirms everything but slows you down. Use when working on shared infra or testing new skills.

---

## Common patterns (copy-paste)

### A. Start a new project
```bash
cd ~/my-project                  # any git repo
claude
```
```
/exp-init
/exp-new "first hypothesis" --slug=baseline --with-branch
```

### B. Resume work next day
```bash
cd ~/my-project
git status                       # see what branch you're on
claude
```
```
/exp-status                      # remind yourself of the neighborhood
```

### C. Ablation from current node
```
/exp-branch "drop layer norm" --slug=no-layernorm --with-branch
```
Then edit code, train, eval.

### D. Record results and move on
```
/exp-record acc=0.91 latency_ms=58
```
Claude fills Method/Results/Conclusion (asks for text or proposes from metrics).

### E. Brainstorm 3 next directions
```
/exp-plan k=3
```
Claude drafts 3 candidates. Pick 1 → it auto-invokes `/exp-branch` with the chosen draft.

### F. Cross-link findings
```
/exp-link a3b1c9 d4e5f7 contradicts
```

### G. Compare two siblings
```
/exp-compare a3b1c9 d4e5f7
```

### H. Idea-only brainstorm (no code yet)
```
/exp-new "wild idea I might try later" --slug=wild-idea
# ... later, when ready:
/exp-attach <id>                  # creates branch, status idea→active
```

---

## Switching between experiments

The skill suite uses **current git branch → current node** as the mapping. To work on an existing experiment:

```bash
git checkout exp/<id>-<slug>      # outer code repo
```

Now `/exp-record`, `/exp-status`, `/exp-branch` all default to this node.

To list all your experiment branches:
```bash
git branch | grep '^  exp/'
```

Or open Obsidian on the vault to navigate visually.

---

## Where things live (quick map)

```
~/my-project/                          # outer code repo (your code)
├── .git/                              # branches: main, exp/<id>-<slug>, ...
├── .gitignore                         # includes: experiments/
├── CLAUDE.md                          # (recommended) — see Layer 2
├── src/...                            # your code
└── experiments/                       # vault (nested git repo)
    ├── .git/                          # vault's own history
    ├── INDEX.md                       # auto-maintained root list
    ├── nodes/
    │   └── 2026-05-<id>-<slug>.md     # one experiment = one file
    └── attachments/                   # plots, csv, screenshots

~/.claude/skills/                      # symlinks → <this-repo>/skills/*
~/research-infra/                      # this repo (skills source of truth)
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `no vault found` | Run `/exp-init` in your project root |
| `PyYAML required` | `python3 -m pip install --user pyyaml` |
| `not on an exp/ branch` (record/status) | `git checkout exp/<id>-<slug>` or pass `--node=<id>` |
| `branch X already exists` | Pick different slug or `git branch -d X` first |
| `working tree has uncommitted changes` | Commit / stash code changes first |
| Obsidian shows empty | Open `<project>/experiments/` as vault (Cmd+R refresh, Cmd+G for graph) |
| Vault commit: `user.email not set` | `git config --global user.email "..."` |
| `github-repo: null` in old nodes | Run `/exp-attach <id>` to backfill, or set the field manually |
| Claude executed without confirming | Add CLAUDE.md (Layer 2) and/or use `--dry-run` (Layer 3) |

---

## What to read next

- [`README.md`](README.md) — install, architecture overview, full use case list
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — why nested vault repo, design rationale
- [`docs/SYNC.md`](docs/SYNC.md) — sync vault from server to laptop Obsidian
- [`docs/CASE-STUDY-ctrl-world.md`](docs/CASE-STUDY-ctrl-world.md) — worked example, 11 nodes, 5 hops
- `/exp-help` — type in Claude Code anytime for inline cheatsheet
