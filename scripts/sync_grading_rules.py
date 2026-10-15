"""Copy the canonical grading rules into Flutter's Android-packaged assets.

Run after editing grading_rules.yaml, before building the Flutter app.
Use --check in verification or CI to reject a stale packaged copy.
"""

from argparse import ArgumentParser
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "grading_rules.yaml"
TARGET = ROOT / "flutter_app" / "assets" / "grading_rules.yaml"


def main() -> int:
    parser = ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = SOURCE.read_bytes()
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != source:
            print("Flutter grading rules asset is stale. Run scripts/sync_grading_rules.py.")
            return 1
        print("Flutter grading rules asset matches the canonical YAML.")
        return 0
    TARGET.write_bytes(source)
    print(f"Updated {TARGET.relative_to(ROOT)} from grading_rules.yaml.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
