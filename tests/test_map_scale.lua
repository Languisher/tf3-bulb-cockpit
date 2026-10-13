local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
assert(P.mapScale({})==100,'default route-map scale is 100%')
for value=10,400 do assert(P.mapScale({__options={routeMapScale=value}})==value)end
for _,value in ipairs({0,9,401,1.5,'150',false,math.huge})do
  assert(P.mapScale({__options={routeMapScale=value}})==100,'invalid saved values fall back to the default')
end
print('PASS: 10–400% integer scale range and invalid preference fallback')
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local script=env.data();local saved={options={language='fr',flashNextStop=true},lines={}}
local writes=0;local state={get=function()return saved end,set=function(_,v)saved=v;writes=writes+1 end}
api={type={ComponentType={GAME_SCRIPT=1}},engine={system={gameScriptSystem={getEntityForGameScript=function()return 1 end}},
  getComponent=function()return {state=saved}end},cmd={makeScriptingSendEventCmd=function(_,id,name,param)return {id=id,name=name,param=param}end,
  sendCommand=function(cmd,callback)script.handleEvent({},state,'',cmd.id,cmd.name,cmd.param);callback(nil,true)end}}
local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
for _,value in ipairs({10,137,400})do
  A.saveOptions({routeMapScale=value},function(_,ok)assert(ok)end)
  assert(P.mapScale(A.read())==value and saved.options.language=='fr' and saved.options.flashNextStop)
end
local count=writes;A.saveOptions({routeMapScale=400},function()end);assert(writes==count)
for _,value in ipairs({9,401,1.5,'100',false,math.huge})do
  local before=saved
  assert(not pcall(A.saveOptions,{routeMapScale=value},function()end))
  script.handleEvent({},state,'',A.id,A.optionsEvent,{routeMapScale=value,language='zh'})
  assert(saved==before,'invalid scale cannot partially apply other options')
end
local f=assert(io.open('tests/test_native.lua'));local harness=f:read('*a');f:close()
assert(load(harness..[=[
do
  aliases={__options={language='zh',flashNextStop=true,routeMapScale=100}}
  local requests={}
  modules['aliases.lua'].saveOptions=function(value,callback)requests[#requests+1]={value=value,callback=callback}end
  contexts.LinnanBulbMapScaleNative={}
  api.gui.mouse={Event={Type={Pressed=1,Released=2}}}
  local param={aliases=aliasState,width=400,session={closed=false}}
  local function widgets()
    local result={}
    walk(render('LinnanBulbMapScaleNative',param),function(kind,p)if p.meta and p.meta.id then result[p.meta.id]=p end end)
    return result
  end
  local controls=widgets();local slider=assert(controls['linnan.bulb.settings.scale'])
  assert(slider.min==10 and slider.max==400 and slider.step==1 and slider.pageStep==10 and slider.horizontal)
  mouseEvents.LinnanBulbMapScaleNative({button=0,type=1})
  for value=101,237 do slider.onValueChange(value)end
  assert(#requests==0,'dragging performs no saved-state command')
  assert(widgets()['linnan.bulb.settings.scale'].value==237)
  mouseEvents.LinnanBulbMapScaleNative({button=0,type=2})
  assert(#requests==1 and requests[1].value.routeMapScale==237,'release coalesces the drag into one command')
  assert(not widgets()['linnan.bulb.settings.scale'].meta.enabled)
  aliases.__options.language='en';aliases.concurrent={name='keep'}
  requests[1].callback(nil,true);join()
  assert(aliases.__options.routeMapScale==237 and aliases.__options.flashNextStop and aliases.__options.language=='en' and aliases.concurrent)
  widgets()['linnan.bulb.settings.scale-reset'].onClick()
  assert(#requests==2 and requests[2].value.routeMapScale==100)
  requests[2].callback(nil,false);join()
  assert(widgets()['linnan.bulb.settings.scale'].value==237,'failed saves restore the accepted scale')
  widgets()['linnan.bulb.settings.scale'].onValueChange(138)
  unmounts.LinnanBulbMapScaleNative();param.session.closed=true
  for _,item in ipairs(contexts.LinnanBulbMapScaleNative)do item.expired=true end
  requests[3].callback(nil,true);join()
  assert(aliases.__options.routeMapScale==138,'an accepted command remains saved after closing')
  assert(not timers.LinnanBulbMapScaleNative,'scale setting adds no timer')
  -- The real HUD changes native drawing dimensions, retaining the upper identity.
  aliases={__options={flashNextStop=false,language='en'}}
  snapshot={vehicle=200,next=2,passed=1,route={lineId=800,name='Scale route',mode='TRAM',color='#ffe077',stops={}}}
  for i=1,4 do snapshot.route.stops[i]={id=i,name='Stop '..i,sourceIndex=i-1,transfers={}}end
  collect.read=function()return snapshot end
  free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
  local identitySize
  for _,percent in ipairs({10,37,100,175,400})do
    aliases.__options.routeMapScale=percent;tick()
    local canvas,identity,transform
    walk(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}}),function(kind,p)
      if p.meta and p.meta.id=='linnan.bulb.canvas'then canvas=p end
      if p.meta and p.meta.id=='linnan.bulb.identity'then identity=p end
      if p.meta and p.meta.class and p.meta.class:find('bulb-canvas-scale',1,true)then transform=p.meta.class end
    end)
    assert(canvas and identity)
    local size=identity.meta.styleSheet.size
    if not identitySize then identitySize=size end
    assert(size[1]==identitySize[1] and size[2]==identitySize[2],'upper-left identity does not scale')
    assert(canvas.meta.styleSheet.anchorPoint[1]==.5 and canvas.meta.styleSheet.anchorPoint[2]==1)
    assert(transform==nil,'native drawing must not magnify a pre-rendered canvas')
  end
  print('PASS: native Slider contract, one save per drag, reset/rollback/close, all-option preservation and HUD-only scaling')
end
]=],'@map_scale_ui'))()
