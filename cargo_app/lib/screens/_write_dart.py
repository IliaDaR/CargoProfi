#!/usr/bin/env python3
import sys, os
data = sys.stdin.buffer.read()
with open("/opt/CargoProfi/cargo_app/lib/screens/vehicles_screen.dart", "wb") as f:
    f.write(data)
lines = data.decode().count("\n")
print(f"Written {lines} lines")
