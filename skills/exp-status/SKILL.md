---
name: exp-status
description: READ-ONLY. Show the current experiment node, its parent chain, sibling nodes (same parent), unfinished children, cross-links, and git branch state. Default target is the current node (from current git branch); pass [node-id] to inspect any node.
argument-hint: "[node-id]"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(grep *) Bash(ls *) Read Grep
---

# exp-status — show experiment neighborhood

Read-only. No file writes, no commits.

## 1. Resolve target

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

if [[ -n "<ARG_ID>" ]]; then
  FILE=$(exp_node_path "$VAULT" "<ARG_ID>")
  [[ -z "$FILE" ]] && exp_die "node id '<ARG_ID>' not found"
else
  FILE=$(exp_current_node "$VAULT")
  if [[ -z "$FILE" ]]; then
    echo "(no current node — not on an exp/<id>-<slug> branch)"
    echo "Listing all root nodes from INDEX.md instead:"
    sed -n '/<!-- ROOTS_START -->/,/<!-- ROOTS_END -->/p' "$VAULT/INDEX.md" | grep -E '^- '
    exit 0
  fi
fi

ID=$(exp_fm_get "$FILE" id)
echo "TARGET=$FILE  ID=$ID"
```

## 2. Build the neighborhood report

Use bash + Read + python3 to gather:

**Current node block:**
- id, slug, status, github-branch, github-commit
- hypothesis (first 200 chars)
- metrics (one-line)
- tags

**Parent chain** (walk `parents:` recursively up to root):
```bash
python3 - "$FILE" <<'PY'
import sys, yaml, re, pathlib
file = pathlib.Path(sys.argv[1])
vault_nodes = file.parent
def load(p):
    txt = p.read_text()
    m = re.match(r"^---\n(.*?)\n---", txt, re.DOTALL)
    return yaml.safe_load(m.group(1)) if m else {}
def resolve(wikilink):
    name = wikilink.strip("[]")
    cands = list(vault_nodes.glob(f"{name}.md"))
    return cands[0] if cands else None
chain = []
cur = file
seen = set()
while True:
    fm = load(cur)
    chain.append((fm.get("id"), fm.get("slug"), fm.get("status"), fm.get("github-branch")))
    parents = fm.get("parents") or []
    if not parents: break
    nxt = resolve(parents[0])
    if not nxt or str(nxt) in seen: break
    seen.add(str(nxt))
    cur = nxt
print("Parent chain (root → target):")
for i, (id_, slug, st, br) in enumerate(reversed(chain)):
    indent = "  " * i
    arrow = "└─ " if i > 0 else ""
    here = "  ← you are here" if i == len(chain) - 1 else ""
    print(f"{indent}{arrow}{id_} {slug}  [{st}, {br or 'no-branch'}]{here}")
PY
```

**Siblings** (other children of the immediate parent):
```bash
python3 - "$FILE" "$VAULT" <<'PY'
import sys, yaml, re, pathlib
file = pathlib.Path(sys.argv[1]); vault = pathlib.Path(sys.argv[2])
def load(p):
    m = re.match(r"^---\n(.*?)\n---", p.read_text(), re.DOTALL)
    return yaml.safe_load(m.group(1)) if m else {}
me = load(file)
my_parents = me.get("parents") or []
if not my_parents:
    print("(this is a root node — siblings = other roots)"); sys.exit(0)
parent_wikis = [p.strip("[]") for p in my_parents]
me_id = me.get("id")
siblings = []
for n in sorted((vault / "nodes").glob("*.md")):
    if n == file: continue
    fm = load(n)
    nps = [x.strip("[]") for x in (fm.get("parents") or [])]
    if set(nps) & set(parent_wikis):
        siblings.append((fm.get("id"), fm.get("slug"), fm.get("status")))
print("Siblings (same parent):")
if not siblings: print("  (none)")
else:
    for id_, slug, st in siblings: print(f"  - {id_} {slug} [{st}]")
PY
```

**Children of current** (anyone whose `parents:` contains me):
```bash
python3 - "$FILE" "$VAULT" <<'PY'
import sys, yaml, re, pathlib
file = pathlib.Path(sys.argv[1]); vault = pathlib.Path(sys.argv[2])
my_wiki = file.stem
def load(p):
    m = re.match(r"^---\n(.*?)\n---", p.read_text(), re.DOTALL)
    return yaml.safe_load(m.group(1)) if m else {}
kids = []
unfin = []
for n in sorted((vault / "nodes").glob("*.md")):
    fm = load(n)
    ps = [x.strip("[]") for x in (fm.get("parents") or [])]
    if my_wiki in ps:
        st = fm.get("status")
        kids.append((fm.get("id"), fm.get("slug"), st))
        if st not in ("completed", "archived"):
            unfin.append((fm.get("id"), fm.get("slug"), st))
print("Children:")
if not kids: print("  (none)")
else:
    for id_, slug, st in kids: print(f"  - {id_} {slug} [{st}]")
print("Unfinished children:")
if not unfin: print("  (none)")
else:
    for id_, slug, st in unfin: print(f"  - {id_} {slug} [{st}]  ← open thread")
PY
```

**Cross-links** (frontmatter `links:` array):
```bash
exp_fm_get "$FILE" links | grep -E "^- " || echo "  (none)"
```

**Git state:**
```bash
echo "Branch: $(exp_current_branch)"
git status --short | head -5
echo "Last 3 commits on this branch:"
git log --oneline -3 2>/dev/null
echo "Unpushed: $(git log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')"
```

## 3. Present

Print the gathered info as ONE clean text block, in this order:
1. Current node header (id, slug, status, branch)
2. Hypothesis
3. Parent chain (tree)
4. Siblings
5. Children + unfinished children
6. Cross-links
7. Git state
8. Suggested next actions:
   - if unfinished children exist → "open child <id>: git checkout exp/<id>-<slug>"
   - if status=active and Results empty → `/exp-record`
   - else → `/exp-plan` (brainstorm next) or `/exp-branch` (specific child)
