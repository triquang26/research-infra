# research-infra

> **Local, Obsidian-friendly DAG of experiments for Claude Code.**
> Treat every hypothesis as a node, every git branch as the code for one node, and let Claude Code drive node creation / branching / record-keeping through atomic, human-in-the-loop skills.
>
> Inspired by [Flywheel (Paradigma)](https://flywheel.paradigma.inc) — local-first, no cloud, no auto-research. Just structure + traversal.

---

## What you get

- **9 Claude Code skills** (`/exp-init`, `/exp-new`, `/exp-branch`, `/exp-record`, `/exp-status`, `/exp-plan`, `/exp-link`, `/exp-attach`, `/exp-compare`) + `/exp-help`.
- **Nested-git-repo vault** (`<repo>/experiments/`) — every node change is its own commit, never pollutes your code branches.
- **Loose git coupling**: a node can be an *idea* (no branch) or *active* (branch `exp/<id>-<slug>` exists), and switching costs one command.
- **Obsidian-friendly file layout**: each node is a markdown file with YAML frontmatter and wikilinks, so opening the vault in Obsidian gives you a graph view for free.
- **Atomic + HITL** by design: every state-changing op previews exactly what it will do and waits for your `y` before touching disk or git.

No cloud. No GPU provisioning. No npm. Python 3 + git only.

---

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/triquang26/research-infra/main/install.sh | bash
```

This clones to `~/research-infra` and symlinks `skills/*` into `~/.claude/skills/`. After this:

```
~/research-infra/                        # the repo
~/.claude/skills/exp-init   -> ~/research-infra/skills/exp-init
~/.claude/skills/exp-new    -> ~/research-infra/skills/exp-new
... (etc.)
```

### Already cloned?

```bash
cd ~/research-infra
./install.sh                             # idempotent — safe to re-run
```

### Server with read-only home, prefer copies over symlinks?

```bash
COPY_MODE=1 ./install.sh
```

### Custom location

```bash
RESEARCH_INFRA_DIR=/srv/tools/research-infra ./install.sh
```

### Dependencies

The installer checks and auto-installs where it can:
- `git` — required
- `python3` — required
- `PyYAML` — auto-installs via `pip install --user pyyaml` if missing
- **No npm/node needed**

---

## Quick start (3 commands → working vault)

```bash
cd ~/my-research-project                 # any existing git repo
claude                                   # start Claude Code

# inside Claude Code, type:
/exp-init
/exp-new "Transformer 4L baseline >85% acc on dataset X" --slug=baseline-4l --with-branch
# ... run training ...
/exp-record acc=0.87 loss=0.42
```

After this you have:
- `experiments/nodes/2026-05-<id>-baseline-4l.md` with hypothesis + results
- git branch `exp/<id>-baseline-4l` checked out
- `experiments/.git/` recording every vault change

Open `experiments/` in Obsidian → graph view shows your DAG.

---

## Tutorial — End-to-end on a real paper repo (Ctrl-World example)

Concrete walkthrough: implementing the [Ctrl-World](https://github.com/Yanjiang-Guo/ctrl-world) paper on an SSH server, viewing the experiment DAG on your laptop in Obsidian. **Two GitHub repos** are involved: one for the code, one for the vault. This is the recommended setup.

### Why two repos?

| Repo | Holds | Audience | Visibility |
|---|---|---|---|
| **Code** (e.g. `triquang26/ctrl-world`) | implementation, branches `exp/<id>-<slug>` | you / collaborators / upstream PRs | usually public |
| **Vault** (e.g. `triquang26/ctrl-world-vault`) | DAG notes, hypotheses, results, links | you (+ maybe team) | usually private |

Separation means:
- PRs back upstream don't leak your messy `experiments/` folder
- Code reviewers see code diffs only
- Vault can be private even when code is public
- Vault commits (1 per skill op) don't bloat code branch history

### Step 1 — Server: fork the paper repo

```bash
ssh user@server
gh repo fork Yanjiang-Guo/ctrl-world --clone=true     # creates triquang26/ctrl-world
cd ctrl-world
```

(If not using `gh`: `git clone <paper-url>` then push to a new GitHub repo you own.)

### Step 2 — Server: install research-infra

```bash
curl -fsSL https://raw.githubusercontent.com/triquang26/research-infra/main/install.sh | bash
```

### Step 3 — Server: bootstrap the vault

```bash
cd ~/ctrl-world           # still in the code repo
claude                    # start Claude Code
```

Inside Claude Code:
```
/exp-init
```

This creates:
- `experiments/` (nested git repo with its own `.git/`)
- Appends `experiments/` to outer `.gitignore` so code branches don't see vault changes
- Commits the gitignore update on outer `main`

### Step 4 — Server: create the vault GitHub remote (one-time)

```bash
gh repo create triquang26/ctrl-world-vault --private --confirm
cd experiments
git remote add origin git@github.com:triquang26/ctrl-world-vault.git
git push -u origin main
```

### Step 5 — Server: auto-push hook (so every vault commit syncs)

```bash
cat >.git/hooks/post-commit <<'EOF'
#!/usr/bin/env bash
git push origin main --quiet 2>/dev/null || true
EOF
chmod +x .git/hooks/post-commit
cd ..                      # back to code repo root
```

Now every `/exp-*` op that commits to the vault will auto-push to GitHub.

### Step 6 — Server: start experimenting

```
/exp-new "Reproduce Ctrl-World on DROID 95k traj" --slug=baseline --with-branch
```

Claude previews, you confirm. This:
- Creates `experiments/nodes/2026-05-<id>-baseline.md`
- Creates outer code branch `exp/<id>-baseline` from `main`, checks it out
- Vault commit → auto-pushed to `ctrl-world-vault`
- Outer branch has no commits yet (you haven't changed code)

Now edit code on the server (`src/model.py`, etc.), train, eval, then:
```
/exp-record coherent_seconds=18.5 policy_uplift_pct=41.2
```

Method / Results / Conclusion get filled (you write or let Claude propose), status flips to `completed`. Vault commit → auto-pushed.

### Step 7 — Server: push code branches when ready (manual)

```bash
git add src/...
git commit -m "exp(<id>): baseline implementation"
git push origin exp/<id>-baseline
```

Code branches push **manually** — different cadence from vault.

### Step 8 — Server: branch an ablation

```bash
git checkout exp/<id>-baseline   # already there, just being explicit
```
```
/exp-branch "Drop memory retrieval (k=0)" --slug=ablate-memory-k0 --with-branch
```

Claude reads current node, creates child node, creates branch `exp/<child-id>-ablate-memory-k0` forked from `exp/<id>-baseline`, checks it out. Vault commit → auto-pushed.

### Step 9 — Laptop: clone vault, open in Obsidian

```bash
git clone git@github.com:triquang26/ctrl-world-vault.git ~/vaults/ctrl-world
open -a Obsidian ~/vaults/ctrl-world
```

Refresh manually with `git pull`, or wire a 30-second LaunchAgent (template in [`docs/SYNC.md`](docs/SYNC.md#option-a--vault-has-its-own-github-repo-recommended)).

### Step 10 — Laptop: optionally clone code for review

```bash
git clone git@github.com:triquang26/ctrl-world.git ~/code/ctrl-world
git -C ~/code/ctrl-world checkout exp/<id>-baseline   # see the experiment's code
```

Vault on laptop shows what / why / results. Code repo shows how. PR to upstream paper repo from `main` of your fork — vault never leaks.

### The picture

```
SERVER ──────────────────────► GITHUB ◄─────────── LAPTOP

~/ctrl-world/                  triquang26/ctrl-world          ~/code/ctrl-world/  (optional)
├── .git/  ─── push exp/* ──►    main                          for code review
├── .gitignore  experiments/     exp/abc123-baseline
├── src/                         exp/def456-ablate-memory-k0
└── experiments/  ── auto ──►  triquang26/ctrl-world-vault    ~/vaults/ctrl-world/
    ├── .git/   post-commit       main (all vault commits)     git pull every 30s
    ├── nodes/                                                  open -a Obsidian
    └── INDEX.md
```

| Action | Code repo (`ctrl-world`) | Vault repo (`ctrl-world-vault`) |
|---|---|---|
| Branches | `main` + `exp/<id>-<slug>` | `main` only |
| Push | manual (`git push origin exp/...`) | auto via post-commit hook |
| Files | source code | markdown nodes + INDEX |
| Audience | you / collaborators / PR upstream | you (+ team) |
| View | IDE / `gh pr view` | Obsidian on laptop |

### Want a single repo instead?

You can — drop the nested-git approach and let vault files live on whichever code branch you're on. Trade-off: `/exp-link` and `/exp-compare` across branches will fail (file not visible). See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md#why-nested-git-for-the-vault) for why we chose nested. For solo projects with no cross-branch linking, single-repo can work — but you'll have to modify the skills.

---

## Use cases (copy-paste ready)

### Use case 1 — Start a brand-new research thread

```
/exp-init                                                 # once per project
/exp-new "My first hypothesis" --slug=baseline --with-branch
```

Claude previews exactly what will be created, you confirm, vault + git branch ready.

---

### Use case 2 — Run an ablation on an existing node

```bash
git checkout exp/<parent-id>-<parent-slug>                # jump to parent code
```
```
/exp-branch "Drop layer norm — expect speedup at acc cost" --slug=no-layernorm --with-branch
```

Child node created with `parents: [[<parent-wiki>]]`. New git branch from parent's branch.

After training:
```
/exp-record acc=0.83 latency_ms=22
```

→ Method/Results/Conclusion sections filled (you type or let Claude propose), status → `completed`, commit.

---

### Use case 3 — Brainstorm without committing compute

```
/exp-plan k=3
```

Claude reads the current node + 2 ancestors, drafts 3 candidate next-step hypotheses (each with: hypothesis, slug, estimated cost, why). You pick 1 → it auto-invokes `/exp-branch` with the chosen draft. Discarded drafts are *not* saved.

---

### Use case 4 — "I have an idea but no time to code it yet"

```
/exp-new "Try mamba SSM instead of transformer" --slug=mamba-idea
```

No `--with-branch` → status `idea`, no git branch created. Sits in vault as a note.

Later, when you're ready:
```
/exp-attach <id>
```

→ Creates `exp/<id>-mamba-idea`, status flips to `active`, you start coding.

---

### Use case 5 — Compare two competing branches

```
/exp-compare <node-a-id> <node-b-id>
```

Side-by-side table: hypothesis, metrics (with Δ), git diff between the two branches, sample of changed files. Helps decide which sibling to extend.

---

### Use case 6 — Record a finding that crosses the DAG

You discover that two distant nodes contradict each other.

```
/exp-link <a-id> <b-id> contradicts
```

(Other relations: `extends`, `replicates`.) Both files get a `links:` frontmatter entry pointing at the other. Obsidian graph view shows the cross-edge after refresh.

---

### Use case 7 — "Where am I in the graph?"

```
/exp-status
```

(With no args, uses current node from git branch.) Prints:
```
Current: <id> <slug>  [completed, exp/<id>-<slug>]
Parent chain (root → here): ...
Siblings: ...
Unfinished children: ...
Cross-links: ...
Git: branch state, unpushed count
Next: /exp-plan or /exp-branch
```

Or inspect any node: `/exp-status <node-id>`.

---

### Use case 8 — Resume a node from earlier

```bash
git checkout exp/<id>-<slug>             # back on that experiment's code
/exp-status                              # remind yourself where it sits
/exp-record ...                          # add more results, or
/exp-branch "next step..." --with-branch # fork from here
```

`current node` is always derived from the current git branch — no flag needed.

---

### Use case 9 — Cheatsheet anytime

```
/exp-help
```

Prints the full reference card inline.

---

## Architecture (1-minute version)

```
my-project/                              # your code repo (outer git)
├── .git/                                # outer history — your code commits
├── .gitignore                           # includes:  experiments/
├── src/
└── experiments/                         # vault (NESTED git repo)
    ├── .git/                            # vault history — 1 commit per /exp-* op
    ├── .obsidian/app.json
    ├── INDEX.md                         # auto-maintained root list
    ├── nodes/
    │   └── 2026-05-<id>-<slug>.md       # one experiment = one file
    └── attachments/                     # plots, csv, screenshots
```

**Why nested git for the vault?** Because if vault files lived in the outer repo, every code branch would diverge in vault content too. `/exp-link a b` would fail when `a` and `b` were created on different branches. Nested git makes the vault *global* (one history, all nodes visible from any code branch).

**Code ↔ node mapping**: branch `exp/<id>-<slug>` ⇔ node file `YYYY-MM-<id>-<slug>.md` ⇔ wikilink target `[[YYYY-MM-<id>-<slug>]]`. Knowing one, you can derive the others.

**4-step skill discipline (every state-changing op):**
1. **Inspect** — read git state + current node + args
2. **Preview** — print exactly what will change (file + branch + commit msg)
3. **Confirm** — user types `y` (HITL)
4. **Execute atomic** — single transaction, rollback if any sub-step fails

→ Agent never guesses your slug, hypothesis wording, or which parent. Always asks first.

For the full case study (11-node 5-hop DAG built from the Ctrl-World paper), see [`docs/CASE-STUDY-ctrl-world.md`](docs/CASE-STUDY-ctrl-world.md).

---

## Server deployment

### Install on the server

```bash
ssh user@server
curl -fsSL https://raw.githubusercontent.com/triquang26/research-infra/main/install.sh | bash
```

That's it. Then in any project dir on the server, run Claude Code → `/exp-init` → start working.

### Caveat: server git identity

If the server's git has no `user.email` / `user.name`, vault commits will fail. Quick fix:

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

`/exp-init` will inherit these into the nested vault repo.

---

## Sync vault back to local Obsidian

The vault is its own git repo — give it its own GitHub remote (the easiest path).

### Option A — vault has its own GitHub repo (recommended)

**One-time setup on server:**

```bash
# create empty GitHub repo "my-project-vault" first (private)
cd ~/my-project/experiments
git remote add origin git@github.com:USER/my-project-vault.git
git push -u origin main
```

**Auto-push after every vault commit** (optional, adds to vault hooks):

```bash
cat > ~/my-project/experiments/.git/hooks/post-commit <<'EOF'
#!/usr/bin/env bash
git push origin main --quiet 2>/dev/null || true
EOF
chmod +x ~/my-project/experiments/.git/hooks/post-commit
```

**On local machine:**

```bash
git clone git@github.com:USER/my-project-vault.git ~/vaults/my-project
open -a Obsidian ~/vaults/my-project           # macOS
# or just: open the folder as a vault in Obsidian
```

To refresh, just `git pull` in `~/vaults/my-project` (or wire a 1-line LaunchAgent/cron).

### Option B — rsync (no GitHub needed)

On local machine, periodic pull:
```bash
rsync -avz --delete \
  user@server:~/my-project/experiments/ \
  ~/vaults/my-project/
```

Run on demand or via `cron` / `launchd` / `fswatch`.

### Option C — SSHFS (live mount)

```bash
brew install macfuse sshfs                     # macOS one-time
mkdir -p ~/mnt/my-project-vault
sshfs user@server:~/my-project/experiments ~/mnt/my-project-vault
open -a Obsidian ~/mnt/my-project-vault
```

Slowest interaction but always live. Disconnect on idle.

---

## Skill reference

| Skill | What it does | HITL? |
|---|---|---|
| `/exp-init` | Bootstrap `experiments/` vault as nested git repo | yes |
| `/exp-new` | Create ROOT node (no parent). `--with-branch` optional. | yes |
| `/exp-attach` | Promote an idea node → active by creating its git branch | yes |
| `/exp-branch` | Create CHILD of current (or `--parent=<id>`) node | yes |
| `/exp-record` | Fill Method/Results/Conclusion + metrics, mark completed | yes |
| `/exp-status` | Read-only: current + parents + siblings + children + links | no (read-only) |
| `/exp-plan` | Draft k=2-3 candidate child hypotheses, pick 1 to promote | yes (on promote) |
| `/exp-link` | Add cross-edge: extends / contradicts / replicates | yes |
| `/exp-compare` | Side-by-side 2 nodes + git diff branches | no (read-only) |
| `/exp-help` | Inline cheatsheet | no (read-only) |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `no vault found` | Run `/exp-init` in your project root |
| `PyYAML required` | `python3 -m pip install --user pyyaml` |
| `not on an exp/ branch` (record/status) | `git checkout exp/<id>-<slug>` or pass `--node=<id>` |
| `branch X already exists` | Pick a different slug, or `git branch -d X` first |
| `working tree has uncommitted changes` | Commit or stash your code changes first |
| Obsidian shows empty vault | Folder is `experiments/` (visible). In Obsidian: "Open folder as vault" → point at `<repo>/experiments/`. Use `Cmd+R` to reload. `Cmd+G` for graph view. |
| Vault commit fails: `user.email not set` | `git config --global user.email "..."` then re-run skill |
| Both `.experiments/` and `experiments/` exist | Skill prefers visible `experiments/`. Remove the unused one. |

---

## Architecture decisions (short version)

- **Why bash + Python instead of pure TS / Rust?** Skills run inside Claude Code via the Bash tool. Bash + a 100-line Python helper for YAML is enough; no compile step, no install fuss.
- **Why nested vault repo?** See Architecture section above. Single source of truth across all code branches.
- **Why loose git coupling (idea / active)?** So you can brainstorm cheaply (`/exp-new --idea`) without polluting branch list.
- **Why no MCP server?** Vault stays small enough (typically < 200 nodes) that grep + bash + the in-skill Python is faster than spinning up a server. If you outgrow this, ship a tiny MCP later — the skills are the stable API.
- **Why HITL on every op?** Atomic ≠ safe. Confirming the preview catches typos in slugs and bad parent picks before they hit disk.

---

## Repo layout

```
research-infra/
├── README.md                       # this file
├── install.sh                      # one-command installer
├── skills/                         # the 10 skills (symlinked into ~/.claude/skills/)
│   ├── _shared/
│   │   ├── lib.sh                  # bash helpers (gen_id, find_vault, atomic ops)
│   │   ├── fm.py                   # frontmatter helper (get/set/append-list/render)
│   │   └── node_template.md        # markdown template
│   ├── exp-init/SKILL.md
│   ├── exp-new/SKILL.md
│   ├── exp-attach/SKILL.md
│   ├── exp-branch/SKILL.md
│   ├── exp-record/SKILL.md
│   ├── exp-status/SKILL.md
│   ├── exp-plan/SKILL.md
│   ├── exp-link/SKILL.md
│   ├── exp-compare/SKILL.md
│   └── exp-help/SKILL.md
├── docs/
│   ├── ARCHITECTURE.md             # deeper architectural rationale
│   ├── SYNC.md                     # full sync-to-Obsidian guide
│   └── CASE-STUDY-ctrl-world.md    # worked example: 11 nodes, 5 hop, Ctrl-World paper
└── examples/
    └── ctrl-world-build.sh         # script that reproduces the case study end-to-end
```

---

## License

MIT.

## Credits

- Architecture inspired by **Flywheel** by Paradigma — [flywheel.paradigma.inc](https://flywheel.paradigma.inc).
- Built with Claude Code.
