-- Parse selectors with the installed build's real stylesheetutil.lua.
-- Component is a recipe-backed element (R::Component), as used by the
-- official builtin.css.lua; treating it as a native Component hid this bug.
local gui=assert(arg[1],'usage: lua tests/test_branch_connections.lua /path/to/game/gui/main')
-- TF3's own vec3/transform helpers use math.atan2. LuaJIT's math.atan
-- ignores the second argument, unlike the development Lua 5.4 interpreter.
-- Run the renderer with that behavior so an accidental two-argument atan
-- cannot turn a diagonal into a vertical overshooting rail again.
local atan,atan2=math.atan,math.atan2
_twoArgumentAtan=atan
math.atan=function(y)return atan(y)end
math.atan2=function(y,x)return atan(y,x)end
-- Execute the installed build's rotZ/scaleRotZTransl bodies, rather than
-- accepting a fabricated {angle=...} transform in the drawing assertions.
local matrixFile=assert(io.open(gui..'/../../scripts/mat4.tl'))
local matrixSource=matrixFile:read('*a');matrixFile:close()
local matrix={new=function(...)
  local result={};for _,column in ipairs({...})do
    for _,axis in ipairs({'x','y','z','w'})do result[#result+1]=column[axis]end
  end;return result
end}
for _,name in ipairs({'rotZ','scaleRotZTransl'})do
  local body=assert(matrixSource:match('mat4_util%.'..name..' = function.-\nend'))
  body=body:gsub(' : [%w%.]+','')
  assert(load(body,'@game-mat4-'..name,'t',{mat4_util=matrix,math=math,
    vec4={new=function(x,y,z,w)return {x=x,y=y,z=z,w=w}end}}))()
end
_nativeMat4=matrix
local split,strip,ends=string.split,string.strip,string.ends
function string.split(value,separator)
  local result,first={},1
  while true do
    local index=value:find(separator,first,true)
    if not index then result[#result+1]=value:sub(first);return result end
    result[#result+1]=value:sub(first,index-1);first=index+#separator
  end
end
function string.strip(value)return value:match('^%s*(.-)%s*$')end
function string.ends(value,suffix)return value:sub(-#suffix)==suffix end
local previous=require
require=function(path)
  if path=='/scripts/table_util.tl'then return {copy=function(t)
    local copy={};for k,v in pairs(t)do copy[k]=v end;return copy
  end}end
  return previous(path)
end
local parser=dofile(gui..'/stylesheetutil.lua')
require=previous
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
_branchSelectorParser=parser
assert(load(harness..[=[
do
  local parsed={};local add=_branchSelectorParser.makeAdder(parsed)
  for _,rule in ipairs(css)do add(rule.selector,rule.style)end
  local function applied(kind,meta)
    local element=kind=='Component' and 'R::Component' or kind
    local classes={}
    for class in (meta.class or ''):gmatch('[%w%-]+')do classes[class]=true end
    local result={}
    for _,rule in ipairs(parsed)do if #rule.levels==1 then
      local level=rule.levels[1];local match=not level.element or level.element==element
      if level.id and level.id~=meta.id then match=false end
      if #level.pseudoClassList>0 then match=false end
      for _,class in ipairs(level.classList)do if not classes[class]then match=false end end
      if match then for key,value in pairs(rule.styleSheet)do result[key]=value end end
    end end
    return result
  end
  local hidden=applied('Component',{class='bulb-layout-extent'})
  assert(hidden.visibility=='hidden','measurement extent must match the real R::Component element')
  for _,spec in ipairs({{'Component','bulb-glass'},{'Component','bulb-transfer-group'},
    {'TextView','bulb-omission-label'}})do
    local resolved=applied(spec[1],{class=spec[2]})
    assert(not resolved.backgroundImage1 and not resolved.backgroundColor1,
      'station names are the only HUD elements that receive a backing: '..spec[2])
  end
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local names={[1]='南充站',[2]='日照站',[3]='旅顺北站',[4]='杭州站',[5]='喀什东站'}
  local function service(id,ids,mode)
    local result={id=id,name='线路 '..id,mode=mode,color='#ffe077',stops={}}
    for i,station in ipairs(ids)do
      result.stops[i]={id=station,name=names[station],transfers={},sourceIndex=i-1}
      if station==1 or station==3 then
        result.stops[i].transfers={{id=100,name='电车 T1',mode='TRAM',color='#ee5a91'},
          {id=101,name='公交 1001',mode='BUS',color='#48b7bb'}}
      end
    end
    return result
  end
  local cases=0
  local function check(tree,plan,id)
    local canvas
    walk(tree,function(kind,p)
      local meta=p.meta or {};local style=meta.styleSheet or {}
      if kind=='Component' and meta.id==id then canvas=p end
      if meta.id=='linnan.bulb.identity' or meta.class=='bulb-transfer-group' then
        local resolved=applied(kind,meta)
        assert(not style.backgroundColor1 and (not style.backgroundColor or style.backgroundColor[4]==0)
          and not resolved.backgroundImage1,'identity and transfer groups must be transparent')
      end
    end)
    assert(canvas,'native diagram must be present')
    local size=canvas.meta.styleSheet.size
    local extent={0,0}
    for _,child in ipairs(canvas.layout.param.children)do
      local measured=child.param.item.param.meta.styleSheet.size
      for axis=1,2 do extent[axis]=math.max(extent[axis],measured[axis])end
    end
    assert(extent[1]==size[1] and extent[2]==size[2],'one shared, measured coordinate system')
    local expected={}
    for _,segment in ipairs(plan.segments)do expected[segment.key]=segment end
    local markers,diagonals,railY={},{},nil
    local strokes={}
    local drawing={}
    for _,child in ipairs(canvas.layout.param.children)do
      drawing[#drawing+1]=child
      if child.param.item.param.meta.class=='bulb-track-layer'then
        assert(child.param.h==0 and child.param.v==0,'track layer shares the station coordinate origin')
        for _,rail in ipairs(child.param.item.param.layout.param.children)do drawing[#drawing+1]=rail end
      end
    end
    for _,child in ipairs(drawing)do
      local pos=child.param;local node=pos.item;local p=node.param;local meta=p.meta or {}
      if meta.class=='bulb-station-marker'then
        markers[#markers+1]={x=pos.h*extent[1],y=pos.v*extent[2],name=meta.tooltip}
        for _,stop in ipairs(plan.stops)do if meta.tooltip==stop.fullName then railY=pos.v*extent[2]-stop.y end end
      end
      if meta.class and meta.class:find('bulb-branch-stroke',1,true)then
        local segment=assert(expected[pos.localKey:gsub(':rail$',''):gsub(':stripe$','')])
        local resolved=applied(node.kind,meta)
        local transform=assert(resolved.transform,'rotation must match the native element')
        local length=meta.styleSheet.size[1]
        local x,y=pos.h*extent[1],pos.v*extent[2]
        local dx,dy=length*transform[1],length*transform[2]
        assert(math.abs(dx-(segment.x2-segment.x1))<plan.track.rail/2 and
          math.abs(dy-(segment.y2-segment.y1))<plan.track.rail/2,
          'painted branch must reach its actual endpoint after native selector matching: '..pos.localKey)
        if segment.y1~=segment.y2 then
          assert(resolved.transform and resolved.transformOrigin[1]==0 and resolved.transformOrigin[2]==.5,
            'a diagonal requires an applicable rotation, not just a declared CSS rule')
          diagonals[#diagonals+1]=segment
        end
        strokes[#strokes+1]={segment=segment,x=x,y=y}
      end
    end
    assert(#markers==#plan.stops and #diagonals>0 and #strokes==#plan.segments*(plan.track.stripe>0 and 2 or 1))
    local hangzhou=0
    for _,marker in ipairs(markers)do
      if marker.name=='杭州站'then hangzhou=hangzhou+1 end
      for _,stop in ipairs(plan.stops)do if stop.fullName==marker.name then
        assert(math.abs(marker.x-stop.x)<.001 and math.abs(marker.y-railY-stop.y)<.001)
      end end
    end
    assert(hangzhou==1,'杭州 is one shared junction, not two disconnected stations')
    for _,stroke in ipairs(strokes)do
      assert(math.abs(stroke.x-stroke.segment.x1)<.001 and math.abs(stroke.y-railY-stroke.segment.y1)<.001,
        'painted rail and station centers must share coordinates')
    end
    -- Follow the painted rail graph from either origin to the single 杭州.
    local adjacency={}
    local function key(x,y)return string.format('%.4f:%.4f',x,y)end
    for _,segment in ipairs(plan.segments)do
      local a,b=key(segment.x1,segment.y1),key(segment.x2,segment.y2)
      adjacency[a]=adjacency[a] or {};adjacency[b]=adjacency[b] or {}
      adjacency[a][b]=true;adjacency[b][a]=true
    end
    local byId={};for _,stop in ipairs(plan.stops)do byId[stop.id]=stop end
    local seen={};local function visit(k)
      if seen[k]then return end;seen[k]=true
      for nextKey in pairs(adjacency[k] or {})do visit(nextKey)end
    end
    visit(key(byId[4].x,byId[4].y))
    for _,stop in pairs(byId)do assert(seen[key(stop.x,stop.y)],'every branch must visibly connect to 杭州')end
    assert((byId[1].x-byId[4].x)*(byId[5].x-byId[4].x)>0,'both origins stay on the same side of 杭州')
    assert(byId[1].endpoint and byId[4].endpoint and byId[5].endpoint)
    for _,id in ipairs({2,3})do if byId[id]then assert(not byId[id].endpoint)end end
    cases=cases+1
  end
  for _,useAtan2 in ipairs({true,false})do
  math.atan2=useAtan2 and function(y,x)return _twoArgumentAtan(y,x)end or nil
  for _,mode in ipairs({'RER','METRO','TRAM'})do
    local a,b=service(10,{1,2,3,4},mode),service(20,{5,4},mode)
    local services={a,b};local graph=assert(G.build(services))
    aliases={};for _,line in ipairs(services)do aliases[tostring(line.id)]={name=line.name,identifier='A'}end
    for _,main in ipairs(services)do for _,reverse in ipairs({false,true})do
      local stops={};for i=1,#main.stops do stops[i]=main.stops[reverse and #main.stops-i+1 or i]end
      snapshot={route={lineId=main.id,name=main.name,mode=mode,color=main.color,stops=stops},network=graph,
        lines=services,next=2,passed=1,vehicle=200}
      for _,width in ipairs({320,1280})do
        local viewport={x=width,y=720}
        tick()
        local tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport=viewport})
        local plan=P.plan(snapshot,aliases,true,math.max(240,math.min(width-48,1600)))
        check(tree,plan,'linnan.bulb.canvas')
      end
      contexts.LinnanBulbStaticRouteNative={}
      collect.readLine=function()return snapshot end
      local param={lineId=main.id,lines=services,aliases=aliasState,viewport={x=1280,y=720},
        geometry=S.geometry({x=1280,y=720}),color=function()return {1,.88,.47,1}end,
        home=function()end,navigate=function()end,onReady=function()end}
      render('LinnanBulbStaticRouteNative',param);mounts.LinnanBulbStaticRouteNative();join()
      local tree=render('LinnanBulbStaticRouteNative',param)
      check(tree,P.plan(snapshot,aliases,false,1356),'linnan.bulb.static-canvas')
      unmounts.LinnanBulbStaticRouteNative()
    end end
  end
  end
  print('PASS: '..cases..' native fork drawings, single-argument atan / atan2 fallback, actual game matrices and selectors, transparent identity/transfers, shared 杭州')
end
]=],'@test_branch_connections.lua'))()
_branchSelectorParser=nil
_nativeMat4=nil
math.atan,math.atan2=atan,atan2
_twoArgumentAtan=nil
string.split,string.strip,string.ends=split,strip,ends
