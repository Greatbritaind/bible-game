from PIL import Image
im=Image.open('orig.png').convert('RGBA'); px=im.load()
hair={(32,40,88):(48,32,24),(48,80,152):(92,60,38),(112,144,208):(138,98,62)}
skin={(216,144,112):(172,106,70),(240,184,144):(198,138,96),(248,208,176):(214,164,120),(120,64,64):(96,50,38)}
TUNIC,ROBE,ROBE_SH,CREAM,ROBE_HI,TAN=(51,27,18),(120,78,62),(90,58,47),(241,216,186),(146,98,76),(229,188,134)
for y in range(im.height):
  fy=y%48
  for x in range(im.width):
    r,g,b,a=px[x,y]
    if not a: continue
    c=(r,g,b); fx=x%32; row=y//48; center=10<=fx<=21 and row in (0,3)
    n=hair.get(c) or skin.get(c)
    if not n:
      if c==(224,96,128): n=TUNIC if center else ROBE
      elif c==(240,144,160): n=CREAM if center else ROBE_HI
      elif c==(200,48,40): n=CREAM
      elif c==(152,104,56): n=ROBE
      elif c==(112,72,40): n=ROBE_SH
      elif c==(40,40,40): n=(92,60,38) if fy<24 else TUNIC
      elif c==(56,56,56): n=(92,60,38) if fy<24 else TAN
    if n: px[x,y]=n+(255,)

# side views: open tunic shows cream along the front of the belly
orig=Image.open('orig.png').convert('RGBA').load()
OUT=[(16,16,16)]
for row,front_left in ((1,True),(2,False)):
  for f in range(4):
    for fy in range(32,38):
      y=row*48+fy
      xs=range(f*32,f*32+32) if front_left else range(f*32+31,f*32-1,-1)
      n=0
      for x in xs:
        p=orig[x,y]
        if not p[3] or p[:3] in OUT: 
          if n: break
          continue
        if p[:3] in [(224,96,128),(240,144,160),(112,72,40),(152,104,56)]:
          px[x,y]=CREAM+(255,); n+=1
          if n==2: break
        else: break
im.save('Baruch_shared.png')
G=(120,170,90,255)
def bgd(i):
  b=Image.new('RGBA',i.size,G); b.alpha_composite(i); return b
cur=bgd(Image.open('Baruch.png')); new=bgd(im); sc=bgd(Image.open('scribe.png').convert('RGBA'))
W=Image.new('RGBA',(128*3+40,256),G)
W.paste(cur,(0,64)); W.paste(new,(148,64)); W.paste(sc,(296,0))
W.resize((W.width*2,W.height*2),Image.NEAREST).save('shared_preview.png')
