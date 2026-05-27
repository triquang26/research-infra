---
name: exp-help
description: Show inline cheatsheet for the research-infra /exp-* skill suite — when to use which skill, common flows, troubleshooting. Use whenever the user asks how the system works, which skill to use for X, or "I forgot how to use this".
allowed-tools: Read
---

# exp-help — research-infra cheatsheet

When invoked, print the following block VERBATIM (don't paraphrase — user wants the reference card):

```
================================================================================
  research-infra — Claude Code skills for DAG-style experiment tracking
  Full guide: ~/research-infra/USAGE.md   |   In Claude Code: /exp-help anytime
================================================================================

ONE-TIME PER PROJECT
  /exp-init                    Bootstrap experiments/ vault (nested git repo)
  /exp-publish                 Create GitHub vault repo + auto-push hook (needs gh)

CREATE NODES
  /exp-new "<hyp>" [--slug=...] [--with-branch] [--from=<base>]
                               → ROOT node (no parent). New research thread.
  /exp-branch "<hyp>" [--parent=<id>] [--slug=...] [--with-branch]
                               → CHILD of current node (or --parent).
  /exp-attach <id>             → Promote idea → active by creating its git branch.

WORK ON A NODE
  git checkout exp/<id>-<slug> → jump to that experiment's code
  ... edit, train, eval ...
  /exp-record                  → AUTO mode: scans logs/json/wandb, extracts metrics,
                                 drafts Method from git diff parent..HEAD,
                                 drafts Conclusion from metric deltas, shows Preview.
  /exp-record acc=0.9 loss=...  → explicit metrics mode
  /exp-record --ask             → strict ask-field-by-field

EXPLORE THE GRAPH
  /exp-status [<id>]           → 1-node neighborhood (current + parents + siblings)
  /exp-traverse [flags]        → WHOLE-DAG traversal in any direction:
                                   (default)                 = full tree from roots
                                   --from=X                  = subtree under X (down)
                                   --from=X --direction=up   = ancestor chain X→root
                                   --direction=both          = lineage + descendants
                                   --direction=siblings      = same-parent peers
                                   --direction=neighborhood  = parents+sibs+kids
                                   --from=X --to=Y --direction=path  = shortest path
                                   --direction=orphans       = open active/idea leaves
                                 + --filter=open|pass|fail, --depth=N, --format=tree|yaml

PLAN + ANNOTATE
  /exp-plan [k=3] [--node=<id>] → draft k candidate child hypotheses, you pick one to promote
  /exp-link <a> <b> <rel>      → cross-edge: extends | contradicts | replicates
  /exp-compare <a> <b>         → side-by-side metrics + git diff branches

ANY SKILL
  --dry-run                    → preview only, never execute (force-confirm Layer 3)

================================================================================
COMMON FLOWS
================================================================================

A) START A PROJECT
   /exp-init
   /exp-publish                                                # GitHub sync
   /exp-new "<hyp>" --slug=baseline --with-branch
   ... train ...
   /exp-record                                                 # AUTO

B) ABLATION FROM EXISTING
   git checkout exp/<parent-id>-<slug>
   /exp-branch "<hyp>" --slug=ablate-X --with-branch
   /exp-record

C) BRAINSTORM
   /exp-plan k=3                                               # pick 1 to promote

D) IDEA-ONLY
   /exp-new "<vague>" --slug=brainstorm-foo                    # no --with-branch
   /exp-attach <id>                                            # later when ready

E) CROSS-LINK
   /exp-compare <a> <b>
   /exp-link <a> <b> contradicts

F) FORGOT WHERE I AM
   /exp-status                                                 # 1-node view
   /exp-traverse --direction=orphans                           # what's open
   /exp-traverse                                               # full DAG

================================================================================
WHERE THINGS LIVE
================================================================================

YOUR PROJECT
  <project>/.git                       outer code repo, branches exp/<id>-<slug>
  <project>/.gitignore                 ignores experiments/
  <project>/CLAUDE.md                  (recommended) drop-in pin for stricter HITL
  <project>/experiments/.git           VAULT — nested git repo
  <project>/experiments/nodes/         1 markdown file per experiment

TOOL (installed by install.sh)
  ~/research-infra/skills/             source of truth
  ~/.claude/skills/exp-*               symlinks Claude Code reads

LAPTOP (after /exp-publish)
  ~/vaults/<project>/                  git clone of vault repo, opened in Obsidian

================================================================================
TROUBLESHOOTING
================================================================================

"no vault found"               → /exp-init in your project root
"PyYAML required"              → python3 -m pip install --user pyyaml
"not on an exp/ branch"        → git checkout exp/<id>-<slug>  or  --node=<id>
"gh: command not found"        → brew install gh && gh auth login
Obsidian shows empty           → open <project>/experiments/ as vault; Cmd+R reload
Claude executed without preview → copy ~/research-infra/CLAUDE.md.template into project root

================================================================================
Full guide:   ~/research-infra/USAGE.md
Architecture: ~/research-infra/docs/ARCHITECTURE.md
Sync setup:   ~/research-infra/docs/SYNC.md
Case study:   ~/research-infra/docs/CASE-STUDY-ctrl-world.md
================================================================================
```

After printing, ask: "Cần làm gì? (or just type a /exp-* command)".
