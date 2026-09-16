#!/usr/bin/env python3
"""Merges SonarQube generic coverage XML reports into one.

Usage: scripts/merge-sonar-coverage.py <output.xml> <report.xml>...

Unit and snapshot tests run in separate CI jobs, each producing its own report
from scripts/sonar-coverage.sh. A line counts as covered if any report covers it.
"""
import os
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import quoteattr

if len(sys.argv) < 3:
    sys.exit("usage: merge-sonar-coverage.py <output.xml> <report.xml>...")

output, reports = sys.argv[1], sys.argv[2:]
files = {}
for report in reports:
    for file in ET.parse(report).getroot().iter("file"):
        lines = files.setdefault(file.get("path"), {})
        for line in file.iter("lineToCover"):
            number = int(line.get("lineNumber"))
            lines[number] = lines.get(number, False) or line.get("covered") == "true"

os.makedirs(os.path.dirname(output) or ".", exist_ok=True)
with open(output, "w") as xml:
    xml.write('<coverage version="1">\n')
    for path in sorted(files):
        xml.write(f"  <file path={quoteattr(path)}>\n")
        for number in sorted(files[path]):
            covered = "true" if files[path][number] else "false"
            xml.write(f'    <lineToCover lineNumber="{number}" covered="{covered}"/>\n')
        xml.write("  </file>\n")
    xml.write("</coverage>\n")

total = sum(len(lines) for lines in files.values())
covered = sum(1 for lines in files.values() for hit in lines.values() if hit)
print(f"merged {len(reports)} reports: {len(files)} files, {covered}/{total} lines ({covered / max(total, 1):.1%})")
