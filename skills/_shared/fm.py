#!/usr/bin/env python3
"""Frontmatter helper for exp-* skills.

CLI:
  fm.py get <file> <key>                  -> print value (YAML-formatted if complex)
  fm.py set <file> <key> <yaml-value>     -> write value (parsed as YAML)
  fm.py append-list <file> <key> <yaml>   -> append item to list field
  fm.py render <template> k=v k=v ...     -> render template with {{k}} substitutions
  fm.py body-replace <file> <section> <new-content-file>  -> replace markdown section
  fm.py fields <file>                     -> print all frontmatter as YAML
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: PyYAML required. Install: pip3 install pyyaml\n")
    sys.exit(2)


FM_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


def split_doc(text: str) -> tuple[dict, str]:
    m = FM_RE.match(text)
    if not m:
        return {}, text
    fm = yaml.safe_load(m.group(1)) or {}
    return fm, m.group(2)


def join_doc(fm: dict, body: str) -> str:
    fm_text = yaml.dump(fm, default_flow_style=False, sort_keys=False,
                        allow_unicode=True, width=1000).rstrip("\n")
    return f"---\n{fm_text}\n---\n{body}"


def cmd_get(file: str, key: str) -> int:
    fm, _ = split_doc(Path(file).read_text())
    val = fm.get(key)
    if val is None:
        return 1
    if isinstance(val, (list, dict)):
        print(yaml.dump(val, default_flow_style=False,
                        allow_unicode=True).rstrip())
    else:
        print(val)
    return 0


def cmd_set(file: str, key: str, yaml_value: str) -> int:
    path = Path(file)
    fm, body = split_doc(path.read_text())
    try:
        parsed = yaml.safe_load(yaml_value)
    except yaml.YAMLError:
        parsed = yaml_value
    fm[key] = parsed
    path.write_text(join_doc(fm, body))
    return 0


def cmd_append_list(file: str, key: str, yaml_item: str) -> int:
    path = Path(file)
    fm, body = split_doc(path.read_text())
    try:
        item = yaml.safe_load(yaml_item)
    except yaml.YAMLError:
        item = yaml_item
    current = fm.get(key) or []
    if not isinstance(current, list):
        sys.stderr.write(f"ERROR: field '{key}' is not a list\n")
        return 1
    current.append(item)
    fm[key] = current
    path.write_text(join_doc(fm, body))
    return 0


def cmd_render(template: str, *kvs: str) -> int:
    text = Path(template).read_text()
    for kv in kvs:
        if "=" not in kv:
            sys.stderr.write(f"ERROR: expected k=v, got '{kv}'\n")
            return 1
        k, v = kv.split("=", 1)
        text = text.replace("{{" + k + "}}", v)
    sys.stdout.write(text)
    return 0


def cmd_body_replace(file: str, section: str, content_file: str) -> int:
    """Replace `## <section>` block (until next `## ` or EOF) with content from file."""
    path = Path(file)
    fm, body = split_doc(path.read_text())
    new_content = Path(content_file).read_text().rstrip() + "\n"
    pat = re.compile(
        rf"(^## {re.escape(section)}\n)(.*?)(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    if not pat.search(body):
        sys.stderr.write(f"ERROR: section '## {section}' not found in {file}\n")
        return 1
    # Use a callable so digits in new_content aren't parsed as backrefs.
    new_body = pat.sub(lambda m: m.group(1) + new_content + "\n", body, count=1)
    path.write_text(join_doc(fm, new_body))
    return 0


def cmd_fields(file: str) -> int:
    fm, _ = split_doc(Path(file).read_text())
    print(yaml.dump(fm, default_flow_style=False,
                    allow_unicode=True, sort_keys=False).rstrip())
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    cmd = argv[1]
    args = argv[2:]
    try:
        if cmd == "get":
            return cmd_get(*args)
        if cmd == "set":
            return cmd_set(*args)
        if cmd == "append-list":
            return cmd_append_list(*args)
        if cmd == "render":
            return cmd_render(*args)
        if cmd == "body-replace":
            return cmd_body_replace(*args)
        if cmd == "fields":
            return cmd_fields(*args)
    except TypeError as e:
        sys.stderr.write(f"ERROR: bad args for '{cmd}': {e}\n{__doc__}")
        return 2
    sys.stderr.write(f"ERROR: unknown command '{cmd}'\n{__doc__}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
