# Repaint UI pictures into the papyrus / olive-wood palette without moving a single pixel.
# Grey and white pixels follow a brightness ramp from dark wood to light papyrus;
# colored pixels are kept unless a hue rule says otherwise.
from PIL import Image
import colorsys, sys
STOPS=[(0,(36,20,10)),(48,(58,36,20)),(96,(110,74,44)),(140,(165,120,76)),(185,(214,194,150)),(215,(230,211,166)),(240,(241,228,195)),(256,(247,238,214))]
def ramp(l):
  for (a,ca),(b,cb) in zip(STOPS,STOPS[1:]):
    if l<b:
      t=(l-a)/(b-a); return tuple(round(ca[i]+(cb[i]-ca[i])*t) for i in range(3))
  return STOPS[-1][1]
def recolor(src,dst,sat_keep=0.22,hue_map=None):
  im=Image.open(src).convert('RGBA'); px=im.load(); cache={}
  for y in range(im.height):
    for x in range(im.width):
      r,g,b,a=px[x,y]
      if a==0: continue
      k=(r,g,b)
      if k not in cache:
        h,l,s=colorsys.rgb_to_hls(r/255,g/255,b/255)
        lum=0.299*r+0.587*g+0.114*b
        if s<sat_keep or (max(r,g,b)-min(r,g,b))<40: cache[k]=ramp(lum)
        elif hue_map:
          cache[k]=hue_map(h*360,l,s,k) or k
        else: cache[k]=k
      px[x,y]=cache[k]+(a,)
  im.save(dst)
if __name__=='__main__':
  recolor(sys.argv[1],sys.argv[2])
