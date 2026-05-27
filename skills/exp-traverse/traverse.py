#!/usr/bin/env python3
"""Traverse the experiment vault in any direction.

Usage:
  traverse.py <vault-path> [--from=<id>] [--direction=DIR] [--depth=N]
                            [--to=<id>] [--filter=F] [--format=FMT]

Directions (default: down):
  down          subtree under --from (or all roots if --from missing)
  up            ancestor chain from --from up to root
  both          up + down (lineage + descendants of --from)
  siblings      nodes sharing any parent with --from
  neighborhood  parents + siblings + children of --from (1 hop each direction)
  path          shortest path from --from to --to (requires --to)
  orphans       active/idea nodes with no children (open threads)
  all           every node, grouped by root (= old default)

Filters: all (default), open (idea|active), pass, fail.
Formats: tree (default ASCII), yaml (structured dump).
"""
from __future__ import annotations

import re
import sys
from collections import deque
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: PyYAML required\n"); sys.exit(2)


FM_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)
WIKI_RE = re.compile(r"\[\[([^\]|#]+?)\]\]")


def _wiki_to_id(wikistr: str) -> str | None:
    """[[2026-05-abc123-slug]] → 'abc123' (or None)."""
    m = WIKI_RE.search(wikistr)
    if not m:
        return None
    parts = m.group(1).split("-")
    return parts[2] if len(parts) >= 4 else None


def load_node(path: Path) -> dict | None:
    text = path.read_text()
    m = FM_RE.match(text)
    if not m:
        return None
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None
    # Critical: coerce id to str (YAML may parse e.g. "491227" as int)
    fm["id"] = str(fm.get("id") or "")
    fm["_file"] = path
    fm["_wiki"] = path.stem
    fm["_body"] = m.group(2)
    fm["_parent_ids"] = []
    for p in fm.get("parents") or []:
        if isinstance(p, str):
            pid = _wiki_to_id(p)
            if pid:
                fm["_parent_ids"].append(pid)
    return fm


def load_all(vault: Path) -> dict[str, dict]:
    nodes = {}
    for p in sorted((vault / "nodes").glob("*.md")):
        if p.name == ".gitkeep" or p.name.startswith("."):
            continue
        n = load_node(p)
        if n and n.get("id"):
            nodes[n["id"]] = n
    for n in nodes.values():
        n["_children_ids"] = []
    for nid, n in nodes.items():
        for pid in n["_parent_ids"]:
            if pid in nodes:
                nodes[pid]["_children_ids"].append(nid)
    return nodes


def conclusion_verdict(body: str) -> str:
    m = re.search(r"^## Conclusion\n(.*?)(?=^## |\Z)", body, re.MULTILINE | re.DOTALL)
    if not m:
        return "?"
    txt = m.group(1).upper()
    if "FAIL" in txt:
        return "FAIL"
    if "PARTIAL" in txt:
        return "PARTIAL"
    if "PASS" in txt:
        return "PASS"
    return "?"


def metrics_one_line(metrics) -> str:
    if not isinstance(metrics, dict) or not metrics:
        return ""
    parts = []
    for k, v in list(metrics.items())[:3]:
        parts.append(f"{k}={v}")
    extra = "" if len(metrics) <= 3 else f" +{len(metrics)-3}"
    return " " + " ".join(parts) + extra


def matches_filter(node: dict, filt: str) -> bool:
    if filt == "all":
        return True
    status = node.get("status", "")
    if filt == "open":
        return status in ("idea", "active")
    verdict = conclusion_verdict(node["_body"])
    if filt == "pass":
        return status == "completed" and verdict == "PASS"
    if filt == "fail":
        return status == "completed" and verdict == "FAIL"
    return True


# -------------------- Direction selectors --------------------

def collect_descendants(nodes: dict, start: str, depth_limit: int) -> set[str]:
    out = set()
    q = deque([(start, 0)])
    while q:
        nid, d = q.popleft()
        if nid in out or d > depth_limit or nid not in nodes:
            continue
        out.add(nid)
        for c in nodes[nid]["_children_ids"]:
            q.append((c, d + 1))
    return out


