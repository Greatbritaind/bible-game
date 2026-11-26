# Builds Essentials battle sprites and icons for the 8 newer Pokémon from PokeAPI/pokesprite art.
# Fronts: 2x into 192x192 (same as the game's Gen 5 fronts).
# Backs: 2-4x (whole-pixel), cropped into 160x160 showing the top ~68%, like the game's other backs.
# Icons: two 64x64 frames, art 2x, bottom at y=58, second frame 2px higher.
import sys, os
from PIL import Image
SRC, OUT = sys.argv[1], sys.argv[2]
MONS = {672:'SKIDDO',673:'GOGOAT',667:'LITLEO',668:'PYROAR',749:'MUDBRAY',750:'MUDSDALE',831:'WOOLOO',832:'DUBWOOL'}
def load(p): return Image.open(p).convert('RGBA')
def front(im):
    return im.resize((192,192), Image.NEAREST)
def back(im):
    bb = im.getbbox(); w, h = bb[2]-bb[0], bb[3]-bb[1]
    s = next(k for k in (4,3,2,1) if w*k <= 156 and h*k*0.68 <= 150)
    big = im.resize((96*s,96*s), Image.NEAREST)
    cx = (bb[0]+bb[2])*s//2; top = bb[1]*s
    vis = int(h*s*0.68)
    out = Image.new('RGBA',(160,160))
    y0 = top+vis-160
    crop = big.crop((cx-80, y0, cx+80, y0+160))
    out.alpha_composite(crop)
    return out
def icon(im):
    im = im.crop(im.getbbox()); im = im.resize((im.width*2, im.height*2), Image.NEAREST)
    if im.width > 64 or im.height > 60: im.thumbnail((64,60), Image.NEAREST)
    out = Image.new('RGBA',(128,64))
    x = (64-im.width)//2
    out.alpha_composite(im,(x, 58-im.height)); out.alpha_composite(im,(64+x, 56-im.height))
    return out
for d in ['Front','Back','Front shiny','Back shiny','Icons']: os.makedirs(f'{OUT}/Graphics/Pokemon/{d}', exist_ok=True)
os.makedirs(f'{OUT}/Audio/SE/Cries', exist_ok=True)
for i, n in MONS.items():
    for sub, suf in (('',''),('female/','_female')):
        if not os.path.exists(f'{SRC}/s/{sub}{i}.png'): continue
        front(load(f'{SRC}/s/{sub}{i}.png')).save(f'{OUT}/Graphics/Pokemon/Front/{n}{suf}.png')
        front(load(f'{SRC}/s/shiny/{sub}{i}.png')).save(f'{OUT}/Graphics/Pokemon/Front shiny/{n}{suf}.png')
        back(load(f'{SRC}/s/back/{sub}{i}.png')).save(f'{OUT}/Graphics/Pokemon/Back/{n}{suf}.png')
        back(load(f'{SRC}/s/back/shiny/{sub}{i}.png')).save(f'{OUT}/Graphics/Pokemon/Back shiny/{n}{suf}.png')
    ic = f'{SRC}/i{i}.png' if os.path.exists(f'{SRC}/i{i}.png') else f'{SRC}/ps_{n.lower()}.png'
    icon(load(ic)).save(f'{OUT}/Graphics/Pokemon/Icons/{n}.png')
    os.system(f'cp "{SRC}/c{i}.ogg" "{OUT}/Audio/SE/Cries/{n}.ogg"')
print('done')
