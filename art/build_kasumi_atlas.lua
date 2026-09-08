-- Original, editable material studies. Run with Aseprite --batch --script.
-- Four 256px pages, with four 128px studies and 64 palette entries per page.
local out = assert(app.params.out, 'Pass --script-param out=<project directory>')
local names = {'Cedar boards','Lime plaster','Kawara roof','Retaining stone',
  'Damp earth','Bank moss','Cold glass','Lamplit paper',
  'Indigo cotton','Oxidised iron','Tree bark','Leaf clusters',
  'Harvest straw','Vermilion','Deep recess','Aged paper'}
local bases = {{112,94,74},{161,157,136},{94,110,112},{105,116,109},
  {88,86,72},{86,102,65},{87,121,127},{211,173,107},
  {66,94,110},{117,78,54},{86,84,69},{84,113,73},
  {158,143,89},{142,54,42},{30,36,36},{190,183,152}}
local function hash(x,y,k)
  local v = math.sin(x*127.1+y*311.7+k*74.7)*43758.5453
  return v-math.floor(v)
end
for page=0,3 do
local sprite = Sprite(256,256,ColorMode.RGB)
sprite:deleteLayer(sprite.layers[1])
local palette = Palette(64)
for k=page*4,page*4+3 do
  local ramp={}
  for j=0,15 do
    local c=bases[k+1];local f=.46+j*.061
    local function q(v) return math.min(255,math.max(0,math.floor(v*f/8)*8)) end
    ramp[j+1]=app.pixelColor.rgba(q(c[1]),q(c[2]),q(c[3]),255)
    palette:setColor((k%4)*16+j,Color{r=q(c[1]),g=q(c[2]),b=q(c[3])})
  end
  local layer=sprite:newLayer();layer.name=string.format('%02d · %s',k,names[k+1])
  local image=Image(128,128,ColorMode.RGB)
  for py=0,127 do for px=0,127 do
    local x,y=px/2,py/2
    local n=hash(math.floor(px/2),math.floor(py/3),k)
    local tone=8+math.floor(n*3)-1
    if k==0 or k==10 then
      local board=math.floor(x/16);local seam=x%16
      tone=8+math.floor(hash(board,0,k)*3)
      local grain=math.sin(x*2.8+math.sin(y*.11+board)*.8)
      if grain>.80 then tone=tone-2 end
      if seam==0 or seam==15.5 then tone=4 elseif seam==.5 then tone=11 end
      if math.abs(x-(board*16+7+math.sin(y*.10)*1.5))<.3 and y>13 and y<52 then tone=5 end
      if (y==8 or y==55) and seam==4 then tone=1 end
      local knot=((x-(board*16+9))/3)^2+((y-29)/6)^2
      if knot<1 then tone=4+math.floor(knot*5) end
    elseif k==1 then
      tone=9+math.floor(math.sin(x*.15)*math.sin(y*.13))
      if hash(math.floor(x/7),1,k)>.57 then tone=tone-math.floor((y/64)^2*2) end
      if math.abs(x-36-math.sin(y*.25)*2-math.floor(y/12))<.25 and y>39 then tone=6 end
      if n>.85 then tone=tone-1 end
    elseif k==2 then
      local xx=(x+math.floor(y/16)%2*8)%16
      tone=5+math.floor(math.sin(xx/16*math.pi)*7)
      if y%16==0 then tone=2 elseif y%16==1 then tone=12 end
      if xx==0 then tone=3 end
      if hash(math.floor(x/16),math.floor(y/16),k)>.73 then tone=tone-2 end
    elseif k==3 then
      local row=math.floor(y/16);local xx=(x+row%2*13)%32
      local seam=2+math.floor(math.sin(x*.5+row)*1.3)
      tone=7+math.floor(hash(math.floor((x+row%2*13)/32),row,k)*5)
      if y%16<seam or xx<2 then tone=2 elseif y%16<seam+2 then tone=12 end
      if n>.65 then tone=tone-1 end
    elseif k==4 then
      tone=7+math.floor(n*3)
      if hash(math.floor(px/2),math.floor(py/2),k)>.975 then tone=12 end
      if (x-19)^2+(y-37)^2<38 or (x-42)^2+(y-8)^2<18 then tone=6 end
    elseif k==5 or k==11 then
      tone=6+math.floor(n*4)
      if hash(math.floor(px/2),math.floor(py/3),k)>.90 then tone=11 end
    elseif k==6 then
      tone=7+math.floor((1-y/64)*3)+math.floor(math.sin(x*.35)*1.5)
      if x%23<2 then tone=11 end
      if y>48 then tone=tone-2 end
    elseif k==7 then
      tone=10+math.floor(math.cos(x*.05)*math.cos(y*.05)*2)
      if hash(x,y,k)>.80 then tone=tone-1 end
    elseif k==8 then
      tone=7+math.floor(math.sin(x*.45)*3)
      if y>59 or x<2 then tone=11 end
      if y%4==0 and x%3==0 then tone=tone+1 end
    elseif k==9 then
      tone=6+math.floor(n*5)
      if math.sin(x*.16)*math.sin(y*.12)>.45 then tone=4 end
      if x%21==0 then tone=11 end
    elseif k==12 then
      tone=7+math.floor(math.sin(x*1.7+math.sin(y*.25))*3)
      if y%13==0 then tone=tone-2 end
    elseif k==13 then tone=7+math.floor(n*3)
    elseif k==14 then tone=6
    else tone=9+math.floor(n*2);if y<3 or x>60 then tone=5 end end
    if hash(px,py,22)>.85 and k~=14 then tone=tone-1 end
    image:drawPixel(px,py,ramp[math.max(1,math.min(16,tone+1))])
  end end
  sprite:newCel(layer,1,image,Point(k%2*128,math.floor(k%4/2)*128))
