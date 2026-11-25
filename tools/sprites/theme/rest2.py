import glob, os, colorsys
from recolor import recolor, ramp
U='/home/claude/bible-player/game/Graphics/UI'
def lum(k): return 0.299*k[0]+0.587*k[1]+0.114*k[2]
def all_ramp(h,l,s,k): return ramp(lum(k))
def redblue(h,l,s,k):
  if (h<20 or h>330) and s>0.45: return (47,93,138)
  return all_ramp(h,l,s,k)
def mapfn(h,l,s,k):
  if 180<=h<=250 and s>0.25:                       # water: muted blue
    r,g,b=colorsys.hls_to_rgb(205/360,l*0.88,min(0.55,s*1.0)); return (round(r*255),round(g*255),round(b*255))
  if (h<15 or h>340) and s>0.5: return k           # red town dots stay red
  # land: old-map ochre, darker where the hills are
  L=lum(k); t=max(0,min(1,(L-90)/150))
  a=(150,110,62); b=(238,222,184)
  return tuple(round(a[i]+(b[i]-a[i])*t) for i in range(3))
keep={'icon_own','icon_seen','icon_types','icon_shapes','icon_hw','icon_menuseenown'}
jobs=[]
for f in glob.glob(U+'/Pokedex/*.png'):
  n=os.path.basename(f)[:-4]
  if n in keep: continue
  jobs.append((f,'Pokedex',redblue if n.startswith('cursor') else all_ramp))
for f in glob.glob(U+'/Naming/*.png'):
  n=os.path.basename(f)[:-4]
  jobs.append((f,'Naming',redblue if n.startswith('cursor') else all_ramp))
for n in ['bg','overlay_main','overlay_party']:
  jobs.append((U+'/Storage/%s.png'%n,'Storage',all_ramp))
jobs.append((U+'/Town Map/bg.png','Town Map',all_ramp))
jobs.append((U+'/Town Map/mapRegion2.png','Town Map',mapfn))
for f,d,fn in jobs:
  os.makedirs('out/'+d,exist_ok=True); recolor(f,'out/%s/%s'%(d,os.path.basename(f)),sat_keep=0,hue_map=fn)
print(len(jobs))