def collect_ancestors(nodes: dict, start: str, depth_limit: int) -> set[str]:
    out = set()
    q = deque([(start, 0)])
    while q:
        nid, d = q.popleft()
        if nid in out or d > depth_limit or nid not in nodes:
            continue
        out.add(nid)
        for p in nodes[nid]["_parent_ids"]:
            q.append((p, d + 1))
    return out


def collect_siblings(nodes: dict, start: str) -> set[str]:
    if start not in nodes:
        return set()
    me = nodes[start]
    parent_set = set(me["_parent_ids"])
    out = set()
    for nid, n in nodes.items():
        if nid == start:
            continue
        if parent_set & set(n["_parent_ids"]):
            out.add(nid)
    return out


def collect_neighborhood(nodes: dict, start: str) -> set[str]:
    if start not in nodes:
        return set()
    out = {start}
    out.update(nodes[start]["_parent_ids"])
    out.update(nodes[start]["_children_ids"])
    out.update(collect_siblings(nodes, start))
    return out


def shortest_path(nodes: dict, src: str, dst: str) -> list[str]:
    """Undirected BFS over parent+child edges."""
    if src not in nodes or dst not in nodes:
        return []
    prev = {src: None}
    q = deque([src])
    while q:
        cur = q.popleft()
        if cur == dst:
            path = []
            while cur is not None:
                path.append(cur)
                cur = prev[cur]
            return list(reversed(path))
        for nb in nodes[cur]["_parent_ids"] + nodes[cur]["_children_ids"]:
            if nb in nodes and nb not in prev:
                prev[nb] = cur
                q.append(nb)
    return []


def collect_orphans(nodes: dict) -> set[str]:
    """Active/idea leaves — open threads with no child yet."""
    out = set()
    for nid, n in nodes.items():
        if n.get("status") in ("idea", "active") and not n["_children_ids"]:
            out.add(nid)
    return out


# -------------------- Rendering --------------------

def render_node_line(nodes: dict, nid: str, prefix: str, last: bool, you_are_here: bool, filt: str) -> str:
    n = nodes[nid]
    verdict = conclusion_verdict(n["_body"]) if n.get("status") == "completed" else ""
    tag = f"[{n.get('status', '?')}"
    if verdict and verdict != "?":
        tag += f" {verdict}"
    tag += "]"
    marker = " ◀── you are here" if you_are_here else ""
    suffix = "" if matches_filter(n, filt) else "  (filtered)"
    return (f"{prefix}{'└── ' if last else '├── '}{nid} {n.get('slug', '?')} "
            f"{tag}{metrics_one_line(n.get('metrics'))}{marker}{suffix}")


def render_tree(nodes: dict, roots: list[str], visible: set[str], depth_limit: int,
                filt: str, focus_id: str | None = None) -> str:
    """Render tree, but only descend into children that are in `visible`."""
    out = []
    seen = set()

    def walk(nid: str, prefix: str, last: bool, depth: int):
        if depth > depth_limit or nid in seen:
            return
        seen.add(nid)
        if nid not in nodes:
            return
        line = render_node_line(nodes, nid, prefix, last,
                                you_are_here=(nid == focus_id), filt=filt)
        out.append(line)
        kids = [c for c in nodes[nid]["_children_ids"] if c in visible]
        new_prefix = prefix + ("    " if last else "│   ")
        for i, kid in enumerate(kids):
            walk(kid, new_prefix, i == len(kids) - 1, depth + 1)

    for i, rid in enumerate(roots):
        if rid in visible:
            walk(rid, "", i == len(roots) - 1, 0)
    return "\n".join(out)


def render_chain(nodes: dict, chain: list[str], focus_id: str | None) -> str:
    """Render a linear chain (used for `up` and `path`) top-down with indent."""
    out = []
    for i, nid in enumerate(chain):
        if nid not in nodes:
            continue
        n = nodes[nid]
        verdict = conclusion_verdict(n["_body"]) if n.get("status") == "completed" else ""
        tag = f"[{n.get('status', '?')}"
        if verdict and verdict != "?":
            tag += f" {verdict}"
        tag += "]"
        prefix = "  " * i + ("└─ " if i > 0 else "")
        marker = " ◀── you are here" if nid == focus_id else ""
        out.append(f"{prefix}{nid} {n.get('slug', '?')} {tag}"
                   f"{metrics_one_line(n.get('metrics'))}{marker}")
    return "\n".join(out)