end
sprite:setPalette(palette)
sprite:saveAs(out..'/art/kasumi_materials_'..page..'.aseprite')
sprite:saveCopyAs(out..'/assets/textures/KasumiAtlas'..page..'.png')
end
print('KASUMI: four 256x256 pages, 16 material studies, 64-entry RGB555 palettes')

-- A separate cutout page uses carefully drawn branch structure and leaf clusters.
-- Its transparent background is used only by tree crowns, not by crop blades.
local foliage=Sprite(256,256,ColorMode.RGB)
foliage:deleteLayer(foliage.layers[1])
local fp=Palette(64)
for j=0,63 do
  fp:setColor(j,Color{r=math.floor((31+j*.90)/8)*8,g=math.floor((49+j*1.16)/8)*8,b=math.floor((35+j*.69)/8)*8,a=j==0 and 0 or 255})
end
for kind=0,2 do
  local layer=foliage:newLayer();layer.name=({'Cedar · sprays','Broadleaf · clusters','Mountain ash · leaflets'})[kind+1]
  local im=Image(128,128,ColorMode.RGB);im:clear()
  local function ink(x,y,index)
    x=math.floor(x);y=math.floor(y)
    if x>=0 and y>=0 and x<128 and y<128 then
      local c=fp:getColor(math.max(1,math.min(63,index)))
      im:drawPixel(x,y,app.pixelColor.rgba(c.red,c.green,c.blue,255))
    end
  end
  local function line(x,y,xx,yy,c,w)
    local steps=math.max(math.abs(xx-x),math.abs(yy-y))*1.5
    for s=0,math.ceil(steps) do
      local t=s/math.max(1,steps)
      for dx=-w,w do for dy=-w,w do ink(x+(xx-x)*t+dx,y+(yy-y)*t+dy,c) end end
    end
  end
  local function leaf(x,y,length,width,a,tone)
    local co,si=math.cos(a),math.sin(a)
    for u=-length,length,.5 do
      local half=width*(1-math.abs(u/length)^1.4)
      for v=-half,half,.6 do ink(x+co*u-si*v,y+si*u+co*v,tone+(v<0 and 3 or -4)) end
    end
    line(x-co*length*.7,y-si*length*.7,x+co*length*.8,y+si*length*.8,tone+7,0)
  end
  line(59,119,70,12,18,1)
  for j=0,12 do
    local yy=24+j*6.6;local xx=70-(yy-12)*.105
    for side=-1,1,2 do
      local spread=(20+19*math.sin(j/13*math.pi))*side
      local ex,ey=xx+spread,yy-13+hash(j,side,kind)*8
      line(xx,yy,ex,ey,19,0)
      if kind==0 then
        for k=1,12 do
          local t=k/12;local sx,sy=xx+spread*t,yy+(ey-yy)*t
          local length=3+hash(j,k,side)*6
          line(sx,sy,sx+side*length*.7,sy-length,25+math.floor(hash(j,k,4)*24),0)
          line(sx,sy,sx-side*length*.22,sy+length*.60,21+math.floor(hash(j,k,3)*20),0)
        end
      else
        for k=1,5 do
          local t=k/5;local sx,sy=xx+spread*t,yy+(ey-yy)*t
          local a=math.atan(ey-yy,spread)
          local sz=kind==1 and 7 or 5
          leaf(sx,sy-4,sz,kind==1 and 3.6 or 2.2,a-.48,25+math.floor(hash(j,k,1)*19))
          leaf(sx+side*2,sy+4,sz,kind==1 and 3.6 or 2.2,a+.55,19+math.floor(hash(j,k,2)*19))
        end
      end
    end
  end
  foliage:newCel(layer,1,im,Point(kind%2*128,math.floor(kind/2)*128))
end
foliage:setPalette(fp)
foliage:saveAs(out..'/art/kasumi_foliage.aseprite')
foliage:saveCopyAs(out..'/assets/textures/KasumiFoliage.png')
print('KASUMI FOLIAGE: cedar sprays, broadleaf clusters and mountain-ash leaflets')
