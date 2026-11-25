from PIL import Image, ImageDraw
W=408
P=(241,228,195,255); P2=(230,211,166,255); WD=(110,74,44,255); WH=(165,120,76,255); WL=(58,36,20,255); BL=(47,93,138,255); BLH=(91,139,189,255)
im=Image.new('RGBA',(W,536),(0,0,0,0)); d=ImageDraw.Draw(im)
def panel(y0,h,sel,header):
  y1=y0+h-1
  d.rounded_rectangle((0,y0,W-1,y1),radius=5,fill=WL)
  d.rounded_rectangle((2,y0+2,W-3,y1-2),radius=4,fill=WH)
  d.rectangle((4,y0+4,W-5,y1-4),fill=WD)
  d.rectangle((6,y0+6,W-7,y1-6),fill=WL)
  d.rectangle((8,y0+8,W-9,y1-8),fill=P)
  d.rectangle((8,y1-12,W-9,y1-8),fill=P2)
  if header:
    d.rectangle((8,y0+8,W-9,y0+47),fill=P2)
    d.rectangle((8,y0+48,W-9,y0+49),fill=WD)
  if sel:
    for i,c in enumerate([BL,BL,BLH]):
      d.rectangle((8+i,y0+8+i,W-9-i,y1-8-i),outline=c)
panel(0,222,False,True); panel(222,222,True,True); panel(444,46,False,False); panel(490,46,True,False)
im.save('panels.png')
