from PIL import Image
import json
TS='/home/claude/bible-player/game/Graphics/Tilesets/Interior General.png'
SRC=[1399,1407,1335,1342,1343,1351,1389,1397,1405,1406,1413,1414,1415,1422,1423,1430,1431,1438,1439]+[t for t in range(2341,2392)]
RAMP={'tan':[(84,70,52),(140,123,98),(180,160,130),(208,189,155),(230,214,180)],
      'grey':[(48,47,45),(94,92,88),(126,124,119),(154,152,147),(184,182,177)]}
START={'tan':263,'grey':273}   # first empty tileset row for each color
def lum(c): return 0.299*c[0]+0.587*c[1]+0.114*c[2]
def ramp(r,t):
  t=max(0,min(1,t)); p=t*(len(r)-1); i=min(int(p),len(r)-2); f=p-i
  return tuple(round(r[i][k]+(r[i+1][k]-r[i][k])*f) for k in range(3))
def build():
  ts=Image.open(TS).convert('RGBA')
  def tile(t): k=t-384; return ts.crop(((k%8)*32,(k//8)*32,(k%8)*32+32,(k//8)*32+32))
  used=[t for t in SRC if tile(t).getextrema()[3][1]>0]
  # brightness range of the dark tiles (ignore pure black edges)
  L=[lum(p[:3]) for t in used for p in tile(t).get_flattened_data() if p[3]>0 and lum(p[:3])>12]
  lo,hi=sorted(L)[len(L)//50],sorted(L)[-len(L)//50]
  mapping={}
  for name,r in RAMP.items():
    for i,t in enumerate(used):
      new=384+START[name]*8+i
      im=tile(t); px=im.load()
      for y in range(32):
        for x in range(32):
          p=px[x,y]
          if p[3]==0: continue
          l=lum(p[:3])
          px[x,y]=(ramp(r,max(0,(l-lo)/(hi-lo))**0.45) if l>12 else (30,24,18) if name=='tan' else (27,26,25))+(p[3],)
      k=new-384; ts.paste(im,((k%8)*32,(k//8)*32))
      mapping.setdefault(name,{})[t]=new
  return ts,mapping
if __name__=='__main__':
  ts,mp=build(); ts.save('Interior General.new.png'); json.dump(mp,open('wallmap.json','w')); print(len(mp['tan']))
