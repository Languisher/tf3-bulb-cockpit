"""Build the shared U7/U8 diagonal badge overlay; never runs in the game."""
from pathlib import Path
import struct

size, samples = 64, 4
pixels = bytearray()
for y in range(size):
    for x in range(size):
        covered = sum(x + (sx + .5) / samples + y + (sy + .5) / samples >= size
                      for sy in range(samples) for sx in range(samples))
        pixels.extend((255, 255, 255, round(255 * covered / (samples * samples))))
header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
destination = Path(__file__).resolve().parents[1] / 'mod/content/gui/bulb_cockpit/symbols/badge-diagonal.tga'
destination.write_bytes(header + pixels)
print(destination)
