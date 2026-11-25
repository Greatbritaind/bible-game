import colorsys, sys
from recolor import recolor
def hue_map(h,l,s,k):
  if h<25 or h>=330: th=16      # red -> terracotta
  elif h<50: th=38              # orange -> ochre
  elif h<170: th=72             # green -> olive
  else: th=208                  # blue -> tekhelet
  r,g,b=colorsys.hls_to_rgb(th/360,l*0.92,min(s,0.62)*0.8)
  return (round(r*255),round(g*255),round(b*255))
recolor(sys.argv[1],sys.argv[2],hue_map=hue_map)
