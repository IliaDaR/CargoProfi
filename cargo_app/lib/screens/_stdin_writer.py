import sys
data = sys.stdin.read()
with open("/opt/CargoProfi/cargo_app/lib/screens/vehicles_screen.dart", "w") as f:
    f.write(data)
print(f"Written {len(data.splitlines())} lines")
