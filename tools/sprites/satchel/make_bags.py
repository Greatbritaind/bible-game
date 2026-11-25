from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage
q=np.array(Image.open('downq.png')).astype(int)
H,W=q.shape[:2]
op=q[:,:,3]>0; dark=(q[:,:,0]+q[:,:,1]+q[:,:,2])<100
fill=op&~dark
lab,n=ndimage.label(fill)
yy,xx=np.mgrid[0:H,0:W]
L=lambda *ids: np.isin(lab,ids)
belly=lab==13
# bottom band follows the curve of the bag: the lowest 7 belly pixels in each column
bottom=np.zeros_like(belly)
for x in range(W):
  ys=np.where(belly[:,x])[0]
  if len(ys): bottom[ys[ys>=ys.max()-11],x]=True
center=belly&~bottom&(((xx-43)/16)**2+((yy-82)/11)**2<=1)
side=belly&~bottom&~center
regions={
 1: center,                                   # Items: middle of the bag
 2: L(5),                                     # Medicine: right flap
 3: side&(xx>=43),                            # Poké Balls: right side
 4: bottom&(xx>=56),                          # TMs & HMs: bottom right
 5: L(7),                                     # Berries: left flap
 6: bottom&(xx>=30)&(xx<56),                  # Mail: bottom middle
 7: side&(xx<43),                             # Battle Items: left side
 8: bottom&(xx<30),                           # Key Items: bottom left
}
RED=np.array([226,64,58]); A=0.55
def canvas(arr):
  c=Image.new('RGBA',(128,128),(0,0,0,0))
  sh=Image.new('RGBA',(128,128),(0,0,0,0)); d=ImageDraw.Draw(sh)
  d.ellipse((22,111,106,125),fill=(60,40,28,90))
  c.alpha_composite(sh)
  c.alpha_composite(Image.fromarray(arr.astype(np.uint8)),((128-W)//2,10))
  return c
import os
os.makedirs('out',exist_ok=True)
canvas(q).save('out/bag_blank.png')
for k,m in regions.items():
  a=q.copy(); sel=m
  a[sel,:3]=(a[sel,:3]*(1-A)+RED*A).round()
  img=canvas(a); img.save(f'out/bag_{k}.png'); img.save(f'out/bag_{k}_f.png')
# check every fill pixel of the bag body belongs somewhere
cover=sum(m.astype(int) for m in regions.values()); print('overlap px',(cover>1).sum(),'uncovered leather px',((cover==0)&(belly|L(5,7))).sum())
G=(232,214,170,255)
names=['Items','Medicine','Poké Balls','TMs & HMs','Berries','Mail','Battle Items','Key Items']
sheet=Image.new('RGBA',(4*140,2*150),G)
for k in range(1,9):
  im=Image.open(f'out/bag_{k}.png'); sheet.alpha_composite(im,(((k-1)%4)*140+6,((k-1)//4)*150+4))
sheet=sheet.resize((sheet.width*2,sheet.height*2),Image.NEAREST); d=ImageDraw.Draw(sheet)
for k in range(1,9): d.text((((k-1)%4)*280+14,((k-1)//4)*300+268),f'{k}. {names[k-1]}',fill=(43,33,24))
sheet.save('bags_preview.png')