def gather_cross_links(nodes: dict, restrict: set[str] | None = None) -> list[tuple[str, str, str]]:
    seen = set(); out = []
    for nid, n in nodes.items():
        if restrict is not None and nid not in restrict:
            continue
        for link in n.get("links") or []:
            if not isinstance(link, dict):
                continue
            other = _wiki_to_id(str(link.get("to", "")))
            rel = link.get("relation", "")
            if not other or not rel:
                continue
            if restrict is not None and other not in restrict:
                continue
            key = tuple(sorted([nid, other]) + [rel])
            if key in seen:
                continue
            seen.add(key); out.append((nid, other, rel))
    return out


def render_stats(nodes: dict) -> str:
    by_status, by_verdict = {}, {"PASS": 0, "FAIL": 0, "PARTIAL": 0, "?": 0}
    for n in nodes.values():
        by_status[n.get("status", "?")] = by_status.get(n.get("status", "?"), 0) + 1
        if n.get("status") == "completed":
            v = conclusion_verdict(n["_body"])
            by_verdict[v] = by_verdict.get(v, 0) + 1
    parts = [f"Total: {len(nodes)}"]
    parts.append("Status: " + " ".join(f"{k}={v}" for k, v in sorted(by_status.items())))
    if any(by_verdict.values()):
        parts.append("Verdict: " + " ".join(f"{k}={v}" for k, v in by_verdict.items() if v))
    return " | ".join(parts)


def render_yaml(nodes: dict, visible: set[str]) -> str:
    out = {}
    for nid in sorted(visible):
        if nid not in nodes:
            continue
        n = nodes[nid]
        out[nid] = {
            "slug": n.get("slug"),
            "status": n.get("status"),
            "verdict": conclusion_verdict(n["_body"]) if n.get("status") == "completed" else None,
            "parents": n["_parent_ids"],
            "children": n["_children_ids"],
            "github-branch": n.get("github-branch"),
            "github-repo": n.get("github-repo"),
            "metrics": n.get("metrics", {}),
            "date-completed": str(n.get("date-completed") or ""),
        }
    return yaml.dump({
        "nodes": out,
        "cross_links": [{"a": a, "b": b, "relation": r}
                        for a, b, r in gather_cross_links(nodes, visible)],
    }, default_flow_style=False, sort_keys=False, allow_unicode=True)


# -------------------- Main --------------------

