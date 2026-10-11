local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  warnings={}
  local browserName,staticName='LinnanBulbBrowserNative','LinnanBulbStaticRouteNative'
  contexts[browserName]={};contexts[staticName]={}
  aliases={__options={flashNextStop=true}}
  local roster={{id=10,name='Metro 1',mode='METRO',color='#006db8'},
    {id=20,name='Tram 2',mode='TRAM',color='#e0b332'},
    {id=30,name='Bus 1001',mode='BUS',color='#ba4c99'}}
  aliases['10']={name=roster[1].name,identifier='1',prefix='',suffix=''}
  aliases['20']={name=roster[2].name,identifier='2',prefix='T',suffix=''}
  aliases['30']={name=roster[3].name,identifier='1001',prefix='',suffix=''}
  local loaded,closed=0,0
  local weak=setmetatable({},{__mode='v'})
  collect.readLine=function(id,withCities,links,config)
    assert(phase=='join','static engine reads must run on the main thread')
    loaded=loaded+1;assert(not withCities and config.__options==aliases.__options)
    if id==999 then return nil end
    local line=roster[id==10 and 1 or id==20 and 2 or 3]
    local map={static=true,next=0,passed=0,lines=roster,
      route={lineId=id,name=line.name,mode=line.mode,color=line.color,stops={}}}
    for i=1,24 do map.route.stops[i]={id=i,name='站 '..i,transfers=i==2 and {roster[2],roster[3]} or {}}end
    weak[loaded]=map;return map
  end
  local param={aliases=aliasState,lines=roster,geometry=S.geometry({x=1280,y=720}),viewport={x=1280,y=720},
    color=function()return {.1,.4,.8,1}end,onClose=function()closed=closed+1 end}
  local function controls(tree)
    local found={};walk(tree,function(kind,p)if p.meta and p.meta.id then found[p.meta.id]=p end end)
    return found
  end
  local function child(tree)
    local found
    walk(tree,function()end)
    local function visit(v)
      if type(v)~='table'then return end
      if v.recipe==staticName then found=v end
      for _,sub in pairs(v)do if type(sub)=='table'then visit(sub)end end
    end
    visit(tree);return found
  end
  local home=render(browserName,param);local c=controls(home)
  assert(c['linnan.bulb.browser.configure'].content.param.text=='线路','short native line-editor entry')
  assert(c['linnan.bulb.settings.city'].content.param.text=='公交线路编号一键配置',
    'bus configuration is a direct button on the directory home')
  assert(c['linnan.bulb.settings.flash'].value==1,'home reflects the saved flash option')
  assert(c['linnan.bulb.browser.line.10'] and c['linnan.bulb.browser.line.20'])
  assert(not c['linnan.bulb.browser.line.30'] and loaded==0,'directory is metadata only, bus empty')
  c['linnan.bulb.browser.bus-search'].onTyping('1001')
  home=render(browserName,param);c=controls(home);assert(c['linnan.bulb.browser.line.30'])
  c['linnan.bulb.browser.line.10'].onClick()
  local selected=assert(child(render(browserName,param)))
  local diagram=render(staticName,selected.param)
  mounts[staticName]();join();diagram=render(staticName,selected.param)
  assert(loaded==1 and not timers[staticName],'static map loads exactly once without timer')
  local markers,transfers=0,{}
  walk(diagram,function(kind,p)
    if kind=='Component' and p.meta.class=='bulb-station-marker'then markers=markers+1 end
    if kind=='Button' and p.meta.class=='bulb-transfer-link'then transfers[#transfers+1]=p end
  end)
  assert(markers==24,'static map scrolls the FULL line, never HUD pagination')
  assert(#transfers==2,'all real transfer badges are clickable')
  assert(controls(diagram)['linnan.bulb.browser.map'].horizontalPolicy=='needed')
  render(staticName,selected.param);assert(loaded==1,'UI redraw never reloads topology')
  transfers[1].onClick()
  assert(contexts[staticName][1]:get().snapshot==nil,'jump immediately drops previous snapshot')
  unmounts[staticName]();contexts[staticName]={}
  selected=assert(child(render(browserName,param)));assert(selected.param.lineId==20)
  diagram=render(staticName,selected.param);mounts[staticName]();join();diagram=render(staticName,selected.param);assert(loaded==2)
  controls(diagram)['linnan.bulb.browser.back'].onClick()
  assert(contexts[staticName][1]:get().snapshot==nil,'back releases snapshot before rendering directory')
  unmounts[staticName]();contexts[staticName]={}
  home=render(browserName,param);assert(not child(home))
  controls(home)['linnan.bulb.browser.configure'].onClick()
  local config=render(browserName,param);assert(controls(config)['linnan.bulb.browser.back'])
  local editor=controls(render('LinnanBulbSettingsContentNative',param))
  assert(not editor['linnan.bulb.settings.city'] and not editor['linnan.bulb.settings.flash'],
    'line editor does not duplicate the home controls')
  assert(editor['linnan.bulb.settings.apply-all'] and editor['linnan.bulb.settings.search'],
    'line editing and apply-all remain available')
  controls(config)['linnan.bulb.browser.back'].onClick()
  assert(controls(render(browserName,param))['linnan.bulb.browser.bus-search'].value=='1001','bus search preserved on back')
  -- Drop old native trees/callbacks, as a real unmounted subtree does.
  home,c,selected,diagram,transfers,config=nil,nil,nil,nil,nil,nil
  collectgarbage('collect');collectgarbage('collect')
  assert(next(weak)==nil,'no visited snapshot survives back navigation')
  for i=1,301 do
    home=render(browserName,param)
    controls(home)['linnan.bulb.browser.line.10'].onClick()
    selected=child(render(browserName,param))
    diagram=render(staticName,selected.param)
    mounts[staticName]();join();diagram=render(staticName,selected.param)
    controls(diagram)['linnan.bulb.browser.back'].onClick()
    unmounts[staticName]();contexts[staticName]={}
  end
  home,selected,diagram=nil,nil,nil
  collectgarbage('collect');collectgarbage('collect')
  assert(next(weak)==nil,'301 visits retain zero static snapshots')
  assert(not timers[browserName] and not timers[staticName],'no background directory/map timers')
  controls(render(browserName,param))['linnan.bulb.browser.line.10'].onClick()
  selected=child(render(browserName,param));diagram=render(staticName,selected.param)
  mounts[staticName]();join();diagram=render(staticName,selected.param)
  unmounts[browserName]()
  assert(contexts[staticName][1]:get().snapshot==nil,'closing window releases child graph too')
  contexts[staticName]={};selected.param.lineId=999
  diagram=render(staticName,selected.param)
  mounts[staticName]();join();diagram=render(staticName,selected.param)
  assert(not controls(diagram)['linnan.bulb.browser.map'],'deleted line remains a valid error layout')
  -- Closing before the queued load cancels all work, even if the join later
  -- executes while its old Lua callback is still alive.
  contexts[staticName]={};selected.param.lineId=10
  diagram=render(staticName,selected.param);mounts[staticName]()
  local before=loaded
  unmounts[staticName]();join()
  assert(loaded==before,'cancelled static visit must not query the engine')
  -- First-ever settings open: defaults may still be awaiting persistence.
  -- Loading only the second rail service must keep its directory badge B.
  contexts[browserName]={};contexts[staticName]={};aliases={}
  param.lines={{id=10,name='铁路甲',mode='TRAIN',color='#006db8'},
    {id=20,name='铁路乙',mode='TRAIN',color='#006db8'}}
  collect.readLine=function(id,_,_,effective)
    local line=param.lines[2];assert(id==20)
    assert(P.alias(line,effective,P.defaults({line},effective))=='B','scoped static load must retain full-directory defaults')
    return {static=true,next=0,passed=0,lines={line},route={lineId=id,name=line.name,mode='TRAIN',color=line.color,
      stops={{id=1,name='起点',transfers={}},{id=2,name='终点',transfers={}}}}}
  end
  controls(render(browserName,param))['linnan.bulb.browser.line.20'].onClick()
  selected=child(render(browserName,param));render(staticName,selected.param);mounts[staticName]();join()
  diagram=render(staticName,selected.param)
  assert(controls(diagram)['linnan.bulb.browser.map'],'first visit draws successfully before defaults acknowledgment')
  assert(aliases.__defaults==nil,'temporary display numbering never mutates persistent root config')
  unmounts[staticName]();unmounts[browserName]()
  assert(#warnings==0,table.concat(warnings,'\n'))
end
print('PASS: native directory, search, complete static map, clickable transfers, back/close release and 301-visit retention')
]=],'@test_browser_hud.lua'))()
