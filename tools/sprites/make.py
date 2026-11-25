from PIL import Image
import sys
SP='/tmp/claude-0/-home-claude/5814e8cd-8e0d-5b58-b35b-15ab18587543/scratchpad/sprites/'
skin={(216,152,112):(172,106,70),(240,192,152):(198,138,96),(248,216,184):(214,164,120),(120,64,64):(96,50,38)}
jobs={
 'aFarmer 1.png':('aFisherman2.png',{(157,128,128):(140,138,88),(99,79,79):(88,90,54)}),
 'aFarm Woman 1.png':('aWoman 2.png',{(112,153,122):(184,136,72),(28,49,34):(96,62,30)}),
 'aFarmer 2.png':('Man 2.png',{(72,120,80):(146,102,58),(48,80,56):(104,70,40),(40,56,48):(70,46,28)}),
 'aBoy 1.png':('NPC 02.png',{**skin,(200,176,104):(110,72,44),(120,112,64):(72,46,30),(56,56,24):(40,26,18),
   (136,144,144):(176,156,118),(192,200,216):(214,198,160),(255,255,255):(236,224,192),(72,72,88):(128,104,72),
   (224,112,80):(150,98,60),(144,64,40):(104,66,40)}),
}
G=(120,170,90,255)
rows=[]
for out,(src,m) in jobs.items():
  im=Image.open(src).convert('RGBA'); o=im.copy(); px=im.load()
  for y in range(im.height):
    for x in range(im.width):
      p=px[x,y]
      if p[3] and p[:3] in m: px[x,y]=m[p[:3]]+(p[3],)
  im.save(SP+out)
  a=Image.new('RGBA',o.size,G); a.alpha_composite(o); b=Image.new('RGBA',o.size,G); b.alpha_composite(im)
  rows.append((a,b))
W=Image.new('RGBA',(128*4+16*3, 192*2+16),G)
for k,(a,b) in enumerate(rows):
  x=(k%2)*(128*2+40); y=(k//2)*(192+16)
  W.paste(a,(x,y)); W.paste(b,(x+128+8,y))
W.resize((W.width*2,W.height*2),Image.NEAREST).save(SP+'preview_all.png')
