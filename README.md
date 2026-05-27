# research-infra

**A local DAG of experiments for Claude Code.** Each experiment is a markdown note + git branch. Claude Code handles the bookkeeping (create node, branch off, record results, traverse the graph) through human-in-the-loop skills.

Built for ML researchers running experiments on SSH servers and wanting to **see their research as a graph in Obsidian** without learning a new tool. Inspired by [Flywheel (Paradigma)](https://flywheel.paradigma.inc) — same DAG mental model, local-first, no cloud, no auto-research.

---

## What you get

- **12 Claude Code skills** that drive the whole workflow (`/exp-init`, `/exp-new`, `/exp-branch`, `/exp-record`, `/exp-status`, `/exp-traverse`, `/exp-plan`, `/exp-link`, `/exp-attach`, `/exp-compare`, `/exp-publish`, `/exp-help`).
- **Nested-git-repo vault** at `<project>/experiments/` — every node change is its own commit, never pollutes your code branches.
- **Obsidian-friendly markdown**: each node is one file with YAML frontmatter and wikilinks. Open the vault in Obsidian → graph view for free.
- **Atomic + HITL** by design: every state-changing op previews exactly what it will do and waits for your `y` before touching disk.
- **No npm/node**. Python 3 + git. Works on locked-down servers.

---

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/triquang26/research-infra/main/install.sh | bash
```

Clones to `~/research-infra`, symlinks `skills/*` into `~/.claude/skills/`. Idempotent.

Already cloned? `cd ~/research-infra && ./install.sh`.

Server with read-only home? `COPY_MODE=1 ./install.sh`.

---

## 👉 Forgot how to use it? Read [USAGE.md](USAGE.md)

That's the **daily driving guide** — TL;DR commands, prompting styles, force-confirm layers, common patterns, CLAUDE.md drop-in template.

Or in Claude Code, type:
```
/exp-help
```

…and you get the cheatsheet inline.

---

## 5-minute quickstart

```bash
cd ~/my-research-project       # any git repo
claude                         # start Claude Code
```

Inside Claude Code:
```
/exp-init                                                # bootstrap vault (once per project)
/exp-new "Transformer 4L baseline" --slug=baseline --with-branch
# ... run training ...
/exp-record                                              # auto-detects metrics from logs
```

That's it. You now have:
- `experiments/nodes/2026-05-<id>-baseline.md` — node with hypothesis + results
- git branch `exp/<id>-baseline` checked out
- `experiments/.git/` — vault commit history

Open `experiments/` in Obsidian → graph view shows your DAG.

---

## Tutorial — implement a paper end-to-end

The full story: implement [Ctrl-World](https://github.com/Yanjiang-Guo/ctrl-world) on an SSH server, view the experiment DAG on your laptop in Obsidian. Two GitHub repos: one for code, one for vault.

### Why two repos?

| Repo | Holds | Audience |
|---|---|---|
| **Code** (`triquang26/ctrl-world`) | implementation, `exp/*` branches | you / collaborators / PR upstream |
| **Vault** (`triquang26/ctrl-world-vault`) | DAG notes, hypotheses, results | you (private) |

Separation: PRs back upstream don't leak your messy vault. Vault can be private even when code is public.

### Step 1 — fork the paper repo (server)

```bash
ssh user@server
gh repo fork Yanjiang-Guo/ctrl-world --clone=true
cd ctrl-world
```

### Step 2 — install research-infra (once per server)

```bash
curl -fsSL https://raw.githubusercontent.com/triquang26/research-infra/main/install.sh | bash
```

### Step 3 — bootstrap vault

```
claude
> /exp-init
```

Creates `experiments/` (nested git repo) + appends `experiments/` to outer `.gitignore`. **5 sec.**

### Step 4 — publish vault to GitHub (one command)

```
/exp-publish
```

This single skill:
- creates `triquang26/ctrl-world-vault` on GitHub (private by default — uses `gh` CLI)
- adds it as the vault's remote and pushes
- installs a post-commit hook so every future vault commit auto-pushes

Now every `/exp-record` you do auto-syncs to GitHub. **30 sec.**

<details>
<summary>Without /exp-publish (manual)</summary>

```bash
gh repo create triquang26/ctrl-world-vault --private --confirm
cd experiments
git remote add origin git@github.com:triquang26/ctrl-world-vault.git
git push -u origin main
cat >.git/hooks/post-commit <<'EOF'
#!/usr/bin/env bash
git push origin main --quiet 2>/dev/null || true
EOF
chmod +x .git/hooks/post-commit
cd ..
```
</details>

### Step 5 — first experiment

```
/exp-new "Reproduce Ctrl-World on DROID 95k traj" --slug=baseline --with-branch
```

Claude shows Preview, you `y`, file + branch + commit created. Vault commit auto-pushes to GitHub.

Now edit code (`src/model.py`, etc.), train, eval. When done:

```
/exp-record
```

(No args = AUTO mode.) Claude scans for `results.json` / `metrics.json` / `*.log` / `wandb-summary.json` in your project, extracts metrics, drafts Method from `git diff parent..HEAD`, drafts Conclusion from metric deltas vs parent. Shows everything in a single Preview. You `y` or `edit`.

### Step 6 — push code branch (manual)

```bash
git add src/...
git commit -m "exp(<id>): baseline implementation"
git push origin exp/<id>-baseline
```

Code branches push **manually** (different cadence from vault).

### Step 7 — branch an ablation

```
/exp-branch "Drop memory retrieval (k=0)" --slug=ablate-memory-k0 --with-branch
```

Child node, new branch from parent's branch, vault commit auto-pushed.

### Step 8 — laptop: clone vault, open in Obsidian

```bash
git clone git@github.com:triquang26/ctrl-world-vault.git ~/vaults/ctrl-world
open -a Obsidian ~/vaults/ctrl-world
```

Refresh: `git pull` (or wire a 30 s LaunchAgent — see [docs/SYNC.md](docs/SYNC.md)).

### Step 9 — explore the DAG (anytime)

```
/exp-traverse                          # full DAG
/exp-traverse --direction=orphans      # open threads (need follow-up)
/exp-traverse --from=<id> --direction=up   # lineage to root
```

→ See [Step-by-step worked example with 11 nodes](docs/CASE-STUDY-ctrl-world.md).

---

## Architecture in 1 minute

```
my-project/                            # outer code repo
├── .git/                              # branches: main, exp/<id>-<slug>, ...
├── .gitignore                         # includes: experiments/
├── src/                               # your code
└── experiments/                       # VAULT — nested git repo
    ├── .git/                          # vault's own commit history
    ├── nodes/                         # 1 markdown file per experiment
    ├── attachments/                   # plots, csv, screenshots
    └── INDEX.md                       # auto-maintained root list
```

3 key design decisions:

1. **Vault is a nested git repo.** Otherwise vault files would diverge per code branch, and cross-node ops (`/exp-link`, `/exp-compare`) would fail. Nested = single source of truth.
2. **Loose git coupling.** A node can be `idea` (no branch yet) or `active` (branch exists). Brainstorm cheaply with `/exp-new --idea`, promote later with `/exp-attach`.
3. **4-step skill discipline.** Every state-changing op: **Inspect → Preview → Confirm → Execute atomic**. Claude shows the diff before touching disk. No surprises.

Code ↔ node mapping: branch `exp/<id>-<slug>` ⇔ node file `YYYY-MM-<id>-<slug>.md` ⇔ wikilink `[[YYYY-MM-<id>-<slug>]]`. Knowing any one, you derive the others.

Deeper rationale: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Skill reference

| Skill | What it does | One-line usage |
|---|---|---|
| `/exp-init` | Bootstrap `experiments/` vault (nested git) | `/exp-init` (once per project) |
| `/exp-publish` | Create vault GitHub repo + auto-push hook | `/exp-publish` (once per project, needs `gh`) |
| `/exp-new` | Create ROOT node (no parent) | `/exp-new "<hyp>" --slug=... --with-branch` |
| `/exp-attach` | Promote idea node → active by creating branch | `/exp-attach <id>` |
| `/exp-branch` | Create CHILD of current (or `--parent=<id>`) | `/exp-branch "<hyp>" --slug=... --with-branch` |
| `/exp-record` | Auto-detect + record results into current node | `/exp-record` (auto) or `/exp-record acc=0.91 ...` |
| `/exp-status` | 1-node neighborhood (current + parents + siblings) | `/exp-status [<id>]` |
| `/exp-traverse` | Whole-DAG view in any direction | `/exp-traverse [--from=<id>] [--direction=up\|down\|both\|siblings\|path\|orphans]` |
| `/exp-plan` | Draft k=2-3 candidate hypotheses | `/exp-plan [k=3]` |
| `/exp-link` | Cross-edge between 2 nodes | `/exp-link <a> <b> extends\|contradicts\|replicates` |
| `/exp-compare` | Side-by-side metrics + git diff | `/exp-compare <a> <b>` |
| `/exp-help` | Inline cheatsheet | `/exp-help` |

Full per-skill arg + auto-detect details: [USAGE.md](USAGE.md#info-each-skill-needs).

---

## Sync vault to laptop Obsidian

Default & recommended: **Option A — vault as its own GitHub repo** (set up automatically by `/exp-publish`):

**Server**: vault commits auto-push (via post-commit hook installed by `/exp-publish`).

**Laptop**:
```bash
git clone git@github.com:USER/PROJECT-vault.git ~/vaults/PROJECT
open -a Obsidian ~/vaults/PROJECT
```

Auto-pull every 30 s via LaunchAgent: see [docs/SYNC.md](docs/SYNC.md).

Alternatives (rsync, SSHFS) also in [docs/SYNC.md](docs/SYNC.md).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `no vault found` | `/exp-init` in your project root |
| `PyYAML required` | `python3 -m pip install --user pyyaml` |
| `not on an exp/ branch` | `git checkout exp/<id>-<slug>` or pass `--node=<id>` |
| `branch X already exists` | Pick different slug or `git branch -d X` first |
| `working tree has uncommitted changes` | Commit / stash code changes first |
| Obsidian shows empty vault | Open `<project>/experiments/` as vault. `Cmd+R` reload. `Cmd+G` for graph. |
| Vault commit: `user.email not set` | `git config --global user.email "..."` |
| `gh` not installed (for /exp-publish) | `brew install gh && gh auth login` |
| `github-repo: null` in old nodes | Run `/exp-attach <id>` to backfill |
| Claude executed without confirming | Use CLAUDE.md template + `--dry-run` — see [USAGE.md](USAGE.md#force-confirm-4-layers) |

---

## Repo layout

```
research-infra/
├── README.md                       # this file — install + tutorial + reference
├── USAGE.md                        # 👈 daily driving guide
├── CLAUDE.md.template              # drop into any project root for stricter HITL
├── install.sh                      # one-command installer
├── skills/
│   ├── _shared/{lib.sh, fm.py, node_template.md}
│   └── exp-{init,publish,new,attach,branch,record,status,traverse,plan,link,compare,help}/SKILL.md
├── docs/
│   ├── ARCHITECTURE.md             # why nested vault, design rationale
│   ├── SYNC.md                     # full sync-to-Obsidian guide
│   └── CASE-STUDY-ctrl-world.md    # worked example: 11 nodes, 5 hops
└── examples/
    └── ctrl-world-build.sh         # reproduces the case study end-to-end
```

---

## License

MIT.

## Credits

Architecture inspired by **Flywheel** by Paradigma. Built with Claude Code.
