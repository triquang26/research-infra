---
name: exp-traverse
description: READ-ONLY traversal of the experiment DAG in any direction. Use when the user asks broad questions about the graph ("what have I tried", "what's open", "show me the lineage of X", "how do I get from A to B", "any contradictions") or when you (Claude) need full graph context. Supports 7 directions: down (subtree), up (ancestors), both (lineage + descendants), siblings, neighborhood (parents+siblings+children), path (shortest between 2 nodes), orphans (open active/idea leaves). Output is ASCII tree (default) or YAML structured dump.
argument-hint: "[--from=<id>] [--to=<id>] [--direction=down|up|both|siblings|neighborhood|path|orphans|all] [--depth=N] [--filter=open|pass|fail|all] [--format=tree|yaml]"
allowed-tools: Bash(python3 *) Bash(source *) Read
---

# exp-traverse — flexible DAG traversal

You are running `/exp-traverse [flags]`. Goal: load the entire vault, walk it in the direction the user wants, output a view they (and you) can reason over.

## 1. Inspect

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
echo "VAULT=$VAULT"
```

## 2. Pick the right direction

Map natural-language asks to `--direction=`:

| User says | Use direction | Required args |
|---|---|---|
| "show me the whole graph", "what have I tried" | `all` (default if no `--from`) | none |
| "what's downstream of X", "subtree from X" | `down` (default if `--from` given) | `--from=<id>` |
| "lineage of X up to root", "what led to X" | `up` | `--from=<id>` |
| "show X with its lineage AND descendants" | `both` | `--from=<id>` |
| "what else came from the same parent as X" | `siblings` | `--from=<id>` |
| "context around X" (parents, siblings, children) | `neighborhood` | `--from=<id>` |
| "path from X to Y", "how are X and Y related" | `path` | `--from=<id> --to=<id>` |
| "what threads are still open", "unfinished work" | `orphans` | none |

If user asks something else (e.g. "all FAIL nodes"), pick the right `--filter=` AND a sensible direction (usually `all`).

## 3. Run

```bash
python3 "${CLAUDE_SKILL_DIR}/traverse.py" "$VAULT" \
  [--from=<id>] [--to=<id>] [--direction=<dir>] \
  [--depth=<N>] [--filter=<f>] [--format=<f>]
```

Default values: `--direction=down` (or `all` if no `--from`), `--depth=100`, `--filter=all`, `--format=tree`.

**Format choice:**
- `tree` (default): ASCII tree, human-readable, shows status/verdict/metrics badges. Use when you'll show output to user.
- `yaml`: structured dump (nodes + cross_links + metrics). Use when YOU need to reason programmatically across many nodes (e.g., "which sibling has highest acc"); don't dump YAML at the user unless they explicitly want raw data.

## 4. Answer the user

Echo the python output, THEN address the user's actual question. Don't just dump tree silently. Examples:

- User: "what's open?"  →  Run `--direction=orphans`, then summarize: "3 open threads: nn6c97 needs `/exp-record`, ..."
- User: "show me lineage of X"  →  Run `--from=X --direction=up`, then point out key turning points along the chain.
- User: "anything contradicts the baseline?"  →  Run default tree, then read the Cross-links section, summarize contradictions.
- User: "what's the deepest path?"  →  Run `--direction=all --format=yaml`, parse for longest chain, answer.

## 5. Direction quick reference (paste verbatim if user asks)

```
/exp-traverse                              # full DAG from all roots
/exp-traverse --from=<id>                  # subtree under X (= --direction=down)
/exp-traverse --from=<id> --direction=up   # ancestor chain X → root
/exp-traverse --from=<id> --direction=both # X's lineage + descendants
/exp-traverse --from=<id> --direction=siblings    # same-parent peers
/exp-traverse --from=<id> --direction=neighborhood # parents + siblings + children
/exp-traverse --from=<a> --to=<b> --direction=path # shortest path a ↔ b
/exp-traverse --direction=orphans          # active/idea leaves (open threads)

/exp-traverse --filter=fail                # mark FAIL nodes, keep tree shape
/exp-traverse --filter=open                # mark active/idea nodes
/exp-traverse --depth=2                    # limit walk depth
/exp-traverse --format=yaml                # structured (for programmatic reasoning)
```
