#!/usr/bin/env python3
"""Generate dashboard/index.html by embedding the latest report JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PLACEHOLDER = "__REPORT_JSON__"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", required=True, help="Path to report JSON")
    parser.add_argument("--template", required=True, help="Path to HTML template")
    parser.add_argument("--output", required=True, help="Path to output HTML")
    args = parser.parse_args()

    report_path = Path(args.report)
    template_path = Path(args.template)
    output_path = Path(args.output)

    if not report_path.is_file():
        print(f"Report not found: {report_path}", file=sys.stderr)
        return 1
    if not template_path.is_file():
        print(f"Template not found: {template_path}", file=sys.stderr)
        return 1

    report = json.loads(report_path.read_text(encoding="utf-8"))
    template = template_path.read_text(encoding="utf-8")

    if PLACEHOLDER not in template:
        print(f"Placeholder {PLACEHOLDER} not found in template", file=sys.stderr)
        return 1

    embedded = json.dumps(report, ensure_ascii=True)
    output = template.replace(PLACEHOLDER, embedded)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output, encoding="utf-8")
    print(f"Dashboard written to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

