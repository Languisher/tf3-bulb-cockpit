local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local asset=assert(io.open('mod/content/gui/bulb_cockpit/symbols/track-strip.tga','rb'))
local bytes=asset:read('*a');asset:close()
local w,h=string.unpack('<I2I2',bytes,13)
assert(bytes:byte(3)==2 and bytes:byte(17)==32 and bytes:byte(18)==0x28 and #bytes==18+w*h*4,
  'edge mask must be a complete, top-origin 32-bit RGBA TGA')
assert(bytes:byte(22)==0 and bytes:byte(22+w*4)==192 and bytes:byte(22+w*4*2)==255,
  'strip must fade from transparent edges to opaque ink')
local function distance(a,b)return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)end
local function heading(s)return math.atan(s.y2-s.y1,s.x2-s.x1)end
local function delta(a,b)return math.abs(math.atan(math.sin(a-b),math.cos(a-b)))end
local function check(points,width)
  local strokes=P.roundedTrack(points,width,'#abcdef','test')
  assert(#strokes<=#points+12*(#points-2),'curve subdivisions have a fixed per-corner budget')
  assert(strokes[1].x1==points[1].x and strokes[1].y1==points[1].y,'origin stays on its station')
  assert(strokes[#strokes].x2==points[#points].x and strokes[#strokes].y2==points[#points].y,
    'destination stays on its station')
  local seen,curves={},0
  for i,s in ipairs(strokes)do
    assert(not seen[s.key] and s.color=='#abcdef');seen[s.key]=true
    assert(distance({x=s.x1,y=s.y1},{x=s.x2,y=s.y2})>.00001,'no zero-length painted chord')
    if s.curve then curves=curves+1 end
    if i>1 then
      local prior=strokes[i-1]
      assert(distance({x=prior.x2,y=prior.y2},{x=s.x1,y=s.y1})<.00001,'no gap between fillet and rail')
      assert(delta(heading(prior),heading(s))<=math.rad(13),'rounded corners cannot retain a hard 30-degree kink')
    end
  end
  assert(curves>=4,'each horizontal/diagonal transition uses a real fillet, not just a round join cap')
  assert(math.abs(heading(strokes[1]))<.0001 and math.abs(heading(strokes[#strokes]))<.0001,
    'horizontal terminal leads are retained at both ends')
  return strokes
end
for _,width in ipairs({6,8,18})do
  for _,dy in ipairs({-120,120})do
    local points={{x=24,y=0},{x=100,y=0},{x=308,y=dy},{x=390,y=dy}}
    local strokes=check(points,width)
    local curves={}
    for _,s in ipairs(strokes)do if s.curve then curves[#curves+1]=s end end
    assert(curves[1].x1<100 and curves[1].y1==0,'bend starts smoothly before the old sharp corner')
    for _,s in ipairs(strokes)do
      assert(s.x1>=24 and s.x2<=390 and math.abs(s.y1)<=120 and math.abs(s.y2)<=120,
        'rounding stays inside the original corridor')
    end
  end
end
-- Small viewports, neighboring bends and cycle return lanes must not
-- produce negative straight lengths or retain unbounded vertex histories.
for _,points in ipairs({
  {{x=0,y=0},{x=2,y=0},{x=5,y=8},{x=7,y=8}},
  {{x=0,y=0},{x=20,y=0},{x=40,y=110},{x=150,y=110},{x=170,y=0},{x=190,y=0}},
})do
  local rails=P.roundedTrack(points,18,'#abcdef','narrow')
  assert(#rails<=#points+12*(#points-2))
  for i,s in ipairs(rails)do
    assert(s.x2>=s.x1 and s.x1==s.x1 and s.y1==s.y1,'finite, forward strokes after compression')
    if i>1 then assert(distance({x=rails[i-1].x2,y=rails[i-1].y2},{x=s.x1,y=s.y1})<.00001)end
  end
end
local straight=P.roundedTrack({{x=0,y=0},{x=0,y=0},{x=100,y=0},{x=200,y=0}},18,'#fff','straight')
assert(#straight==2 and not straight[1].curve,'straight services need no arc subdivision')
print('PASS: circular tangent fillets, exact station endpoints, bounded subdivisions and compressed/cycle corridors')
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local function line(id,ids,mode)
    local stops={}
    for i,station in ipairs(ids)do stops[i]={id=station,name='站 '..station,sourceIndex=i-1,transfers={}}end
    return {id=id,name='线路 '..id,mode=mode,color='#abcdef',stops=stops}
  end
  for _,mode in ipairs({'RER','METRO','TRAM'})do
    local a,b=line(10,{1,2,3,4},mode),line(20,{5,4},mode)
    for _,merged in ipairs({false,true})do
      snapshot={route={lineId=10,name=a.name,mode=mode,color=a.color,stops=a.stops},
        lines={a,b},next=2,passed=1,vehicle=200,network=merged and G.build({a,b}) or nil}
      aliases={};tick()
      local tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
      local canvas
      walk(tree,function(_,p)if p.meta and p.meta.id=='linnan.bulb.canvas'then canvas=p end end)
      local size=canvas.meta.styleSheet.size
      local plan=P.plan(snapshot,aliases,true,1232)
      local expected={}
      local function capKey(x,y,suffix)return string.format('%s:%.5f:%.5f',suffix,x,y)end
      for _,suffix in ipairs(plan.track.stripe>0 and {':rail',':stripe'} or {':rail'})do
        if merged then
          for _,s in ipairs(plan.rails)do
            expected[capKey(s.x1,s.y1,suffix)]=true;expected[capKey(s.x2,s.y2,suffix)]=true
          end
        else
          expected[capKey(plan.geometry.left,0,suffix)]=true;expected[capKey(plan.geometry.right,0,suffix)]=true
        end
      end
      local actual,railY,firstMarker={},nil,nil
      for i,c in ipairs(canvas.layout.param.children)do
        local p=c.param.item.param
        if p.meta.class=='bulb-station-marker'then railY=c.param.v*size[2];firstMarker=i;break end
      end
      local drawing={}
      for i,c in ipairs(canvas.layout.param.children)do
        local p=c.param.item.param
        if p.meta.class=='bulb-track-layer'then
          assert(i<firstMarker and c.param.localKey=='linnan.bulb.track-layer',
            'all new caps stay in the stable background before station markers')
          for _,r in ipairs(p.layout.param.children)do drawing[#drawing+1]=r end
        else drawing[#drawing+1]=c end
      end
      local caps=0
      for _,child in ipairs(drawing)do
        local pos=child.param;local p=pos.item.param
        if p.meta.class=='bulb-track-cap'then
          local key=capKey(pos.h*size[1],pos.v*size[2]-railY,pos.localKey:find(':stripe:',1,true) and ':stripe' or ':rail')
          assert(expected[key] and not actual[key],'each endpoint/join receives exactly one cap per ink layer')
          actual[key]=true;caps=caps+1
          assert(p.path:find('symbols/circle.tga',1,true),'caps use the shared antialiased round mask')
        end
      end
      for key in pairs(expected)do assert(actual[key],'horizontal endpoints must have round caps too: '..key)end
      if merged then
        assert(#plan.rails<=#plan.segments+24,'two-corner fork has a fixed small drawing budget')
        assert(caps<=2*#plan.rails*(plan.track.stripe>0 and 2 or 1),'shared vertices do not duplicate caps')
      else assert(caps==(plan.track.stripe>0 and 4 or 2))end
    end
  end
  print('PASS: native round terminal caps, unique arc join caps, shared assets and bounded fork node counts')
end
]=],'@test_track_caps.lua'))()
