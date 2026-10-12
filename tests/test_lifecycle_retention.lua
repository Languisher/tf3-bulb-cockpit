-- Exercise the real installer with the native GUI harness. Deliberately do
-- not step/render the hidden HUD after exit: the visible parent must remove
-- that subtree, regardless of whether hidden child state is reconciled.
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  free.FreeCamTool.pop();join()
  local function containsHud(node)
    if type(node)~='table'then return false end
    if node.recipe=='LinnanBulbCockpitHudNative'then return true end
    for _,v in pairs(node)do if type(v)=='table' and containsHud(v)then return true end end
    return false
  end
  local root=render('LinnanBulbFreeCamNative',mounted.param)
  local idleQueries,oldGetSize=0,api.gui.byId.getSize
  api.gui.byId.getSize=function(...)idleQueries=idleQueries+1;return oldGetSize(...)end
  assert(not timers.LinnanBulbFreeCamNative,'ordinary play cannot register an empty root timer')
  for i=1,2000 do join()end
  api.gui.byId.getSize=oldGetSize
  print('idle: retained HUD='..tostring(containsHud(root))..'; GUI size queries='..idleQueries)
  assert(not containsHud(root),'exit must unmount the entire HUD in the visible parent, not only hide its component')
  assert(idleQueries==0,'normal camera must perform zero viewport queries after initial calibration')
  -- Opening settings still measures current GUI units on demand, even when
  -- the window was resized during normal play. Closing cancels a queued open.
  local function findSettings(node)
    if type(node)~='table'then return end
    if node.recipe=='LinnanBulbSettingsNative'then return node.param end
    for _,v in pairs(node)do local found=findSettings(v);if found then return found end end
  end
  contexts.LinnanBulbSettingsNative={}
  local settingsParam=findSettings(render('LinnanBulbMainButtonNative',{}))
  assert(settingsParam and not settingsParam.meta.class,'settings entry is visible outside first person')
  local function gear()
    local result
    walk(render('LinnanBulbSettingsNative',settingsParam),function(k,p)if k=='ToggleButton'then result=p end end)
    return result
  end
  gear().onValueChange(1);gear().onValueChange(0);join()
  assert(windowParam==nil,'closing before the sizing join must cancel a queued settings open')
  guiWidth,guiHeight=900,700
  gear().onValueChange(1);join()
  assert(windowParam.viewport.x==900 and windowParam.viewport.y==700,'size settings from the actual current viewport')
  gear().onValueChange(0)
  -- A blocked main-thread join must coalesce timer ticks. Once the session
  -- exits, its queued work must not read a vehicle or reveal stale pixels.
  unmounts.LinnanBulbCockpitHudNative()
  -- Production writes logs to the engine; the harness's accumulating log
  -- array is a test recorder, not a mod-owned cache.
  log.verbose=function()end
  local collections=0
  collect.read=function(vehicle,_,_,cache)
    assert(vehicle==200 and phase=='join');collections=collections+1
    local result={vehicle=vehicle,next=2,passed=1,route={lineId=1,name='生命周期测试',mode='TRAM',
      color='#006db8',stops={{name='起点',transfers={}},{name='终点',transfers={}}}}}
    cache.snapshot=result
    return result
  end
  local weak=setmetatable({},{__mode='v'})
  local function dropHud()
    unmounts.LinnanBulbCockpitHudNative()
    for _,state in ipairs(contexts.LinnanBulbCockpitHudNative)do state.expired=true end
    contexts.LinnanBulbCockpitHudNative=nil
    mounts.LinnanBulbCockpitHudNative=nil;unmounts.LinnanBulbCockpitHudNative=nil
    timers.LinnanBulbCockpitHudNative=nil;timers.LinnanBulbFlashingStationNative=nil
  end
  local function cycle(i)
    free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
    local tree=render('LinnanBulbFreeCamNative',mounted.param);hudParam=nil;findHud(tree)
    assert(hudParam and hudParam.meta.localKey)
    assert(not findSettings(tree),'camera tree never owns a duplicate toolbar entry')
    contexts.LinnanBulbCockpitHudNative={}
    render('LinnanBulbCockpitHudNative',hudParam)
    mounts.LinnanBulbCockpitHudNative()
    if i==1 then
      for j=1,500 do timers.LinnanBulbCockpitHudNative()end
      assert(#joins==2,'500 delayed ticks must retain only one route join and one bounds join')
    end
    join()
    local states=contexts.LinnanBulbCockpitHudNative
    local drawn=render('LinnanBulbCockpitHudNative',hudParam)
    weak[i]=states[1]:old()
    local staleTimer=timers.LinnanBulbCockpitHudNative
    staleTimer() -- read queued just before exit
    local before=collections
    free.FreeCamTool.pop()
    local empty=render('LinnanBulbFreeCamNative',mounted.param)
    assert(not containsHud(empty),'exit must remove HUD even if the child never rerenders')
    assert(findSettings(render('LinnanBulbMainButtonNative',{})),'independent toolbar entry survives cockpit exit')
    dropHud();join();staleTimer();join()
    assert(collections==before and not hudVisible,'old joins/timers must be inert after disposal')
    hudParam=nil
  end
  cycle(1);collectgarbage('collect')
  local before=collectgarbage('count')
  for i=2,1001 do cycle(i)end
  collectgarbage('collect');collectgarbage('collect')
  local after=collectgarbage('count')
  local retained=0;for _ in pairs(weak)do retained=retained+1 end
  print(string.format('retention: routes=%d; heap delta=%.1f KiB',retained,after-before))
  assert(retained==0,'all old route snapshots must be collectible after exit')
  assert(after-before<64,'Lua retained heap must stay bounded over 1,000 repeated cockpit sessions')
  local oldSize=api.gui.byId.getSize
  local queries=0
  api.gui.byId.getSize=function(...)queries=queries+1;return oldSize(...)end
  assert(not timers.LinnanBulbFreeCamNative,'ordinary play cannot register an empty root timer')
  for i=1,2000 do join()end
  assert(queries==0 and #joins==0)
  api.gui.byId.getSize=oldSize
  print(string.format('PASS: 1,001 sessions; retained routes=%d; heap delta=%.1f KiB; idle queries=%d; delayed 500 ticks -> 2 jobs',
    retained,after-before,queries))
  unmounts.LinnanBulbFreeCamNative()
  for _,state in ipairs(contexts.LinnanBulbFreeCamNative)do state.expired=true end
  free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
  for i=1,500 do join()end
  assert(#joins==0,'disposed parent must release camera subscriptions and make deferred timers inert')
  free.FreeCamTool.pop()
end
]=],'@lifecycle_retention'))()
