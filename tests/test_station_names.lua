local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local function check(value,width,expected)
  local text,rows,actualWidth=P.stationLabel(value,width,14,B.textWidth)
  assert(text==expected,value..': '..text)
  assert(rows<=2 and actualWidth<=width)
  for line in text:gmatch('[^\n]+')do assert(B.textWidth(line,14)+4<=width+.001)end
end
check('New York Central',80,'New York\nCentral')
check('Charles de Gaulle',100,'Charles de\nGaulle')
check("King's Cross",90,"King's Cross")
check('Baden-Baden Hauptbahnhof',128,'Baden-Baden\nHauptbahnhof')
check('  North\t  Park  ',64,'North\nPark')
check('杭州火车站',46,'杭州火\n车站')
check('杭州 Central',80,'杭州\nCentral')
local long,rows,w=P.stationLabel('Supercalifragilisticexpialidocious',80,14,B.textWidth)
assert(rows==1 and long:sub(-3)=='…' and not long:find('\n') and w<=80,'oversize words elide on one line')
check('New York Central Station West',80,'New York\nCentral…')
check('École du Nord',100,'École du\nNord')
local existing,existingRows,existingWidth=P.stationLabel('Supercalifragilisticexpialidocious…',80,14,B.textWidth)
assert(existingRows==1 and existingWidth<=80 and not existing:find('……',1,true))
-- Real linear and branched plans use the same formatter and retain the full tooltip.
local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
local function service(id,ids)
 local stops={}
 for i,n in ipairs(ids)do stops[i]={id=n,name=n==1 and 'Charles de Gaulle' or 'New York Central',sourceIndex=i-1,transfers={}}end
 return {id=id,name='Line '..id,mode='METRO',color='#123456',stops=stops}
end
local a,b=service(10,{1,2,3}),service(20,{4,2,3})
for _,width in ipairs({272,640,1280})do
 for _,branch in ipairs({false,true})do
  local snapshot={route={lineId=a.id,name=a.name,mode=a.mode,color=a.color,stops=a.stops},lines={a,b},next=2,passed=1,
    network=branch and assert(G.build({a,b})) or nil}
  local plan=P.plan(snapshot,{},false,width,nil,B.textWidth)
  assert(plan.geometry.width<=width)
  for _,stop in ipairs(plan.stops)do
   assert(stop.nameRows<=2 and (stop.fullName=='Charles de Gaulle' or stop.fullName=='New York Central'))
   for word in stop.name:gmatch('[%a]+')do
    assert(stop.fullName:find(word,1,true))
   end
   for line in stop.name:gmatch('[^\n]+')do assert(B.textWidth(line,14)+4<=stop.nameWidth+.001)end
   assert(not stop.name:find('Charle\ns') and not stop.name:find('Cen\ntral'))
  end
 end
end
print('PASS: whole English/Latin words, apostrophes, compounds, CJK, whitespace, two-row ellipsis, tooltip and route/branch bounds')
local f=assert(io.open('tests/test_native.lua'));local harness=f:read('*a');f:close()
assert(load(harness..[=[
do
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local titles={'Charles de Gaulle','New York Central Station West',"King's Cross",'Baden-Baden Hauptbahnhof'}
  local function service(id,ids)
    local stops={}
    for i,n in ipairs(ids)do stops[i]={id=n,name=titles[n],sourceIndex=i-1,transfers={}}end
    return {id=id,name='Line '..id,mode='METRO',color='#123456',stops=stops}
  end
  local a,b=service(800,{1,2,3}),service(801,{4,2,3})
  aliases={__options={language='en',flashNextStop=false}}
  collect.read=function()return snapshot end
  local function check(tree,plan)
    local found=0
    walk(tree,function(kind,p)
      local class=p.meta and p.meta.class
      if kind=='TextView' and (class=='bulb-station-name' or class=='bulb-station-terminus-name')then
        found=found+1;local stop=plan.stops[found]
        assert(p.text==stop.name and p.meta.tooltip==stop.fullName,'renderer must use the word-aware plan and retain the original name')
      end
    end)
    assert(found==#plan.stops)
  end
  for _,branch in ipairs({false,true})do
    snapshot={vehicle=200,next=2,passed=1,lines={a,b},network=branch and assert(G.build({a,b})) or nil,
      route={lineId=a.id,name=a.name,mode=a.mode,color=a.color,stops=a.stops}}
    for _,percent in ipairs({10,100,137,400})do
      aliases.__options.routeMapScale=percent;tick()
      local width=math.max(240,math.min(1600,(1280-48)/(percent/100)))
      check(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}}),
        P.plan(snapshot,aliases,false,width,nil,B.textWidth))
    end
    local static={static=true,next=0,passed=0,route=snapshot.route,lines=snapshot.lines,network=snapshot.network}
    collect.readLine=function()return static end
    local name='LinnanBulbStaticRouteNative';contexts[name]={}
    local param={lineId=800,aliases=aliasState,lines={a,b},viewport={x=1280,y=720},geometry=S.geometry({x=1280,y=720}),
      color=settingsParam.color,navigate=function()end,home=function()end,onClose=function()end,onReady=function()end}
    render(name,param);mounts[name]();join()
    local count=static.network and #static.network.nodes or #static.route.stops
    check(render(name,param),P.plan(static,aliases,false,math.max(800,count*220+256),nil,B.textWidth))
    unmounts[name]()
  end
  print('PASS: actual HUD/static text and complete tooltips across straight/branched routes and four zoom levels')
end
]=],'@station_names_render'))()
