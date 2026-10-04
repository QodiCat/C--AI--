"""Check Agent entry size, maintained source size, and current documentation links."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []


def check_size(path, limit):
    count = len(path.read_text(encoding="utf-8").splitlines())
    if count > limit:
        errors.append(f"{path.relative_to(ROOT)}: {count} lines exceeds {limit}")


entries = [ROOT / "AGENTS.md"]
for scope in (".agents", "app/lib", "server"):
    entries.extend((ROOT / scope).rglob("AGENTS.md"))
for entry in entries:
    if not entry.exists():
        errors.append(f"Missing entry: {entry.relative_to(ROOT)}")
    else:
        check_size(entry, 50)

for scope in ("server", "app/lib", "app/test", "tools"):
    for path in (ROOT / scope).rglob("*"):
        if path.suffix in {".go", ".dart", ".py"} and not any(
            part in {".cache", "node_modules", "build"} for part in path.parts
        ):
            check_size(path, 500)

documents = [
    ROOT / "AGENTS.md", ROOT / "README.md", ROOT / "app/README.md",
    ROOT / "docs/README.md", ROOT / "docs/需求变更.md",
    ROOT / "docs/DEPLOYMENT.md",
    *(ROOT / ".agents").glob("*.md"),
]
for document in documents:
    if not document.exists():
        errors.append(f"Missing current document: {document.relative_to(ROOT)}")
        continue
    for target in re.findall(r"\]\(([^)]+)\)", document.read_text(encoding="utf-8")):
        if "://" in target or target.startswith("#"):
            continue
        relative = target.split("#", 1)[0]
        if not (document.parent / relative).exists():
            errors.append(f"{document.relative_to(ROOT)}: broken link {target}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("PASS: Agent entries <=50 lines, source files <=500 lines, current links valid")
