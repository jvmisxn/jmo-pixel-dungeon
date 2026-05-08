"""Run this script to strip null bytes from all .gd files in the project."""
import os

project_dir = os.path.dirname(os.path.abspath(__file__))
fixed = []

for root, dirs, files in os.walk(os.path.join(project_dir, "src")):
    for f in files:
        if not f.endswith(".gd"):
            continue
        path = os.path.join(root, f)
        with open(path, "rb") as fh:
            data = fh.read()
        if b"\x00" in data:
            clean = data.replace(b"\x00", b"")
            with open(path, "wb") as fh:
                fh.write(clean)
            fixed.append(path)
            print(f"FIXED: {path} (removed {len(data) - len(clean)} null bytes)")

if not fixed:
    print("All files clean - no null bytes found.")
else:
    print(f"\nFixed {len(fixed)} file(s).")

input("\nPress Enter to close...")
