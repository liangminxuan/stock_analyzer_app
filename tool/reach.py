#!/usr/bin/env python3
"""依赖可达性扫描 —— 审计用（见 AUDIT_REPORT.md 第 5 节）。

从 lib/main.dart 出发，沿 import 关系（跳过 dart: / package:）做图遍历，
输出从入口不可达的文件及其行数，用于发现死代码。

用法:
    python3 tool/reach.py            # 默认扫描 lib/，入口 lib/main.dart
    python3 tool/reach.py lib/main.dart
"""

import collections
import os
import re
import sys


def collect(root: str) -> dict:
    files = {}
    for dirpath, _, filenames in os.walk(root):
        for name in filenames:
            if name.endswith(".dart"):
                path = os.path.join(dirpath, name)
                with open(path, encoding="utf-8") as handle:
                    files[path] = handle.read()
    return files


def build_import_graph(files: dict) -> dict:
    graph = {path: set() for path in files}
    for path, source in files.items():
        for match in re.finditer(r"import\s+'([^']+)'", source):
            target = match.group(1)
            if target.startswith(("package:", "dart:")):
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if resolved in files:
                graph[path].add(resolved)
    return graph


def main() -> int:
    entry = sys.argv[1] if len(sys.argv) > 1 else "lib/main.dart"
    root = os.path.dirname(entry) or "."

    files = collect(root)
    if entry not in files:
        print(f"入口不存在: {entry}")
        return 1

    graph = build_import_graph(files)

    reached, stack = set(), [entry]
    while stack:
        current = stack.pop()
        if current in reached:
            continue
        reached.add(current)
        stack.extend(graph[current] - reached)

    unreached = sorted(set(files) - reached)
    total_lines = sum(len(source.splitlines()) for source in files.values())
    dead_lines = sum(len(files[path].splitlines()) for path in unreached)

    print(
        f"总 dart 行数: {total_lines} | 不可达文件: {len(unreached)}/{len(files)} "
        f"| 不可达行数: {dead_lines} ({dead_lines / total_lines * 100:.1f}%)"
    )
    for path in unreached:
        print(f"  - {path} {len(files[path].splitlines())} 行")

    print("\n被引用次数最多的文件（高耦合，改动需谨慎）:")
    fan_in = collections.Counter()
    for targets in graph.values():
        for target in targets:
            fan_in[target] += 1
    for path, count in fan_in.most_common(6):
        print(f"  {count:>3}  {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
