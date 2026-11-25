# Copies the wooden fence-post tiles from Outside.png into Interior General.png (row 290), unchanged.
import sys
from PIL import Image
SRC, OUT = sys.argv[1], sys.argv[2]
o = Image.open('/home/claude/bible-player/game/Graphics/Tilesets/Outside.png').convert('RGBA')
ts = Image.open(SRC).convert('RGBA')
if ts.height < 291*32:
    n = Image.new('RGBA', (256, 291*32), (0,0,0,0)); n.paste(ts, (0,0)); ts = n
PIECES = [(4,165), (3,165), (5,165), (6,165), (5,166)]   # left side, right side, bottom-left, bottom-right, bottom run
for i, (c, r) in enumerate(PIECES):
    ts.paste(o.crop((c*32, r*32, c*32+32, r*32+32)), (i*32, 290*32))
ts.save(OUT)
