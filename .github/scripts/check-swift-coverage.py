#!/usr/bin/env python3

import json
import os
from pathlib import Path
import sys


def main():
    root = Path(__file__).resolve().parents[2]
    sources = set((root / "Sources/AlibabaCloudCredentials").rglob("*.swift"))
    if not sources:
        raise ValueError("No production Swift files found")

    with open(sys.argv[1], encoding="utf-8") as report:
        data = json.load(report)
    coverage = {}
    for item in data["data"]:
        for file in item["files"]:
            path = Path(file["filename"]).resolve()
            if path not in sources:
                continue
            lines = file["summary"]["lines"]
            count, covered = lines["count"], lines["covered"]
            if (type(count) is not int or type(covered) is not int
                    or count <= 0 or not 0 <= covered <= count):
                raise ValueError(f"Invalid line coverage for {path.relative_to(root)}")
            if path in coverage:
                raise ValueError(f"Duplicate coverage for {path.relative_to(root)}")
            coverage[path] = (covered, count)

    missing = sources - coverage.keys()
    if missing:
        raise ValueError("Missing coverage for " + ", ".join(
            str(path.relative_to(root)) for path in sorted(missing)))

    covered = sum(lines[0] for lines in coverage.values())
    count = sum(lines[1] for lines in coverage.values())
    rows = ["## Swift line coverage", "", "| File | Covered / lines | Coverage |",
            "| --- | ---: | ---: |"]
    for path, (file_covered, file_count) in sorted(coverage.items()):
        rows.append(f"| {path.name} | {file_covered} / {file_count} | "
                    f"{file_covered / file_count:.2%} |")
    rows.extend([f"| **Total** | **{covered} / {count}** | **{covered / count:.2%}** |",
                 "", "Required line coverage: **90%**.", ""])
    summary = "\n".join(rows)
    print(summary, end="")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(summary)
    return 0 if covered * 100 >= count * 90 else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        print(f"Coverage check failed: {error}", file=sys.stderr)
        sys.exit(1)
