import glob, os
from recolor import recolor, ramp
U='/home/claude/bible-player/game/Graphics/UI'
def all_ramp(h,l,s,k): return ramp(0.299*k[0]+0.587*k[1]+0.114*k[2])
def redblue(h,l,s,k):
  if (h<20 or h>330) and s>0.45: return (47,93,138)
  return all_ramp(h,l,s,k)
jobs=[]
jobs+= [(f,'Summary',all_ramp) for f in glob.glob(U+'/Summary/bg_*.png')]
jobs+= [(f,'Bag',all_ramp) for f in glob.glob(U+'/Bag/bg_*.png')]
jobs+= [(U+'/Bag/cursor.png','Bag',redblue),(U+'/Bag/icon_slider.png','Bag',all_ramp)]
jobs+= [(U+'/Mart/bg.png','Mart',all_ramp),(U+'/Mart/cursor.png','Mart',redblue)]
for f,d,fn in jobs:
  os.makedirs('out/'+d,exist_ok=True); recolor(f,'out/%s/%s'%(d,os.path.basename(f)),sat_keep=0,hue_map=fn)
print(len(jobs))
