import colorsys, glob, os
from recolor import recolor, ramp
SRC='/home/claude/bible-player/game/Graphics/UI/Party'; OUT='out/Party'; os.makedirs(OUT,exist_ok=True)
def hl(th,l,s,lf=1.0,sf=0.5):
  r,g,b=colorsys.hls_to_rgb(th/360,min(1,l*lf),min(1,s*sf)); return (round(r*255),round(g*255),round(b*255))
def all_ramp(h,l,s,k): return ramp(0.299*k[0]+0.587*k[1]+0.114*k[2])
def sel(h,l,s,k):       # selected panel: wood body, red outline -> blue cord
  if (h<20 or h>330) and s>0.5: return (47,93,138)
  return all_ramp(h,l,s,k)
def faint(h,l,s,k): return hl(14,l,s,0.95,0.55)     # fainted: dusty terracotta
def swap(h,l,s,k):  return hl(208,l,s,0.95,0.45)    # swapping: muted blue
rules={'panel_round_sel':sel,'panel_rect_sel':sel,'panel_round_faint_sel':sel,'panel_rect_faint_sel':sel,
       'icon_cancel_sel':sel,'icon_cancel_narrow_sel':sel}
for f in glob.glob(SRC+'/*.png'):
  n=os.path.basename(f)[:-4]
  if n.startswith('overlay_hp') and n!='overlay_hp_back': continue   # keep the green/yellow/red HP bars
  if n.startswith('icon_ball') or n in ('icon_item','icon_mail'): continue
  if 'swap' in n: fn=swap
  elif 'faint' in n and not n.endswith('_sel'): fn=faint
  else: fn=rules.get(n,all_ramp)
  recolor(f,f'{OUT}/{n}.png',sat_keep=0,hue_map=fn)
