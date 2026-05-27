# Architecture

## TL;DR

```
my-project/                        # outer git repo (your code)
├── .git/                          # outer history, branches: main, exp/<id>-<slug>, ...
├── .gitignore                     # includes: experiments/
├── src/...                        # code lives here
└── experiments/                   # VAULT — nested git repo
    ├── .git/                      # vault history, 1 commit per /exp-* op
    ├── INDEX.md                   # auto-maintained root list
    ├── nodes/                     # 1 markdown file per experiment
    └── attachments/
```

- **Outer repo**: tracks code. Branches `exp/<id>-<slug>` per active experiment.
- **Vault (nested repo)**: tracks the DAG of experiments. Global view — every node visible from every outer branch.
- **No leak between the two**: outer `.gitignore` includes `experiments/`, so code commits never carry vault diffs.

## Why nested git for the vault?

We tried (and rejected) putting vault files into the outer repo. Failure mode:

1. `/exp-new --with-branch` on outer branch `main`: writes `experiments/nodes/A.md` + commits on `main`.
2. `/exp-branch` from `A`: creates outer branch `exp/<B-id>-<slug>`, writes `experiments/nodes/B.md`, commits on the new branch.
3. Switch back to outer branch `main`. `experiments/nodes/B.md` is **gone** (it lives only on branch B).
4. `/exp-link A B contradicts` fails — B's file isn't on the current branch.

Nested vault repo solves this:

- Vault is single source of truth.
- Outer branches store code only.
- Cross-node ops (`link`, `compare`, `status` with parent chain) always succeed.

Trade-off: 2 git histories to manage. Acceptable — they don't interact.

## Loose git coupling

A node has 3 statuses:
- `idea` — no git branch yet (just a hypothesis on disk)
- `active` — git branch `exp/<id>-<slug>` exists; user is iterating on code
- `completed` — results recorded, may keep branch or archive

`/exp-new` defaults to `idea`. Pass `--with-branch` to skip straight to `active`. Or do it in 2 steps: `/exp-new` → later `/exp-attach <id>`.

This means you can:
- Brainstorm a bunch of ideas without polluting the branch list
- Decide later which ideas are worth coding
- Keep history of *decisions to defer* alongside completed work

## 4-step atomic discipline

Every state-changing skill follows the same shape:

1. **Inspect** — read git state, current node, args. Hard-fail early on ambiguity (e.g., not on an exp/ branch).
2. **Preview** — print exactly what will change: which file, which git branch op, which commit message.
3. **Confirm** — wait for user `y` / `n` / `edit-slug <new>` / `abort`.
4. **Execute atomic** — single transaction: render → write file → optionally create branch → vault commit. If any step fails, rollback (restore staged files, no orphan branch).

This is HITL by construction. Agent never invents slugs, hypothesis wording, parent IDs.

## Node data model

File: `experiments/nodes/YYYY-MM-<id>-<slug>.md`

```yaml
---
id: a3b1c9                  # 6-char base36, unique per vault
slug: baseline-4l           # kebab, user-confirmed
type: experiment            # experiment | insight | review
status: completed           # idea | active | completed | archived
hypothesis: ...
parents:                    # wikilinks (list)
- '[[2026-05-x9z2p7-prior-work]]'
links:                      # cross-edges (list of maps)
- {to: '[[2026-05-q0w1e8-sibling]]', relation: contradicts}
github-branch: exp/a3b1c9-baseline-4l   # or null when status=idea
github-commit: <sha>        # snapshot at /exp-record time
date-created: 2026-05-27
date-started: 2026-05-27
date-completed: 2026-05-28
tags: []
metrics: {acc: 0.87, latency_ms: 45}
---

# a3b1c9 — baseline-4l

## Hypothesis
...

## Parents
- [[2026-05-x9z2p7-prior-work]]

## Method
...

## Results
- acc: 0.87
- latency_ms: 45

## Plots
![[attachments/loss-curve.png]]

## Conclusion
...

## Next directions
- [ ] try 6 layer
- [ ] quantize int8
```

**Conventions:**
- Filename `YYYY-MM-<id>-<slug>.md` → sorts by month, unique by id.
- Branch `exp/<id>-<slug>` ⇔ node 1:1 (when status active/completed).
- Wikilink target = filename without `.md`.
- Parents go in **both** frontmatter (for `/exp-status` etc.) and `## Parents` body (so vanilla Obsidian graph view sees them).

## Skill mechanics

- Skills live as `<repo>/skills/exp-*/SKILL.md` (frontmatter + body).
- `install.sh` symlinks them into `~/.claude/skills/exp-*` so Claude Code discovers them.
- Skill body is read by Claude as the prompt when invoked. It tells Claude the 4 steps + the exact bash to execute.
- Bash blocks source `_shared/lib.sh` for helpers (`exp_find_vault`, `exp_gen_id`, `exp_vault_commit`, etc.).
- `_shared/fm.py` handles YAML frontmatter read/write/render (more reliable than bash sed/awk).

## Why no MCP server?

Considered, deferred. For vaults under ~200 nodes:
- `grep -r` over `nodes/*.md` is millisecond-fast.
- All graph ops fit in ~80 LOC of Python (see `exp-status` skill's parent-chain walk).
- An MCP server adds: a long-running process, dep installation, IPC failure modes.

If you grow past 500 nodes and start running queries in tight loops, ship a thin MCP server then. The skills will stay the same — the only change is `lib.sh` would delegate `exp_node_path` / parent-chain walks to the MCP.

## Why bash + Python?

- **Bash**: Claude Code's Bash tool is the primary execution channel. Skill bodies are markdown; bash blocks inside are the execution layer.
- **Python (just for YAML)**: bash's YAML handling is awful; PyYAML is ~100ms startup and handles every edge case (Unicode, multi-line strings, flow mappings).
- **No npm/node**: deliberate. Server constraints (no npm allowed per setup) + Python ships with macOS/Linux.

## Failure modes & guarantees

| Failure | What happens | Recovery |
|---|---|---|
| Bad slug typo | Preview shows it, user edits before confirm | Free |
| `git branch` fails (e.g., name collision) | No file written, no commit | Re-run with different slug |
| `git commit` fails (e.g., hook reject) | Staged files unstaged, error reported | Fix hook, re-run skill |
| Vault not found | Skill hard-fails with "run /exp-init" | Run /exp-init |
| PyYAML missing | `fm.py` errors out, vault unchanged | `pip install --user pyyaml` |
| Outer branch dirty | `exp_require_clean` blocks branch-creating ops | Commit/stash code first |

Atomic = either fully applied or fully not. Never half-applied.

## What's NOT in this system (intentionally)

- Auto-research loops (the `flywheel auto` analog) — out of scope.
- Paper-to-graph parsing (the `flywheel p2graph` analog) — manual for now.
- Cloud sync built in — see `docs/SYNC.md` for git-based sync.
- Compute provisioning — you run experiments yourself.
- Multi-user collab — single-user assumption, but vault repo can be shared via GitHub.

If you want any of these, fork and add. Skills are the stable API.
