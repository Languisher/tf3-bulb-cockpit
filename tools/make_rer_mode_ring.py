"""Build the shared RER rounded-square outline; never runs in the game."""
from pathlib import Path
import struct
from PIL import Image, ImageDraw

size, scale = 128, 8
alpha = Image.new('L', (size * scale, size * scale))
draw = ImageDraw.Draw(alpha)
draw.rounded_rectangle((6 * scale, 6 * scale, 122 * scale, 122 * scale),
                       radius=26 * scale, outline=255, width=8 * scale)
alpha = alpha.resize((size, size), Image.Resampling.LANCZOS)
pixels = bytearray()
for a in alpha.tobytes():
    pixels.extend((255, 255, 255, a))
header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
destination = Path(__file__).resolve().parents[1] / 'mod/content/gui/bulb_cockpit/symbols/rer-mode-ring.tga'
destination.write_bytes(header + pixels)
print(destination)
