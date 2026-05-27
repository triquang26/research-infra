---
name: exp-help
description: Show inline cheatsheet for the research-infra /exp-* skill suite — when to use which skill, common flows, troubleshooting. Use whenever the user asks how the experiment-tracking system works, or which command to use for X.
allowed-tools: Read
---

# exp-help — research-infra cheatsheet

When invoked, print the following block VERBATIM (don't paraphrase, the user wants the reference card):

```
==============================================================================
  research-infra — Claude Code skills for DAG-style experiment tracking
==============================================================================

ONE-TIME PER PROJECT
  /exp-init                 Bootstrap experiments/ vault (nested git repo)

CREATE NODES
  /exp-new "<hypothesis>" [--slug=...] [--with-branch]
      → ROOT node (no parent). Use for new research thread.
  /exp-branch "<hypothesis>" [--parent=<id>] [--slug=...] [--with-branch]
      → CHILD of current node (or --parent). Use to extend/ablate an existing
        experiment.
  /exp-attach <node-id> [--from=<base>]
      → Promote a status=idea node to active by creating its git branch.

WORK ON A NODE
  git checkout exp/<id>-<slug>     # jump to that experiment's code branch
  ... edit code, run training/eval ...
  /exp-record k1=v1 k2=v2          # write Method/Results/Conclusion + metrics
                                   # → status becomes "completed"

EXPLORE THE GRAPH
  /exp-status [node-id]            # current node + parent chain + siblings
                                   # + children + cross-links + git state
  /exp-plan [k=3] [--node=<id>]    # propose k candidate next hypotheses;
                                   # user picks one to promote → /exp-branch
  /exp-compare <a-id> <b-id>       # side-by-side metrics + git diff branches
  /exp-link <a-id> <b-id> <rel>    # extends | contradicts | replicates

==============================================================================
COMMON FLOWS
==============================================================================

A) START A NEW THREAD
   /exp-init
   /exp-new "<root hypothesis>" --slug=baseline --with-branch
   ... train ...
   /exp-record acc=0.87 loss=0.42

B) ABLATION FROM AN EXISTING NODE
   git checkout exp/<parent-id>-<parent-slug>
   /exp-branch "<child hypothesis>" --slug=ablation-X --with-branch
   ... train ...
   /exp-record acc=0.84 loss=0.51

C) BRAINSTORM BEFORE COMMITTING
   /exp-plan k=3                   # see 3 candidate directions, pick 1

D) IDEA-ONLY NODE (no code yet)
   /exp-new "<vague idea>" --slug=brainstorm-foo    # no --with-branch
   ... decide later it's worth pursuing ...
   /exp-attach <id>                # creates branch + flips status to active

E) FIND RELATIONSHIPS BETWEEN SIBLINGS
   /exp-compare <a> <b>            # see metric deltas, file diff
   /exp-link <a> <b> contradicts   # record finding

==============================================================================
NODE FILE LAYOUT
==============================================================================

experiments/nodes/YYYY-MM-<id>-<slug>.md  (one per experiment)

  ---
  id: <6 char>
  slug: <kebab>
  status: idea | active | completed | archived
  hypothesis: ...
  parents:  [ "[[<parent-wiki>]]" ]
  links:    [ {to: "[[...]]", relation: extends|contradicts|replicates} ]
  github-branch: exp/<id>-<slug>  | null
  metrics: { ... }
  ---

  ## Hypothesis / Parents / Method / Results / Plots / Conclusion / Next directions

==============================================================================
WHERE THINGS LIVE
==============================================================================

PROJECT REPO  (your code, your branches)
  <repo>/.git                          ← outer git repo, branches exp/<id>-<slug>
  <repo>/.gitignore                    ← gitignores experiments/
  <repo>/experiments/                  ← VAULT (nested git repo)
    .git/                              ← vault's own history (1 commit / op)
    nodes/YYYY-MM-<id>-<slug>.md       ← experiment notes
    attachments/                        ← plots, csv, screenshots
    INDEX.md                           ← auto-maintained root list

SKILLS (installed by install.sh)
  ~/.claude/skills/exp-*               ← symlinks → <repo>/skills/exp-*/SKILL.md
  ~/.claude/skills/_shared/lib.sh      ← shared bash helpers
  ~/.claude/skills/_shared/fm.py       ← YAML frontmatter helper

==============================================================================
TROUBLESHOOTING
==============================================================================

"no vault found"             → run /exp-init in your project root
"PyYAML required"            → python3 -m pip install --user pyyaml
"not on an exp/ branch"      → git checkout exp/<id>-<slug>  OR  pass --node=<id>
Obsidian doesn't see vault   → the folder is "experiments/" (not dot-prefixed
                               by default). Open Obsidian → "Open folder as vault"
                               → point at <repo>/experiments/

Want full docs:  see README.md or https://github.com/triquang26/research-infra
```

After printing, ask: "What would you like to do next? (or just type a /exp-* command)".
