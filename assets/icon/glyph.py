import math, re, cairosvg
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union
C='#7C9CFF'; BG='#0E0F12'
def path_poly(d, n=24):
    toks=re.findall(r'[MLCQZ]|-?\d+\.?\d*', d); i=0; pts=[]; cur=None; cmd=None
    while i<len(toks):
        t=toks[i]
        if t in 'MLCQZ': cmd=t; i+=1
        if cmd=='Z': break
        nums=lambda k: [float(x) for x in toks[i:i+k]]
        if cmd in 'ML': x,y=nums(2); i+=2; cur=(x,y); pts.append(cur)
        elif cmd=='C':
            a=nums(6); i+=6; p0=cur; p1,p2,p3=(a[0],a[1]),(a[2],a[3]),(a[4],a[5])
            for k in range(1,n+1):
                s=k/n; u=1-s
                pts.append((u**3*p0[0]+3*u*u*s*p1[0]+3*u*s*s*p2[0]+s**3*p3[0], u**3*p0[1]+3*u*u*s*p1[1]+3*u*s*s*p2[1]+s**3*p3[1]))
            cur=p3
        elif cmd=='Q':
            a=nums(4); i+=4; p0=cur; p1,p2=(a[0],a[1]),(a[2],a[3])
            for k in range(1,n+1):
                s=k/n; u=1-s
                pts.append((u*u*p0[0]+2*u*s*p1[0]+s*s*p2[0], u*u*p0[1]+2*u*s*p1[1]+s*s*p2[1]))
            cur=p2
    return Polygon(pts)
def rrect(x,y,w,h,r): return box(x+r,y+r,x+w-r,y+h-r).buffer(r, quad_segs=16)
W1,W2,WY,WR=(410,436),(596,436),436,34
body=path_poly('''M 446 318 L 474 318 C 470 355 474 390 492 412 L 526 412 L 526 372 Q 526 358 540 358 L 610 358
      C 632 358 646 380 646 404 L 646 420 Q 646 442 624 442 L 390 442 Q 366 442 366 418
      C 366 384 398 366 438 362 C 445 345 446 332 446 318 Z''')
scooter_body=unary_union([body, rrect(518,344,94,24,12), rrect(622,380,26,12,6), rrect(426,298,70,22,11)])
wheels=unary_union([Point(*W1).buffer(WR,quad_segs=32), Point(*W2).buffer(WR,quad_segs=32)])
hubs=unary_union([Point(*W1).buffer(12,quad_segs=16), Point(*W2).buffer(12,quad_segs=16)])
GAP=9
scooter=unary_union([scooter_body.difference(wheels.buffer(GAP)).buffer(-6,quad_segs=16).buffer(6,quad_segs=16), wheels.difference(hubs)])
cx,cy,r=512,255,150; a0=math.radians(31)
arc_pts=[(cx+r*math.cos(t), cy+r*math.sin(t)) for t in [math.pi-a0 + (k/200)*(math.pi+2*a0) for k in range(201)]]
# angles from 140deg going to 400deg (=40deg) via top (decreasing y means angle 270deg): go 140->400
arc=LineString(arc_pts).buffer(10, cap_style='round', quad_segs=16)
hands=LineString([(508,182),(508,262),(576,207)]).buffer(9, cap_style='round', join_style='round', quad_segs=16)
dimhand=LineString([(512,264),(550,296)]).buffer(9, cap_style='round', quad_segs=16).difference(hands.buffer(0.01))
clear=scooter_body.union(wheels).buffer(GAP+2)
main=unary_union([arc.difference(clear), hands, scooter])
dimhand=dimhand.difference(clear)
def to_d(g):
    polys=[g] if g.geom_type=='Polygon' else list(g.geoms)
    out=[]
    for p in polys:
        for ring in [p.exterior,*p.interiors]:
            c=list(ring.coords); out.append('M'+' L'.join(f'{x:.1f} {y:.1f}' for x,y in c)+' Z')
    return ' '.join(out)
MAIN_D, DIM_D = to_d(main), to_d(dimhand)
minx,miny,maxx,maxy=unary_union([main,dimhand]).bounds
GCX,GCY=(minx+maxx)/2,(miny+maxy)/2
def svg(bg=None, scale=0.15, color=C, dim=0.55, size=108):
    bgr=f'<rect width="108" height="108" fill="{bg}"/>' if bg else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="{size}" height="{size}">{bgr}
<g transform="translate(54 54) scale({scale}) translate({-GCX:.1f} {-GCY:.1f})" fill="{color}" fill-rule="evenodd">
<path d="{MAIN_D}"/><path d="{DIM_D}" fill-opacity="{dim}"/></g></svg>'''
def png(s, out, px): cairosvg.svg2png(bytestring=s.encode(), write_to=out, output_width=px, output_height=px)
if __name__=='__main__':
    print('bounds', minx,miny,maxx,maxy)
    # max radius from glyph center, in dp at scale
    import itertools
    allg=unary_union([main,dimhand]); far=max(math.hypot(x-GCX,y-GCY) for x,y in allg.convex_hull.exterior.coords)
    print('max radius dp', far*0.15, '(safe 33)')
    open('icon.svg','w').write(svg(BG)); open('foreground.svg','w').write(svg())
    png(svg(BG),'preview.png',512)