def main(argv: list[str]) -> int:
    args = {"from": None, "to": None, "direction": "down",
            "depth": 100, "filter": "all", "format": "tree"}
    vault = None
    for a in argv[1:]:
        if a.startswith("--from="):       args["from"] = a.split("=", 1)[1]
        elif a.startswith("--to="):       args["to"] = a.split("=", 1)[1]
        elif a.startswith("--direction="): args["direction"] = a.split("=", 1)[1]
        elif a.startswith("--depth="):    args["depth"] = int(a.split("=", 1)[1])
        elif a.startswith("--filter="):   args["filter"] = a.split("=", 1)[1]
        elif a.startswith("--format="):   args["format"] = a.split("=", 1)[1]
        elif not a.startswith("--"):      vault = Path(a)
    if not vault or not vault.exists():
        sys.stderr.write(f"ERROR: bad vault path: {vault}\n{__doc__}")
        return 2

    nodes = load_all(vault)
    if not nodes:
        print("(empty vault)"); return 0

    direction = args["direction"]
    start = args["from"]
    focus_id = start

    # ----- Determine `visible` set + the roots from which to render -----
    if direction == "all" or (direction == "down" and start is None):
        visible = set(nodes.keys())
        roots = sorted([nid for nid, n in nodes.items() if not n["_parent_ids"]],
                       key=lambda x: nodes[x].get("date-created", ""))
        header = f"DAG ({vault.name})  [direction=all roots]"

    elif direction == "down":
        if start not in nodes:
            sys.stderr.write(f"ERROR: --from id '{start}' not found\n"); return 1
        visible = collect_descendants(nodes, start, args["depth"])
        roots = [start]
        header = f"DAG ({vault.name})  [from={start}, direction=down, depth≤{args['depth']}]"

    elif direction == "up":
        if start not in nodes:
            sys.stderr.write(f"ERROR: --from id '{start}' not found\n"); return 1
        visible = collect_ancestors(nodes, start, args["depth"])
        # render as linear chain root→start
        chain = sorted(visible, key=lambda nid: len(collect_ancestors(nodes, nid, 100)))
        print("=" * 70)
        print(f"DAG ({vault.name})  [from={start}, direction=up, depth≤{args['depth']}]")
        print(render_stats(nodes)); print("=" * 70); print()
        print(render_chain(nodes, chain, focus_id))
        xl = gather_cross_links(nodes, visible)
        if xl:
            print(); print("Cross-links:")
            for a, b, r in xl:
                print(f"  {r:12} {a} {nodes[a].get('slug','?')}  ↔  {b} {nodes[b].get('slug','?')}")
        return 0

    elif direction == "both":
        if start not in nodes:
            sys.stderr.write(f"ERROR: --from id '{start}' not found\n"); return 1
        visible = collect_ancestors(nodes, start, args["depth"]) | collect_descendants(nodes, start, args["depth"])
        roots = sorted([nid for nid in visible if not (set(nodes[nid]["_parent_ids"]) & visible)],
                       key=lambda x: nodes[x].get("date-created", ""))
        header = f"DAG ({vault.name})  [from={start}, direction=both, depth≤{args['depth']}]"

    elif direction == "siblings":
        if start not in nodes:
            sys.stderr.write(f"ERROR: --from id '{start}' not found\n"); return 1
        sibs = collect_siblings(nodes, start)
        visible = sibs | {start}
        roots = sorted(nodes[start]["_parent_ids"]) or [start]
        for r in roots:
            visible.add(r)
        header = f"DAG ({vault.name})  [siblings of {start}]"

    elif direction == "neighborhood":
        if start not in nodes:
            sys.stderr.write(f"ERROR: --from id '{start}' not found\n"); return 1
        visible = collect_neighborhood(nodes, start)
        roots = sorted([nid for nid in visible if not (set(nodes[nid]["_parent_ids"]) & visible)],
                       key=lambda x: nodes[x].get("date-created", ""))
        header = f"DAG ({vault.name})  [neighborhood of {start}: parents+siblings+children]"

    elif direction == "path":
        if not start or not args["to"]:
            sys.stderr.write("ERROR: direction=path requires --from=<a> --to=<b>\n"); return 1
        path = shortest_path(nodes, start, args["to"])
        if not path:
            print(f"(no path between {start} and {args['to']})"); return 0
        print("=" * 70)
        print(f"PATH ({vault.name})  {start} → {args['to']}")
        print("=" * 70); print()
        print(render_chain(nodes, path, focus_id=None))
        return 0

    elif direction == "orphans":
        visible = collect_orphans(nodes)
        if not visible:
            print("(no open threads — all nodes either completed or have children)"); return 0
        print("=" * 70)
        print(f"OPEN THREADS ({vault.name})  [idea/active leaves]")
        print(render_stats(nodes)); print("=" * 70); print()
        for nid in sorted(visible, key=lambda x: nodes[x].get("date-created", "")):
            n = nodes[nid]
            print(f"  • {nid} {n.get('slug', '?')}  [{n.get('status','?')}]"
                  f"{metrics_one_line(n.get('metrics'))}")
            if n["_parent_ids"]:
                for pid in n["_parent_ids"]:
                    if pid in nodes:
                        print(f"      └ parent: {pid} {nodes[pid].get('slug','?')}")
        return 0

    else:
        sys.stderr.write(f"ERROR: unknown direction '{direction}'\n{__doc__}")
        return 2

    # ----- YAML format (early exit) -----
    if args["format"] == "yaml":
        sys.stdout.write(render_yaml(nodes, visible))
        return 0

    # ----- Tree format -----
    print("=" * 70); print(header); print(render_stats(nodes)); print("=" * 70); print()
    print(render_tree(nodes, roots, visible, args["depth"], args["filter"], focus_id))
    xl = gather_cross_links(nodes, visible)
    if xl:
        print(); print("Cross-links (within visible set):")
        for a, b, r in xl:
            print(f"  {r:12} {a} {nodes[a].get('slug','?')}  ↔  {b} {nodes[b].get('slug','?')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
