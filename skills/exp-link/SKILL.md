---
name: exp-link
description: Add a non-parent cross-edge between two existing experiment nodes. Relation is one of extends, contradicts, replicates. Use when you discover a relationship between two nodes in different branches of the DAG (e.g., experiment B replicates result of A but in a different setting). Updates the links field on BOTH nodes.
argument-hint: "<node-a-id> <node-b-id> <relation>"
allowed-tools: Bash(git *) Bash(source *) Bash(python3 *) Bash(test *) Read Write
---

# exp-link — link two nodes with a relation

You are running `/exp-link <a> <b> <relation>`. Goal: add a cross-edge `a` ↔ `b` typed as `extends` | `contradicts` | `replicates`. Edge is recorded on BOTH nodes.

## 1. Parse + validate

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault) || exit 1
REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"

A_ID="<a>"; B_ID="<b>"; REL="<relation>"

case "$REL" in
  extends|contradicts|replicates) ;;
  *) exp_die "relation must be one of: extends, contradicts, replicates (got '$REL')" ;;
esac

[[ "$A_ID" == "$B_ID" ]] && exp_die "cannot link a node to itself"

A_FILE=$(exp_node_path "$VAULT" "$A_ID")
B_FILE=$(exp_node_path "$VAULT" "$B_ID")
[[ -z "$A_FILE" ]] && exp_die "node '$A_ID' not found"
[[ -z "$B_FILE" ]] && exp_die "node '$B_ID' not found"

A_WIKI=$(basename "$A_FILE" .md)
B_WIKI=$(basename "$B_FILE" .md)
A_SLUG=$(exp_fm_get "$A_FILE" slug)
B_SLUG=$(exp_fm_get "$B_FILE" slug)

# Check duplicate
A_LINKS=$(exp_fm_get "$A_FILE" links)
if echo "$A_LINKS" | grep -F -q "$B_WIKI" && echo "$A_LINKS" | grep -F -q "$REL"; then
  exp_die "link already exists on $A_ID: ($REL → $B_WIKI)"
fi
```

## 2. Preview

```
About to link:
  A: <a-id> <a-slug>
  B: <b-id> <b-slug>
  relation: <relation>

Will append to A.links:
  - {to: "[[<b-wiki>]]", relation: <relation>}
Will append to B.links:
  - {to: "[[<a-wiki>]]", relation: <relation>}    # mirror entry

commit msg: "exp: link <relation> <a-id> ↔ <b-id>"
```

Ask: "Confirm? (y/n)".

## 3. Execute (atomic)

```bash
source "${CLAUDE_SKILL_DIR}/../_shared/lib.sh"
VAULT=$(exp_find_vault); REPO_ROOT=$(exp_repo_root "$VAULT"); cd "$REPO_ROOT"
A_ID="<a>"; B_ID="<b>"; REL="<relation>"
A_FILE=$(exp_node_path "$VAULT" "$A_ID")
B_FILE=$(exp_node_path "$VAULT" "$B_ID")
A_WIKI=$(basename "$A_FILE" .md)
B_WIKI=$(basename "$B_FILE" .md)

# YAML mapping flow style: {to: "[[wiki]]", relation: rel}
exp_fm_append "$A_FILE" links "{to: '[[${B_WIKI}]]', relation: ${REL}}"
exp_fm_append "$B_FILE" links "{to: '[[${A_WIKI}]]', relation: ${REL}}"

exp_vault_commit "$VAULT" "exp: link ${REL} ${A_ID} ↔ ${B_ID}" "$A_FILE" "$B_FILE"
```

## 4. Report

- Both files updated
- Commit SHA
- Note: in Obsidian's graph view, the new edge will appear after you reload the vault (frontmatter links don't render as edges by default — install Breadcrumbs plugin, OR run `/exp-link` already adds a body-level wikilink in a "Cross-links" section if you want vanilla-graph compatibility. Current implementation: frontmatter only.).
