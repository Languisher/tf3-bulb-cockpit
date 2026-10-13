-- Use the real collector inside the native HUD harness, including asynchronous
-- label confirmation and viewport work sharing the vehicle join.
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  free.FreeCamTool.pop();unmounts.LinnanBulbCockpitHudNative()
  local gui,requireModule=api.gui,ug_require
  local f=dofile('tests/performance_fixture.lua')('mod/content/gui/bulb_cockpit/',300,32,9)
  f.components[200]=f.components[f.vehicle];f.vehicle=200
  api.gui=gui;ug_require=requireModule;collect.read=f.collect.read
  local stored,revision,configurationReads,commands={},100,0,0
  modules['aliases.lua'].read=function(previous)
    configurationReads=configurationReads+1
    if previous==revision then return nil,revision end
    return stored,revision
  end
  modules['aliases.lua'].saveDefaults=function(defaults,callback)
    if not next(defaults)then return end
    commands=commands+1
    local merged={};for id,value in pairs(stored.__defaults or {})do merged[id]=value end
    for id,value in pairs(defaults)do merged[id]=value end
    stored={__defaults=merged};revision=revision+1
    callback(nil,true)
  end
  local root=render('LinnanBulbFreeCamNative',mounted.param);findHud(root)
  contexts.LinnanBulbCockpitHudNative={}
  render('LinnanBulbCockpitHudNative',hudParam)
  mounts.LinnanBulbCockpitHudNative();join()
  free.FreeCamTool.push({}, {cockpitCameraForEntity=200});join();join()
  render('LinnanBulbCockpitHudNative',hudParam);tick();join()
  assert(commands==1 and configurationReads==2,'load configuration on entry and once after confirmed label persistence')
  local function writes(name)
    local total=0;for _,item in ipairs(contexts[name])do total=total+(item.writes or 0)end
    return total
  end
  local rootWrites,hudWrites=writes('LinnanBulbFreeCamNative'),writes('LinnanBulbCockpitHudNative')
  local old=contexts.LinnanBulbCockpitHudNative[1]:old()
  local function futureLamps()
    local current=contexts.LinnanBulbCockpitHudNative[1]:old()
    local expected={}
    for i=current.next,#current.route.stops do expected[current.route.stops[i].name]=true end
    local lamps=0
    walk(render('LinnanBulbCockpitHudNative',hudParam),function(kind,p)
      if kind=='Component' and p.meta.class=='bulb-station-marker'then
        local lit=false
        walk(p,function(k,image)
          if k=='ImageView' and image.meta.class=='bulb-station-light'then lit=true end
        end)
        assert(lit==(expected[p.meta.tooltip]==true),'future stations stay yellow; arrived and skipped lamps turn off')
        if lit then lamps=lamps+1 end
      end
    end)
    assert(lamps>=1,'the steady-mode HUD lights the next and visible future stops')
  end
  futureLamps()
  f.reset();configurationReads=0
  for i=1,100 do tick()end
  assert(f.calls.component==100 and f.calls.TRANSPORT_VEHICLE==100)
  assert(not f.calls.transfers and not f.calls.fleet and not f.calls.town and not f.calls.roster)
  assert(configurationReads==0 and commands==1,'ride timers cannot poll configuration or persist unchanged labels')
  assert(writes('LinnanBulbFreeCamNative')==rootWrites and writes('LinnanBulbCockpitHudNative')==hudWrites,
    'neither root nor HUD can write any state/ref during unchanged progress')
  local state=contexts.LinnanBulbCockpitHudNative[1];local before=state.writes
  local tv=f.components[200].TRANSPORT_VEHICLE
  tv.state='AT_TERMINAL';f.reset();tick()
  local arrived=state:old()
  assert(arrived~=old and state.writes==before+1 and arrived.passed==old.passed+1)
  assert(f.calls.component==1 and not f.calls.transfers and configurationReads==0)
  futureLamps()
  tv.stopIndex=tv.stopIndex+1;tv.state='EN_ROUTE';f.reset();tick()
  assert(state:old()==arrived and state.writes==before+1 and f.calls.component==1,
    'the real HUD updates once on arrival and not again on departure')
  assert(commands==1 and configurationReads==0)
  tv.stopIndex=tv.stopIndex+2;f.reset();tick();futureLamps()
  assert(state:old().next==arrived.next+2,'skip intermediate targets without lighting them')
  assert(f.calls.component==1 and not f.calls.transfers and configurationReads==0,
    'skipped stops still need only the followed vehicle state')
  free.FreeCamTool.pop();f.reset()
  for i=1,10 do tick()end
  assert(not f.calls.component and configurationReads==0 and not hudVisible,'exit stops all game-data polling immediately')
  print('PASS: real collector + HUD, confirmation-driven labels, vehicle-only idle, zero root/HUD writes, one arrival update, departure reuse and exit')
end
]=],'@arrival_hud'))()
