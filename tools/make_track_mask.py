"""Build the tiny reusable white-alpha rail mask; never runs in the game."""
from pathlib import Path
import struct

destination = Path(__file__).resolve().parents[1] / "mod/content/gui/bulb_cockpit/symbols/track-strip.tga"
width, height = 4, 64
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
pixels = bytearray()
for y in range(height):
    edge = min(y, height - 1 - y)
    alpha = 0 if edge == 0 else 192 if edge == 1 else 255
    pixels.extend(bytes((255, 255, 255, alpha)) * width)
destination.write_bytes(header + pixels)
print(destination)
