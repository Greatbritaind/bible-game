from PIL import Image, ImageDraw
import random
P  =(241,228,195,255); P2=(230,211,166,255); P3=(247,238,214,255)
WD =(110,74,44,255); WH=(165,120,76,255); WL=(58,36,20,255); EDGE=(138,106,67,255)
T=(0,0,0,0)
# ---- speech: 84x56, center 16x16 at (34,20) -> 34px sides, 20px top/bottom
w,h=84,56
im=Image.new('RGBA',(w,h),T); d=ImageDraw.Draw(im)
d.rectangle((6,4,w-7,h-5),fill=P)              # parchment
d.rectangle((6,4,w-7,7),fill=EDGE)             # top edge line
d.rectangle((6,8,w-7,9),fill=P3)               # light band under it
d.rectangle((6,h-8,w-7,h-5),fill=EDGE)         # bottom edge line
d.rectangle((6,h-14,w-7,h-9),fill=P2)          # soft shadow band
for x0 in (0,w-14):                            # rollers, full height
  for i,c in enumerate([WL,WL,WD,WD,WH,WH,WH,WD,WD,WD,WD,WL,WL,WL]):
    d.line((x0+i,0,x0+i,h-1),fill=c)
  d.rectangle((x0,0,x0+13,1),fill=WL); d.rectangle((x0,h-2,x0+13,h-1),fill=WL)
im.save('rtj_speech.png')
# ---- letter: a plain papyrus sheet (no rollers), 64x56 too
im=Image.new('RGBA',(w,h),T); d=ImageDraw.Draw(im)
L=(244,233,204,255); L2=(232,216,178,255); LE=(150,122,82,255)
d.rectangle((2,2,w-3,h-3),fill=L)
d.rectangle((2,2,w-3,3),fill=LE); d.rectangle((2,h-4,w-3,h-3),fill=LE)
d.rectangle((2,2,3,h-3),fill=LE); d.rectangle((w-4,2,w-3,h-3),fill=LE)
d.rectangle((4,h-8,w-5,h-5),fill=L2)
random.seed(4)
d.rectangle((6,6,w-7,6),fill=L2)              # a thin inner line along the top
im.save('rtj_letter.png')
# ---- menu / choice: 48x48 wood-framed tablet, center 16x16 at (16,16)
w=h=48
im=Image.new('RGBA',(w,h),T); d=ImageDraw.Draw(im)
d.rounded_rectangle((0,0,w-1,h-1),radius=4,fill=WL)
d.rounded_rectangle((2,2,w-3,h-3),radius=3,fill=WH)
d.rectangle((4,4,w-5,h-5),fill=WD)
d.rectangle((6,6,w-7,h-7),fill=WL)
d.rectangle((8,8,w-9,h-9),fill=P)
d.rectangle((8,h-12,w-9,h-9),fill=P2)
im.save('rtj_menu.png')
# ---- selection arrow 14x28, blue triangle
B=(47,93,138,255); BL=(20,44,68,255)
im=Image.new('RGBA',(12,28),T); d=ImageDraw.Draw(im)
d.polygon([(0,4),(11,13),(0,22)],fill=BL); d.polygon([(1,7),(8,13),(1,19)],fill=B)
im.save('sel_arrow.png')
G=(120,170,90,255)
for n in ['rtj_speech','rtj_letter','rtj_menu','sel_arrow']:
  x=Image.open(n+'.png'); b=Image.new('RGBA',x.size,G); b.alpha_composite(x); b.resize((x.width*6,x.height*6),Image.NEAREST).save('z_'+n+'.png')
