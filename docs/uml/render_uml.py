#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def main() -> int:
    plantuml = shutil.which("plantuml")
    files = sorted(ROOT.glob("*.puml"))

    if not files:
        print("No .puml files found in", ROOT)
        return 1

    if not plantuml:
        print("plantuml is not installed or not in PATH.")
        print("Install PlantUML locally, or use the Docker command from docs/uml/README.md")
        return 1

    cmd = [plantuml, "-tpng", *[str(file) for file in files]]
    print("Rendering UML diagrams...")
    print("Command:", " ".join(cmd))

    completed = subprocess.run(cmd, cwd=ROOT)
    if completed.returncode == 0:
        print("Rendered", len(files), "diagram(s) in", ROOT)
    return completed.returncode


if __name__ == "__main__":
    sys.exit(main())
