local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local name='LinnanBulbStaticRouteNative'
  local roster={{id=10,name='Metro 1',mode='METRO'},{id=20,name='RER A',mode='TRAIN'},
    {id=30,name='Tram 1',mode='TRAM'},{id=40,name='Bus 1001',mode='BUS'}}
  local loaded,closed,checks,components,followed,popped=0,0,0,0,{},0
  local exists,hasLine,fail=true,true,false
  local activeTool
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  api.type=api.type or {};api.type.ComponentType={LINE='line'}
  api.engine={entityExists=function(id)
    assert(id>=10 and id<=40);checks=checks+1;return exists
  end,getComponent=function(id,kind)
    assert(kind=='line');components=components+1;return hasLine and {} or nil
  end}
  api.gui.camera.followEntity=function(id,animate)
    assert(not activeTool,'leave cockpit before moving the map camera')
    assert(animate==true);if fail then error('camera unavailable')end
    followed[#followed+1]=id
  end
  modules['game_react_globals.tl'].getDefaultToolStackApi=function()
    return {getActiveTool=function()return activeTool end,pop=function(tool,key)
      assert(tool==activeTool and tool.name=='FreeCam' and key==nil)
      activeTool=nil;popped=popped+1
    end}
  end
  collect.readLine=function(id)
    loaded=loaded+1
    local line=roster[id/10]
    local snapshot={static=true,next=0,passed=0,lines=roster,
      route={lineId=id,name=line.name,mode=line.mode,color='#006db8',stops={
        {id=1,name='起点',transfers={}},{id=2,name='终点',transfers={}}}}}
    if id==20 then
      snapshot.network=assert(G.build({{id=50,name='同号成员',mode='TRAIN',color='#006db8',stops={
        {id=1,name='起点',transfers={}},{id=3,name='另一终点',transfers={}}}},
        {id=id,name=line.name,mode=line.mode,color='#006db8',stops=snapshot.route.stops}}))
    end
    return snapshot
  end
  local param={aliases=aliasState,lines=roster,geometry=S.geometry({x=320,y=300}),viewport={x=320,y=300},
    color=function()return {.1,.4,.8,1}end,onReady=function()end,home=function()unmounts[name]()end,
    navigate=function()end,onClose=function()closed=closed+1 end}
  local function control(tree,id)
    local found;walk(tree,function(_,p)if p.meta and p.meta.id==id then found=p end end)
    return assert(found,'missing '..id)
  end
  local function draw()return render(name,param)end
  local function open(id)
    contexts[name]={};param.lineId=id
    local initial=draw();local pin=control(initial,'linnan.bulb.browser.locate')
    assert(pin.meta.enabled==false,'disable locating until the selected route has loaded')
    pin.onClick();mounts[name]();join()
    return draw()
  end
  for _,line in ipairs(roster)do
    local before=checks
    local tree=open(line.id)
    local pin=control(tree,'linnan.bulb.browser.locate')
    assert(pin.meta.enabled and checks==before,'render must never query the engine for locating')
    assert(pin.content.param.path=='::/gui/line_vehicle_mgmt/icons/symbol_locate_20.tga')
    assert(pin.meta.styleSheet.size[1]==24 and pin.meta.styleSheet.size[2]==24)
    draw();assert(checks==before and not timers[name],'no locating timer or repeated route reads')
    activeTool={name='FreeCam'}
    pin.onClick()
    assert(followed[#followed]==line.id,'locate the selected REAL service, including merged services')
    assert(checks==before+1 and contexts[name][1]:get().snapshot==nil,
      'check only the selected line on click and immediately release its snapshot')
    pin.onClick();assert(checks==before+1,'ignore stale/repeated clicks after closing')
  end
  assert(closed==4 and popped==4 and components==4 and loaded==4)
  -- Returning to the directory invalidates the old button immediately.
  local tree=open(10);local stale=control(tree,'linnan.bulb.browser.locate')
  control(tree,'linnan.bulb.browser.back').onClick()
  local before=checks;stale.onClick();assert(checks==before and closed==4)
  -- A deleted line (or an ID now belonging to another entity type) stays on
  -- the page with an explanation rather than passing invalid data to C++.
  tree=open(10);exists=false
  control(tree,'linnan.bulb.browser.locate').onClick()
  assert(closed==4 and #followed==4 and contexts[name][1]:get().snapshot)
  assert(control(draw(),'linnan.bulb.browser.locate-error').text:find('已删除',1,true))
  exists=true;hasLine=false
  control(draw(),'linnan.bulb.browser.locate').onClick();assert(#followed==4)
  hasLine=true;fail=true;warnings={}
  control(draw(),'linnan.bulb.browser.locate').onClick()
  assert(closed==4 and #warnings==1)
  assert(control(draw(),'linnan.bulb.browser.locate-error').text:find('定位失败',1,true))
  fail=false;control(draw(),'linnan.bulb.browser.locate').onClick()
  assert(closed==5 and #followed==5,'failed locating can be retried')
end
print('PASS: official line pin, all modes, actual merged member ID, click-only queries, cockpit exit, release and stale/deleted/error guards')
]=],'@test_line_locate.lua'))()
