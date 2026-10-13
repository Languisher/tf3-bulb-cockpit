local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local S=dofile('mod/content/gui/bulb_cockpit/settings.lua')
local snapshot={route={lineId=10,name='tram 乘客-杭州-LO-1',mode='TRAM',color='#006db8',stops={}},next=3,passed=2}
for i=1,23 do snapshot.route.stops[i]={id=i,name='杭州火车站'..i,transfers={}} end
snapshot.route.stops[1].transfers={{id=20,name='tram 乘客-杭州-LO-2',mode='TRAM',color='#ba4c99'}}
local aliases={__options={flashNextStop=true,language='zh'},['10']={name=snapshot.route.name,shortName='T1'},['20']={name='tram 乘客-杭州-LO-2',shortName='T2'}}
local on=P.plan(snapshot,aliases,true,1280)
assert(on.badge=='T1' and on.name==snapshot.route.name)
assert(on.stops[1].transfers[1].text=='T2' and on.stops[1].transfers[1].mode=='TRAM',
  'separate the mode icon from the alias instead of duplicating TRAM in the text')
assert(not on.stops[1].lit and not on.stops[2].lit and on.stops[3].lit and on.stops[4].lit)
local off=P.plan(snapshot,aliases,false,1280)
assert(not off.stops[1].lit and not off.stops[2].lit and not off.stops[3].lit and off.stops[4].lit)
snapshot.next,snapshot.passed=17,16
local page=P.plan(snapshot,aliases,true,1280)
assert(page.first<=17 and page.last>=17 and page.stops[1].index==page.first)
for _,stop in ipairs(page.stops) do assert(stop.lit==(stop.index>=17)) end
assert(P.wrap('杭州火车站',6)=='杭州火\n车站')
assert(P.alias({id=10,name='不同存档的线路'},aliases)=='不同存档的线路')
local compactWidths={}
for _,count in ipairs({1,2,4,8,12,23,64}) do
  local route={name='TP 乘客-杭州-南充-RE-1',lineId=10,stops={}}
  for i=1,count do
    route.stops[i]={name=string.rep('杭州火车站WW',4)..i,transfers={}}
  end
  for _,maxWidth in ipairs({272,640,1232,1600}) do
    local plan=P.plan({route=route,next=count,passed=count-1},{},false,maxWidth)
    local g=plan.geometry
    assert(g.width<=maxWidth and plan.first<=count and plan.last==count,
      'fit the available width while retaining endpoints and next stop')
    for i,stop in ipairs(plan.stops) do
      assert(stop.nameRows<=2,'very long station names cannot grow the diagram indefinitely')
      local x=stop.x
      assert(x+stop.nameWidth*math.cos(math.pi/6)<=g.width)
      if i>1 then
        local prior=plan.stops[i-1]
        assert(prior.nameWidth*math.cos(math.pi/6)+stop.nameRows*18*0.5<stop.x-prior.x,
          'adjacent rotated station labels must not overlap')
      end
    end
    if maxWidth==1600 and count<=8 then compactWidths[count]=g.width end
  end
end
assert(compactWidths[2]<compactWidths[4] and compactWidths[4]<compactWidths[8]
  and compactWidths[4]<800,'short routes must not stretch across the viewport')
-- r8's actual full-screen component reads 1x1, not GUI pixels. The ratio to
-- a fixed-size GUI gauge must work for both normalized and absolute units.
local normalized=P.viewport({x=1,y=1},{x=100/1280,y=100/720})
assert(normalized.x==1280 and normalized.y==720)
local absolute=P.viewport({x=1280,y=720},{x=100,y=100})
assert(absolute.x==1280 and absolute.y==720)
assert(P.viewport({x=1,y=1},{x=0,y=0})==nil,'wait until the gauge is laid out')

local recipes,contexts,timers,joins,mounts,unmounts,wrappers={},{},{},{},{},{},{}
local phase='render'
local actions={}
local active,index
local function hook(value,lazy)
  index=index+1
  local context=contexts[active]
  if not context[index] then
    local item={value=lazy and value() or value}
    function item:old()return self.value end
    function item:get()return self.value end
    function item:set(v)self.value=v;self.writes=(self.writes or 0)+1 end
    function item:hasExpired()return self.expired==true end
    context[index]=item
  end
  return context[index]
end
local react={
  RegisterTool=function(def)return def end,
  RegisterRecipe=function(name,fn)recipes[name]=fn;return function(...)
    local args=table.pack(...)
    return {recipe=name,param=args[args.n],reference=args.n>1 and args[1] or nil}
  end end,
  RegisterWrapperRecipe=function(name,wrapped,fn)
    wrappers[name]=wrapped;recipes[name]=fn
    return function(param)return {recipe=name,param=param}end
  end,
  useState=function(v)return hook(v,false)end,useStateLazy=function(v)return hook(v,true)end,
  useMirrorState=function(source)return source end,
  useRef=function(v)return hook(v,false)end,
  onStepTimer=function(fn,interval,jitter)
    assert(jitter==nil or type(jitter)=='boolean','onStepTimer jitter must be a boolean')
    timers[active]=function()
      phase='deferred'
      fn()
      phase='render'
    end
  end,
  enqueueJoin=function(fn)joins[#joins+1]=fn end,
  useSelfRef=function()return {get=function()return {getPosition=function(_,x,y)
    assert(phase=='join','component geometry must be read on the main thread')
    return {x=0.2+x*0.6,y=0.8+y*0.2}
  end} end} end,
  setMouseTransparent=function()end,setDisableFocusable=function()end,
  onMount=function(fn)mounts[active]=fn end,
  onUnmount=function(fn)unmounts[active]=fn end,
  useInputAction=function(action,handler)actions[active]=actions[active] or {};actions[active][action]=handler end,
  iaHandler=function(fn)return fn end,
  CallOriginalRecipe=function(original,...)
    local args=table.pack(...)
    return {original=original,param=args[args.n],reference=args.n>1 and args[1] or nil}
  end,
}
local builtin={type={Orientation={Horizontal='H',Vertical='V'},ImageViewScaling={Stretch='stretch',AutoFit='auto-fit'},ScrollBarPolicy={AlwaysOff='off',AsNeeded='needed'},FloatingLayoutOverflowMode={KeepInside='keep-inside'}}}
-- Only constructors present in Build 40420's builtin.d.tl; do not fabricate
-- arbitrary APIs via __index (that hid the bad enum namespace in r5).
for _,name in ipairs({'BoxLayout','FloatingLayout','FloatingLayoutChild','Component','TextView','ImageView','TextInputField','Button','ToggleButton','ScrollArea','ComboBox','ComboBoxItem','Window','ActionDescriptor','Selector','HudIconManagerConfig','UseDefaultHudIcon'}) do
  builtin[name]=function(param)
    if name=='ScrollArea' then
      assert(param.content and not param.content.kind:match('Layout$'),
        'ScrollArea does not accept a Layout as content')
    end
    return {kind=name,param=param}
  end
end
local hudVisible=true
local exitChecks=0
local cameraState=dofile('mod/content/gui/bulb_cockpit/camera_state.lua')
local free={FreeCamOptions='original-freecam',FreeCamTool={push=function()end,pop=function()
  assert(hudVisible==false,'hide the route HUD before native camera exit can reflow its parent')
  exitChecks=exitChecks+1
end}}
local reads,stationInventories=0,0
local collectedLinks
local pickStations={[100]={id=100,name='杭州站'},[101]={id=101,name='站前公交'},[102]={id=102,name='杭州站'}}
local collect={resolveStation=function(id,details)
  return pickStations[details and details.stationGroup or id]
end,read=function(vehicle,withCities,links)
  assert(phase=='join','vehicle data must be read on the main thread')
  if not vehicle then return nil end
  assert(vehicle==200)
  reads=reads+1
  collectedLinks=links
  return snapshot
end,listLines=function(withCities)assert(not withCities,'normal settings must not classify cities');return {{id=10,name=snapshot.route.name,mode='TRAM'}} end,
listStationGroups=function()
  stationInventories=stationInventories+1
  return {{id=100,name='杭州站'},{id=101,name='站前公交'},{id=102,name='杭州站'}}
end}
local windowRecipe,windowParam,windowCloses
local windowApi={addSingletonWindow=function(recipe,param)windowRecipe,windowParam=recipe,param end,
  removeAllWindows=function()windowParam=nil;windowCloses=(windowCloses or 0)+1 end}
local modules={['react.lua']=react,['builtin.lua']=builtin,['free_cam_options.tl']=free,
  ['styleutil.tl']={makeStyle=function(v)return v end},['collect.lua']=collect,['native_model.lua']=P,
  ['mode_marks.lua']=B,['settings.lua']=S,
  ['localization.lua']=dofile('mod/content/gui/bulb_cockpit/localization.lua'),
  ['city_settings.lua']=dofile('mod/content/gui/bulb_cockpit/city_settings.lua'),
  ['station_settings.lua']=dofile('mod/content/gui/bulb_cockpit/station_settings.lua'),
  ['hud_react_util.tl']={makeDefaultVisibilityThresholds=function()return {}end},
  ['game_react_globals.tl']={getDefaultWindowApi=function()return windowApi end},
  ['camera_state.lua']=cameraState,
  ['diagnostics.lua']={note=function()end,watch=function()end,install=function()return true end,setCameraReader=function()end}}
ug_require=function(path)return assert(modules[path:match('([^/]+)$')],path)end
local saved={}
local aliasReads=0
modules['aliases.lua']={read=function()aliasReads=aliasReads+1;return aliases,0 end,save=function(line,shortName,callback,displayMode,parts)
  aliases[tostring(line.id)]={name=line.name,shortName=shortName,displayMode=displayMode}
  if parts then for k,v in pairs(parts)do aliases[tostring(line.id)][k]=v end end
  saved[#saved+1]={file='savegame',lineId=line.id}
  callback(nil,true)
end}
modules['aliases.lua'].stationKey=dofile('mod/content/gui/bulb_cockpit/aliases.lua').stationKey
app={loadUserdata=function()error('custom app userdata directories are rejected')end,
  saveUserdata=function()error('custom app userdata directories are rejected')end}
local guiWidth,guiHeight=1280,720
local knownIds={['linnan.bulb.host']=true,['linnan.bulb.gauge']=true,
  ['linnan.bulb.hud']=true,['linnan.bulb.settings']=true,
  ['mainView']=true,['linnan.bulb.entry-gauge']=true}
api={gui={genericRep={find=function(path)return path end,get=function()return {data={NeutralLightest={1,1,1,1},BaseMedium={.15,.18,.21,1}}}end},byId={getSize=function(id)
  assert(phase=='join' and knownIds[id]);
  if id=='linnan.bulb.host' then return {x=1,y=1} end
  if id=='mainView' then return {x=1,y=1} end
  if id=='linnan.bulb.entry-gauge'then return {x=16/guiWidth,y=16/guiHeight}end
  if id=='linnan.bulb.gauge' then return {x=100/guiWidth,y=100/guiHeight} end
  return {x=0.1,y=0.1}
end,setVisible=function(id,visible)
  assert(id=='linnan.bulb.hud','exit visibility must only affect the route HUD')
  hudVisible=visible
end,isVisibleRecursive=function(id)
  assert(phase=='join' and knownIds[id]);return true
end},camera={getSize=function()error('render-target pixels must never size the GUI') end,
  getFollowEntity=function()
    assert(phase=='join','getFollowEntity: API is currently restricted')
    return {200,0}
  end}}}
local warnings,diagnostics={},{}
log={warning=function(message)warnings[#warnings+1]=message end,
  verbose=function(message)diagnostics[#diagnostics+1]=message end}
assert(loadfile('mod/content/gui/bulb_cockpit/install.script.lua'))()
local installed=data()
local replacementMount
installed.replace({ReplaceRecipe=function(original,replacement)
  assert(original==free.FreeCamOptions and replacement);replacementMount=replacement
end})
local reference={mockReference=true}
local rootParam={meta={id='react.game-free-cam'},getGameContext=function()end}
local mounted=replacementMount(reference,rootParam)
local nativeControls=mounted.param.nativeControls
assert(nativeControls and nativeControls.reference==reference)
assert(nativeControls.param==rootParam and nativeControls.param.meta.id=='react.game-free-cam',
  'keep the native ID and caller reference on the original controls')
assert(mounted.param.meta.id=='linnan.bulb.host' and mounted.reference==nil,
  'game hiding native camera controls must not hide the custom host')
assert(rootParam.meta.id=='react.game-free-cam' and rootParam.meta.styleSheet==nil,'never mutate native metadata')
local css={}
local savedRequire=require
require=function(path)
  if path=='::/gui/main/stylesheetutil.lua' then
    return {makeAdder=function(result)return function(selector,value)
      result[#result+1]={selector=selector,style=value}
    end end}
  end
  if path=='::/scripts/mat4.tl' then return _nativeMat4 or {rotZ=function(angle)return {angle=angle}end,scaleRotZTransl=function(scale,angle,position)
    assert(position.x==0 and position.y==0 and position.z==0)
    return {scale=scale,angle=angle}
  end} end
  return savedRequire(path)
end
assert(loadfile('mod/content/gui/bulb_cockpit/native.css.lua'))()
css=data();require=savedRequire
local viewportRule
local stretchRule,rotationRule,nativeLabelsRule
for _,rule in ipairs(css) do
  if rule.selector=='R::LinnanBulbFreeCamNative' then viewportRule=rule.style end
  if rule.selector=='CockpitCamera::Line1, CockpitCamera::Line2' then nativeLabelsRule=rule.style end
  if rule.selector:find('#linnan.bulb.hud > FloatingLayout',1,true)then stretchRule=rule.style end
  if rule.selector=='TextView!bulb-station-name' and rule.style.transform then rotationRule=rule.style end
end
assert(viewportRule and viewportRule.size[1]=='100vw' and viewportRule.size[2]=='100vh')
assert(viewportRule.anchorPoint[1]==1 and viewportRule.anchorPoint[2]==0)
assert(stretchRule and stretchRule.gravity[1]==-1 and stretchRule.gravity[2]==-1,
  'stretch the canvas in every camera mode, independently of action-follow CSS')
assert(rotationRule and math.abs((rotationRule.transform.angle or math.asin(rotationRule.transform[2]))+math.pi/6)<0.001,
  'BULB station labels rise at 30 degrees')
assert(nativeLabelsRule and nativeLabelsRule.visibility=='none','replace the original two route labels')
-- TF3 custom recipes own a component. Their returned child must be a layout,
-- unlike ordinary helper functions which may return a Button or Component.
local layoutKinds={BoxLayout=true,FloatingLayout=true,AbsoluteLayout=true,FlowLayout=true}
local flashKey
local function render(name,param)
  active,index=name,0;contexts[name]=contexts[name] or {}
  local tree=recipes[name](param)
  assert(tree==nil or layoutKinds[tree.kind] or (wrappers[name] and tree.kind=='Window'),name..': Recipe child must be a layout')
  if tree and wrappers[name] then
    for key in pairs(tree.param.meta or {}) do
      assert(key=='class',name..': wrapped Window metadata would insert WithComponentParams')
    end
  end
  -- Expand the animation recipe as the native renderer would. Its local key
  -- changes at a new station/direction; stable keys preserve the blink phase.
  if name=='LinnanBulbCockpitHudNative' then
    local foundFlash=false
    local function expand(node)
      if type(node)~='table' then return node end
      if node.recipe=='LinnanBulbFlashingStationNative' then
        foundFlash=true
        local key=node.param.meta.localKey
        if flashKey~=key then contexts[node.recipe]={};flashKey=key end
        local drawn=render(node.recipe,node.param)
        return drawn.param.children[1].param.item
      end
      for key,value in pairs(node)do if type(value)=='table'then node[key]=expand(value)end end
      return node
    end
    tree=expand(tree)
    if not foundFlash then timers.LinnanBulbFlashingStationNative=nil;flashKey=nil end
  end
  return tree
end
local function join()
  local pending=joins;joins={}
  phase='join'
  for _,fn in ipairs(pending) do fn() end
  phase='render'
end
local function tick()
  if timers.LinnanBulbFlashingStationNative then timers.LinnanBulbFlashingStationNative()end
  timers.LinnanBulbCockpitHudNative()
  join()
end
local function walk(node,fn)
  if type(node)~='table' then return end
  if node.kind then fn(node.kind,node.param) end
  if node.recipe=='LinnanBulbTrackStrokeNative' or node.recipe=='LinnanBulbScaledCanvasNative'then
    fn(node.recipe,node.param)
  end
  for _,v in pairs(node) do if type(v)=='table' then walk(v,fn) end end
end
local aliasState={old=function()return aliases end,set=function(_,v)aliases=v end,
  transform=function(_,fn)aliases=fn(aliases)end,hasExpired=function()return false end}
-- The startup path renders settings while closed, before any vehicle is followed.
local settingsParam={aliases=aliasState,viewport={x=1280,y=720},color=function()return {.1,.4,.8,1}end}
local settings=render('LinnanBulbSettingsNative',settingsParam)
local toggle
walk(settings,function(kind,param)if kind=='ToggleButton' then toggle=param end end)
assert(toggle,'settings toggle exists at startup')
assert(toggle.content.kind=='ImageView' and toggle.value==0 and toggle.meta.tooltip=='线路图设置')
assert(toggle.meta.class=='bulb-settings-toggle' and toggle.meta.styleSheet==nil,
  'entry size and themed feedback are defined together by native CSS')
local entryRule,iconRule,windowVisibility
for _,rule in ipairs(css) do
  if rule.selector=='ToggleButton!bulb-settings-toggle' then entryRule=rule.style end
  if rule.selector=='ImageView!bulb-settings-toggle-icon' then iconRule=rule.style end
  if rule.selector:find('!action-follow Window!bulb-settings-window',1,true) then windowVisibility=rule.style end
end
assert(entryRule.size[1]==32 and entryRule.padding[1]==4 and entryRule.margin[3]==2)
do
  local topAligned=false
  for _,rule in ipairs(css)do
    if rule.selector=='Window!bulb-settings-window Window::Content'then
      topAligned=rule.style.gravity and rule.style.gravity[2]==0 and rule.style.padding[1]<=4
    end
  end
  assert(topAligned,'settings content must start below the title without stretch-generated top whitespace')
end
assert(iconRule.size[1]==24 and iconRule.size[2]==24,'native layer icon is 24 GUI units')
do
  local frame,grip
  for _,rule in ipairs(css)do
    if rule.selector=='Window!bulb-entry-window'then frame=rule.style end
    if rule.selector=='Window!bulb-entry-window Window::TitleLayout'then grip=rule.style end
    if rule.selector:find('bulb-settings-toggle',1,true)then
      assert(not rule.style.transform,'hover and checked states must not enlarge or shift the entry')
    end
  end
  assert(frame and frame.size[1]==44 and frame.size[2]==44 and frame.margin[1]==12,
    'floating entry starts on the native layer-button row')
  -- Zero shadowWidth only changes the outside extents. The inherited native
  -- nine-patch still needs clearing for a frameless, draggable button.
  for _,property in ipairs({'backgroundImage1','borderImage','shadowNinePatch'})do
    assert(frame[property] and frame[property].fileName=='',
      'floating entry must clear inherited window paint: '..property)
  end
  assert(frame.shadowColor and frame.shadowColor[4]==0,
    'floating entry must not tint the inherited window shadow')
  local pad,margin=entryRule.padding,entryRule.margin
  assert(entryRule.size[1]+pad[2]+pad[4]+margin[2]+margin[4]<=frame.size[1]
    and entryRule.size[2]+pad[1]+pad[3]+margin[1]+margin[3]<=frame.size[2],
    'native button including padding and margins must fit its floating frame')
  assert(grip and grip.size[1]==frame.size[1] and grip.size[2]<=8,
    'drag grip overlays only the upper edge, leaving the button body clickable')
end
assert(windowVisibility.visibility=='visible','only the mod settings window stays visible in cockpit mode')
local pauseRule
for _,rule in ipairs(css)do
  if rule.selector:find('#mainView!tool-pause #linnan.bulb.settings',1,true)then pauseRule=rule.style end
end
assert(pauseRule and pauseRule.visibility=='none','settings entry must follow the official pause-menu visibility state')
toggle.onValueChange(1)
assert(windowRecipe and windowParam,'open a real window through the native window API')
local opened=render('LinnanBulbSettingsWindowNative',windowParam)
assert(opened.kind=='Window' and opened.param.closable and opened.param.movable)
assert(opened.param.id=='linnan.bulb.settings.window' and opened.param.autoVisibilityOnFocusChange==false)
local contentParam=opened.param.content.param
settings=render('LinnanBulbSettingsContentNative',contentParam)
local query,rowCount
rowCount=0
walk(settings,function(kind,param)if kind=='TextInputField' then query=param end end)
local function countRows(node)
  if type(node)~='table' then return end
  if node.recipe=='LinnanBulbAliasRowNative' then rowCount=rowCount+1 end
  for _,v in pairs(node) do if type(v)=='table' then countRows(v) end end
end
countRows(settings);assert(rowCount==1,'open settings lists actual lines')
query.onTyping('no matching line')
settings=render('LinnanBulbSettingsContentNative',contentParam)
rowCount=0;countRows(settings);assert(rowCount==0,'empty search remains a valid layout')
local emptyFound=false
walk(settings,function(kind,param)if kind=='TextView' and param.text=='没有找到匹配的线路。' then emptyFound=true end end)
assert(emptyFound,'empty search has a useful state')
-- Exercise the actual search/sort widget callbacks, not just the list helper.
do
  local previousAliases=aliases
  aliases={__options={language='zh'},['10']={name='一号线',prefix='T',identifier='1',suffix=''},
    ['20']={name='机场线',prefix='2026-',identifier='2',suffix='-99'},
    ['30']={name='干线',prefix='',identifier='10',suffix=''}}
  local param={aliases=aliasState,geometry=S.geometry({x=1280,y=720}),color=settingsParam.color,
    lines={{id=10,name='一号线',mode='TRAM'},{id=20,name='机场线',mode='BUS'},{id=30,name='干线',mode='BUS'}}}
  contexts.LinnanBulbSettingsContentNative={}
  local function draw()
    local view=render('LinnanBulbSettingsContentNative',param)
    local widgets,ids,keys={},{},{}
    local function inspect(node)
      if type(node)~='table'then return end
      if node.recipe=='LinnanBulbAliasRowNative'then
        ids[#ids+1]=node.param.line.id;keys[node.param.line.id]=node.param.meta.localKey
      end
      if node.kind and node.param.meta and node.param.meta.id then widgets[node.param.meta.id]=node.param end
      for _,v in pairs(node)do if type(v)=='table'then inspect(v)end end
    end
    inspect(view);return widgets,ids,keys
  end
  local widgets,ids,keys=draw()
  assert(table.concat(ids,',')=='10,20,30')
  widgets['linnan.bulb.settings.search'].onTyping('2026')
  widgets,ids=draw();assert(#ids==0,'default name filter ignores badge prefixes')
  widgets['linnan.bulb.settings.scope'].onValueChange(3)
  widgets,ids=draw();assert(#ids==1 and ids[1]==20)
  widgets['linnan.bulb.settings.search'].onTyping('机场')
  widgets['linnan.bulb.settings.scope'].onValueChange(2)
  widgets,ids=draw();assert(#ids==1 and ids[1]==20,'native name search remains available')
  widgets['linnan.bulb.settings.search'].onTyping('')
  widgets['linnan.bulb.settings.sort'].onValueChange(2)
  local laterKeys
  widgets,ids,laterKeys=draw();assert(table.concat(ids,',')=='30,20,10')
  for id,key in pairs(keys)do assert(laterKeys[id]==key,'sort must preserve row keys and draft identity')end
  aliases=previousAliases;contexts.LinnanBulbSettingsContentNative={}
end
settings=render('LinnanBulbSettingsNative',settingsParam)
walk(settings,function(kind,param)if kind=='ToggleButton' then toggle=param end end)
assert(toggle.value==1,'highlight the settings button while its window is open')
actions.LinnanBulbSettingsWindowNative.IA_MENU_BACK()
assert(windowParam==nil,'native back/close removes the window')
settings=render('LinnanBulbSettingsNative',settingsParam)
walk(settings,function(kind,param)if kind=='ToggleButton' then toggle=param end end)
assert(toggle.value==0,'native close resets the entry highlight')
toggle.onValueChange(1);unmounts.LinnanBulbSettingsNative()
assert(windowParam==nil,'unmount closes the settings window before its alias state expires')
for _,viewport in ipairs({{x=1925,y=1083},{x=1280,y=720},{x=640,y=360},{x=400,y=300}}) do
  local g=S.geometry(viewport)
  assert(g.width<=viewport.x-48 and g.listHeight>=64)
  assert(g.listHeight+224+g.y*viewport.y<=viewport.y,
    'keep native title, toolbar, list and status within the viewport')
  assert(g.rowWidth==g.content-12 and g.inner==g.rowWidth-8 and g.line<=g.inner)
  if g.compact then
    assert(g.badge+g.prefix+g.number+g.suffix+24<=g.inner and g.mode+g.save+8<=g.inner)
  else
    assert(g.line+g.badge+g.prefix+g.number+g.suffix+g.mode+g.save+48==g.inner)
  end
end
local tree=render('LinnanBulbFreeCamNative',mounted.param)
local hudParam
local function findHud(node)
  if type(node)~='table' then return end
  if node.recipe=='LinnanBulbCockpitHudNative' then hudParam=node.param end
  for _,v in pairs(node) do if type(v)=='table' then findHud(v) end end
end
findHud(tree)
assert(hudParam==nil,'normal camera must not mount a route HUD')
assert(contexts.LinnanBulbFreeCamNative[3]:old().x==800,'use a bounded size before calibration')
mounts.LinnanBulbFreeCamNative();join()
tree=render('LinnanBulbFreeCamNative',mounted.param);findHud(tree)
local measured=contexts.LinnanBulbFreeCamNative[3]:old()
assert(measured.x==1280 and measured.y==720,
  'measure GUI host units after mount; camera pixels are unavailable in this test')
guiWidth,guiHeight=640,360
local readsBeforeBounds=aliasReads
assert(not timers.LinnanBulbFreeCamNative,'the root must own no idle timer');join()
assert(aliasReads==readsBeforeBounds,'viewport polling must not read saved game configuration')
assert(contexts.LinnanBulbFreeCamNative[3]:old()==measured,'normal play must not poll bounds')
snapshot.next,snapshot.passed=3,2
assert(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})==nil)
mounts.LinnanBulbCockpitHudNative();join()
assert(hudVisible==false,'an idle HUD starts hidden')
free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
assert(reads==0,'camera entry must defer collection to the main-thread join')
assert(#joins==2,'entry requests at most one bounds and one route read')
join()
assert(reads==1,'main-thread join reads the camera')
assert(#warnings==0,'main-thread refresh must not hit the restricted camera API')
tree=render('LinnanBulbFreeCamNative',mounted.param);findHud(tree)
assert(hudParam.viewport.x==640 and hudParam.viewport.y==360,'measure current GUI scale on entry')
local keptInside=0
walk(tree,function(kind,param)
  if kind=='FloatingLayoutChild' and param.overflowMode==builtin.type.FloatingLayoutOverflowMode.KeepInside then
    keptInside=keptInside+1
  end
end)
assert(keptInside==1,'keep the HUD within the viewport; the settings entry belongs to the native toolbar')
local hostLogged=false
for _,message in ipairs(diagnostics) do
  if message:find('GUI bounds: gui=1280x720',1,true) then hostLogged=true end
end
assert(hostLogged,'measure and log the host before the route HUD exists')
assert(hudParam.meta.id=='linnan.bulb.hud')
assert(hudParam.meta.styleSheet.anchorPoint[1]==0 and hudParam.meta.styleSheet.anchorPoint[2]==0,
  'the split HUD owns the full viewport from its upper-left origin')
local hudPosition=tree.param.children[2].param
assert(hudPosition.h==0 and hudPosition.v==0 and hudParam.meta.styleSheet.size[1]==guiWidth
  and hudParam.meta.styleSheet.size[2]==guiHeight,'split identity/diagram layout must own explicit viewport bounds')
local originalFound=false
local function original(node)
  if type(node)~='table' then return end
  if node.original==free.FreeCamOptions then originalFound=true end
  for _,v in pairs(node) do if type(v)=='table' then original(v) end end
end
original(tree);assert(originalFound,'retain original back/screenshot handlers')
assert(tree.param.children[1].param.item==nativeControls,'native controls retain their own component')
assert(tree.param.children[2].param.item.recipe=='LinnanBulbCockpitHudNative',
  'HUD must be a sibling of native controls, never a descendant of their hidden ID')
local function findSettings(node)
  if type(node)~='table'then return end
  if node.recipe=='LinnanBulbSettingsNative'then return node.param end
  for _,v in pairs(node)do local found=findSettings(v);if found then return found end end
end
assert(not findSettings(tree),'camera replacement must not own or duplicate the toolbar entry')
local entryNode=installed.mainButton()
local entryTree=render(entryNode.recipe,entryNode.param)
assert(not findSettings(entryTree),'entry extension occupies no upper-left toolbar space')
mounts.LinnanBulbMainButtonNative();join()
local launcherParam=assert(windowParam)
local launcherTree=render('LinnanBulbLauncherNative',launcherParam)
assert(launcherTree.kind=='Window' and launcherTree.param.movable and launcherTree.param.compact
  and launcherTree.param.pinned and not launcherTree.param.pinnable and not launcherTree.param.closable)
assert(launcherTree.param.initialX==1 and launcherTree.param.initialY==0,'launcher starts at upper right')
assert(not launcherTree.param.autoFocusOnBecomingVisible,'launcher must not steal focus on load')
local entrySettings=assert(findSettings(launcherTree),'native floating launcher owns the settings entry')
assert(entrySettings.meta.id=='linnan.bulb.settings' and not entrySettings.meta.class)
windowParam,windowRecipe=nil,nil
assert(not timers.LinnanBulbMainButtonNative,'entry must not add background polling')
local hiddenSettingsRule
for _,rule in ipairs(css)do
  if rule.selector=='!action-follow #linnan.bulb.settings, !action-camera #linnan.bulb.settings'then hiddenSettingsRule=rule.style end
end
assert(hiddenSettingsRule and hiddenSettingsRule.visibility=='none','camera actions hide the independent toolbar entry')
local gauge
walk(tree,function(kind,param)
  if kind=='Component' and param.meta and param.meta.id=='linnan.bulb.gauge' then gauge=param end
end)
assert(gauge and gauge.meta.styleSheet.size[1]==100 and gauge.meta.styleSheet.size[2]==100,
  'use a fixed GUI-unit gauge rather than interpreting normalized screen size as pixels')
assert(gauge.mouseTransparent==true,'the calibration gauge must not block game controls')
tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
local canvas,identity
walk(tree,function(kind,param)
  if kind=='Component' and param.meta and param.meta.id=='linnan.bulb.canvas' then canvas=param end
  if kind=='Component' and param.meta and param.meta.id=='linnan.bulb.identity' then identity=param end
  if layoutKinds[kind] then
    assert(param.meta==nil or (param.meta.class=='bulb-fixed-layout' and next(param.meta,'class')==nil),
      'size/background belong to a component; layouts may carry only their CSS class')
  end
end)
assert(canvas and canvas.layout.kind=='FloatingLayout' and canvas.meta.styleSheet.size[2]>100,
  'an explicit panel component must reserve the full diagram height')
assert(canvas.meta.styleSheet.backgroundColor[4]==0,'keep scenery visible between station labels and transfers')
assert(identity and not identity.meta.styleSheet.backgroundColor1 and identity.meta.styleSheet.backgroundColor[4]==0,
  'line identity must remain transparent')
local identityPosition,canvasPosition
for _,child in ipairs(tree.param.children)do
  local pos=child.param
  if pos.item.param.meta.id=='linnan.bulb.identity'then identityPosition=pos end
  if pos.item.param.meta.id=='linnan.bulb.canvas'then canvasPosition=pos end
end
assert(math.abs(identityPosition.h*1280-24)<.001 and math.abs(identityPosition.v*720-72)<.001)
assert(canvasPosition.h==.5 and math.abs(canvasPosition.v*720-(720-32))<.001)
assert(canvas.meta.styleSheet.anchorPoint[1]==.5 and canvas.meta.styleSheet.anchorPoint[2]==1,
  'station diagram is centered horizontally and anchored above the bottom edge')
walk(canvas.layout,function(kind,param)
  if kind=='TextView'then
    assert(param.meta.class~='bulb-route-title' and param.meta.class~='bulb-line-badge',
      'line title and main badge must not remain in the bottom station diagram')
  end
end)
walk(identity.layout,function(kind,param)
  assert(not param.meta or (param.meta.class~='bulb-station-name' and param.meta.class~='bulb-station-terminus-name'),
    'top-left identity must contain no station diagram')
end)
local panelWidth,panelHeight=table.unpack(canvas.meta.styleSheet.size)
local labelCount,rail,centres=0,nil,{}
local omissionCount,terminusLabels=0,0
for _,child in ipairs(canvas.layout.param.children) do
  local positioned=child.param
  local item=positioned.item
  local meta=item.param.meta
  assert(meta.class~='bulb-page-label','station pagination labels must be removed')
  if meta.class=='bulb-omission-label'then
    omissionCount=omissionCount+1
    assert(meta.tooltip:find('省略',1,true) and item.param.text:find('站',1,true))
    assert(not meta.styleSheet.backgroundColor and not meta.styleSheet.backgroundColor1,
      'omission labels must not reintroduce a backing')
  end
  assert(meta and meta.styleSheet.anchorPoint,
    'every positioned item needs an explicit anchor; default anchors shift wide rails and labels')
  local s=meta.styleSheet
  if item.kind=='Component' and meta.class=='bulb-track' then
    rail={x=positioned.h*panelWidth-s.anchorPoint[1]*s.size[1],
      y=positioned.v*panelHeight-s.anchorPoint[2]*s.size[2],width=s.size[1],height=s.size[2]}
  elseif item.kind=='Component' and meta.class=='bulb-station-marker' then
    centres[#centres+1]={x=positioned.h*panelWidth+(0.5-s.anchorPoint[1])*s.size[1],
      y=positioned.v*panelHeight+(0.5-s.anchorPoint[2])*s.size[2]}
  end
  if item.kind=='Component' then
    local fill=meta.styleSheet.backgroundColor
    assert(not fill or fill[4]==0 or fill[1]<0.85 or fill[2]<0.85 or fill[3]<0.85,
      'the diagram must not contain pale or white label backplates')
  end
  if meta and (meta.class=='bulb-station-name' or meta.class=='bulb-station-terminus-name') then
    labelCount=labelCount+1
    if meta.class=='bulb-station-terminus-name'then
      terminusLabels=terminusLabels+1
      assert(s.backgroundColor and s.backgroundColor[3]>.5 and not s.backgroundColor1,
        'terminus name uses a flat rectangular blue background, not the rounded popup surface')
    else assert(s.backgroundColor1 and not s.backgroundColor,'other station labels retain their existing rounded surface')end
    local w,h=table.unpack(meta.styleSheet.size)
    local x,y=positioned.h*panelWidth,positioned.v*panelHeight
    local c,s=math.cos(math.pi/6),math.sin(math.pi/6)
    assert(x-h*s>=0 and x+w*c<=panelWidth,'rotated station labels stay within panel width')
    assert(y-w*s-h*c>=0 and y<=panelHeight,'station labels have real space above the rail')
  end
end
assert(rail and #centres>1 and math.abs(rail.x-centres[1].x)<0.01
  and math.abs(rail.x+rail.width-centres[#centres].x)<0.01,
  'the rail starts and ends exactly at the first and last station centres')
for _,centre in ipairs(centres) do
  assert(math.abs(centre.y-(rail.y+rail.height/2))<0.01,'station lights sit on the rail')
end
assert(labelCount==#P.plan(snapshot,aliases,false,1280-48).stops,
  'each visible station has its own separate label')
assert(terminusLabels==2,'both terminal names, not their station dots, must use rectangular text boxes')
for _,rule in ipairs(css)do
  if rule.selector:find('bulb-station-terminus-name',1,true)then
    assert(not rule.style.backgroundImage1,'terminal text boxes must not inherit the rounded nine-patch')
  end
end
assert(omissionCount==#P.plan(snapshot,aliases,false,1280-48).gaps and omissionCount>0,
  'the HUD renders a counted omission at every hidden rail segment')
local lamps,title=0,false
local boldLabelCount=0
walk(tree,function(kind,param)
  if (kind=='ImageView' or kind=='Component') and param.meta.class=='bulb-station-light' then lamps=lamps+1 end
  if kind=='TextView' then
    local meta=param.meta
    local class=meta and meta.class
    if class=='bulb-station-name' or class=='bulb-station-terminus-name' or class=='bulb-line-badge' or class=='bulb-transfer-label' then
      boldLabelCount=boldLabelCount+1
      assert(meta.styleSheet.fontWeight=='Bold' and param.useUnicodeCompatibilityFont==false,
        'BULB labels must use the native locale font with its Bold face, not the compatibility font')
    end
    assert(not meta.styleSheet.fontFamily,'TF3 does not expose per-label custom font families')
    if class=='bulb-route-title' and meta.tooltip==snapshot.route.name then
      title=true
      assert(meta.styleSheet.fontWeight=='Bold','make the upper-left route caption clear against the smoked surface')
    end
  end
end)
local futureLamps=0
for _,stop in ipairs(P.plan(snapshot,aliases,false,1280-48).stops)do
  if stop.index>snapshot.next then futureLamps=futureLamps+1 end
end
assert(lamps==futureLamps+1 and title and boldLabelCount>=3,'next and future stations start yellow')
tick()
tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}});lamps=0
walk(tree,function(kind,param)if (kind=='ImageView' or kind=='Component') and param.meta.class=='bulb-station-light' then lamps=lamps+1 end end)
assert(lamps==futureLamps,'only the next station turns off; future stations stay yellow and passed stations stay off')
local hudWrites=contexts.LinnanBulbCockpitHudNative[1].writes or 0
local flashWrites=contexts.LinnanBulbFlashingStationNative[1].writes or 0
local function allHudWrites()
  local total=0;for _,item in ipairs(contexts.LinnanBulbCockpitHudNative)do total=total+(item.writes or 0)end
  return total
end
local writesBeforeIdle=allHudWrites()
for _=1,10 do tick()end
assert(allHudWrites()==writesBeforeIdle,'unchanged progress must not write any HUD state or ref')
assert((contexts.LinnanBulbCockpitHudNative[1].writes or 0)==hudWrites,
  'unchanged progress must not invalidate the full route HUD on each blink')
assert(contexts.LinnanBulbFlashingStationNative[1].writes==flashWrites+10,
  'only the next station owns the half-second animation state')
local geometryLogged=false
for _,message in ipairs(diagnostics) do
  if message:find('HUD bounds:',1,true) then geometryLogged=true end
end
assert(geometryLogged,'log actual component bounds after rendering, on the main thread')
assert(#saved==0,'live route rendering must never export requests or images')
local readSnapshot=collect.read
collect.read=function()
  assert(phase=='join')
  error('simulated collector failure')
end
tick()
tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
local failureShown=false
walk(tree,function(kind,param)
  if kind=='TextView' and param.text:find('无法读取车辆数据',1,true) then failureShown=true end
end)
assert(failureShown and #warnings==1,'collector failure must show a diagnostic instead of a silent blank')
tick();assert(#warnings==1,'deduplicate repeated error logs')
collect.read=readSnapshot;tick()
tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
local recovered=false
walk(tree,function(kind,param)if kind=='TextView' and param.meta.class=='bulb-route-title'
  and param.meta.tooltip==snapshot.route.name then recovered=true end end)
assert(recovered,'recover after a transient read failure')
local expired=contexts.LinnanBulbCockpitHudNative[1]
expired.expired=true
local beforeExpiry=reads
tick()
assert(reads==beforeExpiry,'discard pending work after the component expires')
expired.expired=false
timers.LinnanBulbCockpitHudNative()
free.FreeCamTool.pop()
assert(exitChecks==1 and hudVisible==false,'exit hides immediately without waiting for a timer or queued join')
assert(contexts.LinnanBulbCockpitHudNative[1]:old()==nil,'exit releases the route without waiting for hidden timers')
assert(render('LinnanBulbCockpitHudNative',{aliases=aliasState})==nil,
  'a render during normal-camera layout changes must discard the old route')
-- A stale snapshot is deliberately retained until the next tick; it must
-- stay hidden even while the normal camera changes the host dimensions.
guiWidth,guiHeight=1200,720
assert(not timers.LinnanBulbFreeCamNative,'the root must own no idle timer');join()
assert(hudVisible==false,'host recalibration after exit must not reveal the old route')
collect.read=function(vehicle)assert(vehicle==nil);return nil end;tick()
assert(hudVisible==false,'a pending HUD refresh must keep the exited camera hidden')
assert(render('LinnanBulbCockpitHudNative',{aliases=aliasState})==nil,'remove diagram after leaving follow camera')
local message={set=function()end,hasExpired=function()return false end}
tree=render('LinnanBulbAliasRowNative',{line={id=10,name=snapshot.route.name},aliases=aliasState,message=message,geometry=S.geometry({x=1280,y=720}),lineColor={.1,.4,.8,1}})
local input,save,modeButton
walk(tree,function(kind,param)
  if kind=='TextInputField' and param.meta.id=='linnan.bulb.identifier.10' then input=param
  elseif kind=='Button' and param.meta.id=='linnan.bulb.save.10' then save=param
  elseif kind=='ComboBox' and param.meta.id=='linnan.bulb.mode.10' then modeButton=param end
end)
assert(#modeButton.items==8 and modeButton.compact==true,'type dropdown shows each actual type exactly once')
for i,name in ipairs({'Train','RER','地铁','电车','公交','轮渡','航空','货运'})do
  assert(modeButton.items[i].param.content.param.text==name,'one RER option with no duplicate automatic choice')
end
modeButton.onValueChange(3)
assert(input,'structured identifier input exists')
input.onTyping('  9  ');save.onClick();join()
assert(#saved==1 and saved[1].file=='savegame' and aliases['10'].shortName=='T9')
assert(aliases['10'].displayMode=='METRO','type selection applies to the live line and is saved with its abbreviation')
aliases['10'].shortName=string.rep('WWWW杭州',30)
aliases['10'].prefix,aliases['10'].identifier,aliases['10'].suffix=nil,nil,nil
collect.read=readSnapshot;free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
assert(hudVisible==false,'re-entering must wait for fresh route data before revealing the HUD')
join();assert(hudVisible==true,'camera entry restores the HUD without relying on a hidden timer')
tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1925,y=1083}})
local fullWidth,badge
walk(tree,function(kind,param)
  if kind=='Component' and param.meta and param.meta.id=='linnan.bulb.canvas' then fullWidth=param.meta.styleSheet.size[1] end
  if kind=='TextView' and param.meta.class=='bulb-line-badge' then badge=param end
  if kind=='TextView' and (param.meta.class=='bulb-line-badge' or param.meta.class=='bulb-transfer-label') then
    local s=param.meta.styleSheet
    assert(not param.text:find('\n',1,true) and s.size[1]<=50 and s.size[2]<=38,
      'long aliases stay inside their fixed mode-specific marker')
    assert(param.meta.tooltip,'retain the full name in the tooltip')
  end
end)
assert(fullWidth<=1600 and fullWidth>500,'dense routes retain useful context while fitting the viewport')
assert(badge and badge.meta.styleSheet.size[1]<=38 and badge.meta.styleSheet.size[2]<=38
  and badge.text:find('…',1,true),'long aliases must not grow the route box')
assert(P.mode({id=1,name='Metro 杭州 1',mode='TRAIN'}, {})=='TRAIN')
assert(P.mode({id=1,name='杭州地铁1号线',mode='TRAIN'}, {})=='TRAIN')
assert(P.mode({id=1,name='Metropolitan express',mode='TRAIN'}, {})=='TRAIN')
assert(P.mode({id=1,name='杭州地铁1号线',mode='TRAIN'}, {['1']={name='杭州地铁1号线',displayMode='TRAIN'}})=='TRAIN')
assert(P.mode({id=1,name='different save',mode='TRAIN'}, {['1']={name='杭州地铁1号线',displayMode='METRO'}})=='TRAIN')
local originalRoute=snapshot.route
local shapes={METRO='circle',RER='rounded-square',TRAM='tram-bars',BUS='bus-frame'}
local labels={METRO='1',RER='A',TRAM='T1',BUS='1001'}
for mode,shape in pairs(shapes) do
  snapshot.route={lineId=10,name='test '..mode,mode=mode,color='#a13bcb',stops={
    {name='杭州火车站',transfers={{id=20,name='transfer',mode=mode,color='#26b775'}}},
    {name='北江路',transfers={}}}}
  aliases={__options={language='zh'},['10']={name=snapshot.route.name,shortName=labels[mode]},['20']={name='transfer',shortName=labels[mode]}}
  tick();tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  local own,transfer=false,false
  walk(tree,function(kind,param)
    if kind=='ImageView' and param.meta.class=='bulb-shape-'..shape then
      local c=param.meta.styleSheet.color
      own=own or math.abs(c[1]-161/255)<0.001 and math.abs(c[3]-203/255)<0.001
      transfer=transfer or math.abs(c[1]-38/255)<0.001 and math.abs(c[2]-183/255)<0.001
    end
  end)
  assert(own and transfer,'main and transfer marks must use their respective live game colors and mode shapes')
  local g=B.geometry(mode,false)
  if mode=='BUS' then assert(math.abs(g.width/g.height-20/9)<0.001,'BULB bus badges are flat rectangles')
  else assert(g.width==g.height,'metro, train and tram indices occupy square bounds') end
end
-- Suffixes switch RER A-E from graphical presets to TextView. Check the real
-- HUD text path, including fitted small transfer badges and CJK affixes.
for _,case in ipairs({
  {mode='TRAM',prefix='T',identifier='1',suffix=''},
  {mode='TRAM',prefix='T',identifier='1',suffix='b'},
  {mode='BUS',prefix='',identifier='1001',suffix=''},
  {mode='BUS',prefix='',identifier='1001',suffix='b'},
  {mode='RER',prefix='',identifier='A',suffix='b'},
  {mode='RER',prefix='',identifier='B',suffix='1'},
  {mode='RER',prefix='RE',identifier='1',suffix=''},
  {mode='METRO',prefix='',identifier='1',suffix='A'},
  {mode='BUS',prefix='快',identifier='1',suffix='支'},
}) do
  snapshot.route={lineId=10,name='主线 '..case.mode,mode=case.mode,color='#a13bcb',stops={
    {name='杭州火车站',transfers={{id=20,name='换乘线',mode=case.mode,color='#26b775'}}},
    {name='北江路',transfers={}}}}
  aliases={__options={language='zh'},}
  for _,line in ipairs({{id=10,name=snapshot.route.name},{id=20,name='换乘线'}})do
    aliases[tostring(line.id)]={name=line.name,prefix=case.prefix,identifier=case.identifier,suffix=case.suffix}
  end
  tick();tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  local seen={}
  local label=case.prefix..case.identifier..case.suffix
  walk(tree,function(kind,param)
    local class=param.meta and param.meta.class
    if kind=='TextView' and (class=='bulb-line-badge' or class=='bulb-transfer-label')then
      seen[class]=true
      assert(param.meta.tooltip==(class=='bulb-line-badge' and snapshot.route.name or '换乘线'))
      assert(param.meta.styleSheet.fontWeight=='Bold' and param.useUnicodeCompatibilityFont==false,
        case.mode..' '..label..' must retain the native Bold face in main and transfer badges')
      assert(param.text==label or param.text:find('…',1,true),
        'fit the complete prefix/identifier/suffix in the fixed badge without dropping the suffix silently')
    end
  end)
  assert(seen['bulb-line-badge'] and seen['bulb-transfer-label'],
    'exercise both real TextViews for '..case.mode..' '..label)
end
snapshot.route=originalRoute
-- Default badges must reach the renderer, even when a line is itself named A.
aliases={__options={language='zh'},}
snapshot.lines={{id=100,name='A',mode='TRAIN'},
  {id=200,name='电车北线',mode='TRAM'},{id=300,name='杭州地铁1号线',mode='TRAIN'}}
snapshot.route={lineId=100,name='A',mode='TRAIN',color='#a13bcb',stops={
  {name='杭州火车站',transfers={{id=200,name='电车北线',mode='TRAM',color='#26b775'},
    {id=300,name='杭州地铁1号线',mode='TRAIN',color='#006db8'}}},
  {name='北江路',transfers={}}}}
tick();tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
local defaultMain,defaultTransfers,rerIcons=nil,{},0
walk(tree,function(kind,param)
  if kind=='TextView' and param.meta.class=='bulb-line-badge' then defaultMain=param.text end
  if kind=='TextView' and param.meta.class=='bulb-transfer-label' then defaultTransfers[param.text]=true end
  if kind=='ImageView' and param.meta.class=='bulb-rer-line-preset' then
    defaultMain=param.path:match('/rer%-(%a)%.tga$'):upper()
  end
  if kind=='ImageView' and param.meta.class=='bulb-rer-transfer-preset' then
    defaultTransfers[param.path:match('/rer%-(%a)%.tga$'):upper()]=true
  end
  if kind=='ImageView' and param.path:match('/transilien%-mode.tga$') then rerIcons=rerIcons+1 end
end)
assert(defaultMain=='A' and defaultTransfers.T1 and defaultTransfers.B,
  'render the complete-save defaults, including names equal to their own badge')
assert(rerIcons==2,'show the Transilien train symbol in both normal and small RER icons')
for _,actual in ipairs({'TRAIN','TRAM'}) do
  local line={id=actual=='TRAIN' and 400 or 401,name=actual..' 可配置线路',mode=actual}
  contexts.LinnanBulbAliasRowNative={}
  local rowParam={line=line,aliases=aliasState,message=message,geometry=S.geometry({x=400,y=300}),
    lineColor={.1,.4,.8,1},defaultBadge=actual=='TRAIN' and 'A' or 'T1'}
  for index,choice in ipairs({'RER','METRO','TRAM'}) do
    local row=render('LinnanBulbAliasRowNative',rowParam)
    local combo,apply,input
    walk(row,function(kind,param)
      if kind=='ComboBox' then combo=param elseif kind=='Button' then apply=param
      elseif kind=='TextInputField' and param.meta.id=='linnan.bulb.identifier.'..line.id then input=param end
    end)
    local expected=index==1 and (rowParam.defaultBadge:match('^T(%d+)$') or rowParam.defaultBadge)
      or (index==2 and 'A' or '1')
    local prior=index==1 and (actual=='TRAIN' and 'Train' or '电车') or (index==2 and 'RER' or '地铁')
    assert(combo.items[combo.value].param.content.param.text==prior,
      'default and saved types select the same unique menu item')
    assert(input.placeholderText==expected,'automatic center follows the current draft mode without extra placeholder words')
    combo.onValueChange(index+1);apply.onClick();join()
    assert(aliases[tostring(line.id)].displayMode==choice and aliases[tostring(line.id)].identifier=='',
      'native settings applies '..choice..' to an actual '..actual..' line without forcing a custom alias')
    assert(P.alias(line,aliases,P.defaults({line},aliases))==({'A','1','T1'})[index])
    row=render('LinnanBulbAliasRowNative',rowParam)
    walk(row,function(kind,param)if kind=='ComboBox' then assert(param.value==index+1) end end)
  end
end
contexts.LinnanBulbAliasRowNative={}
aliases['400']={name='TRAIN 可配置线路',shortName='',displayMode='TRAIN'}
tree=render('LinnanBulbAliasRowNative',{line={id=400,name='TRAIN 可配置线路',mode='TRAIN'},
  aliases=aliasState,message=message,geometry=S.geometry({x=1280,y=720}),lineColor={.1,.4,.8,1}})
walk(tree,function(kind,param)if kind=='ComboBox' then assert(param.value==1,'saved Train selections display as Train') end end)
assert(aliases['400'].displayMode=='TRAIN','opening settings preserves legacy saved configuration without a migration write')
-- Open the batch window through its actual settings button, edit district,
-- enable, apply, confirm/reload, then close the direct native Window.
do
  local previousAliases=aliases
  aliases={__options={language='zh'},}
  local lines={{id=910,name='市内公交',mode='BUS',busScope='local',towns={{id=100,name='杭州'}}},
    {id=920,name='跨城公交',mode='BUS',busScope='express',towns={{id=100,name='杭州'},{id=200,name='旅顺'}}}}
  local towns={{id=100,name='杭州'},{id=200,name='旅顺'}}
  local listLines,listTowns=collect.listLines,collect.listTowns
  collect.listLines=function(withCities)assert(withCities);return lines end
  collect.listTowns=function()return towns end
  local calls=0
  modules['aliases.lua'].saveBusNaming=function(config,targets,callback)
    calls=calls+1;assert(#targets==2 and config.enabled and config.districts['100'].code=='10')
    assert(config.expressCode=='52' and config.format=='code_table')
    aliases.__busNaming=config
    callback(nil,true)
  end
  contexts.LinnanBulbSettingsContentNative={}
  local content=render('LinnanBulbSettingsContentNative',{aliases=aliasState,lines=lines,towns=towns,
    viewport={x=400,y=300},geometry=S.geometry({x=400,y=300}),color=settingsParam.color})
  local entry
  walk(content,function(kind,param)if kind=='Button' and param.meta.id=='linnan.bulb.settings.city'then entry=param end end)
  assert(entry and entry.content.param.text=='公交线路编号一键配置',
    'batch naming opens directly from the line settings page')
  entry.onClick()
  local param=windowParam
  assert(param.width<=400-48 and param.listHeight==32)
  local cityWindow=render('LinnanBulbCityWindowNative',param)
  assert(cityWindow.kind=='Window' and cityWindow.param.id=='linnan.bulb.city.window'
    and cityWindow.param.title=='公交线路编号一键配置')
  local function draw()
    local result={}
    walk(render('LinnanBulbCityContentNative',param),function(kind,p)
      assert(kind~='ComboBox','bus batch configuration uses a toggle button rather than a dropdown')
      if p.meta and p.meta.id then result[p.meta.id]=p end
      if kind=='TextView'then result[p.text]=true end
      if kind=='TextView' and p.meta.styleSheet.size[1]>0 then
        assert(#p.text==0 or P.wrap(p.text,math.max(2,math.floor(p.meta.styleSheet.size[1]/19)*2),false)==p.text,
          'batch text must stay within its fixed width')
      end
    end)
    return result
  end
  local widgets=draw()
  assert(widgets['linnan.bulb.city.enabled'].value==0 and calls==0,'default off, opening performs no write')
  assert(widgets['linnan.bulb.city.100'].value=='10','initial city code comes from the mapping table')
  assert(widgets['linnan.bulb.city.express'].value=='51','Express has an editable numeric mapping in the same table')
  widgets['linnan.bulb.city.enabled'].onValueChange(1)
  widgets['linnan.bulb.city.express'].onTyping('52')
  widgets['linnan.bulb.city.100'].onTyping('杭')
  widgets=draw();widgets['linnan.bulb.city.apply'].onClick()
  assert(calls==0,'invalid prefix cannot be submitted')
  widgets['linnan.bulb.city.100'].onTyping('52')
  widgets=draw();widgets['linnan.bulb.city.apply'].onClick()
  assert(calls==0,'duplicate city/Express prefixes cannot be submitted')
  widgets['linnan.bulb.city.100'].onTyping(' 10 ')
  widgets=draw();widgets['linnan.bulb.city.apply'].onClick();join()
  assert(calls==1 and aliasState:old().__busNaming.enabled)
  assert(widgets['1001'] and widgets['5201'],'show live examples for city and Express mappings')
  assert(P.alias(lines[1],aliases,P.defaults(lines,aliases))=='1001')
  assert(P.alias(lines[2],aliases,P.defaults(lines,aliases))=='5201')
  cityWindow.param.onClose();assert(windowParam==nil)
  collect.listLines,collect.listTowns=listLines,listTowns
  aliases=previousAliases
end
-- Native station association workflow: click two real map stations, then confirm.
do
  assert(stationInventories==0,'opening normal settings must not enumerate all stations')
  local previousAliases=aliases
  aliases={__options={language='zh'},}
  local calls,fail=0,false
  modules['aliases.lua'].saveStationLink=function(a,b,remove,callback)
    calls=calls+1
    local key=modules['aliases.lua'].stationKey(a.id,b.id)
    if not fail then
      aliases.__stationLinks=aliases.__stationLinks or {}
      if remove then aliases.__stationLinks[key]=nil
      else aliases.__stationLinks[key]={a=a,b=b}end
    end
    callback(nil,not fail)
  end
  local tool,toolParam,toolContext,actionFn,freePops
  freePops=0
  local stack={getActiveTool=function()return tool,'test-key'end}
  function stack.push(def,key,param,stacking)
    assert(stacking==true,'station picker preserves the previous map tool')
    tool,toolParam=def,param
    toolContext={setActionFn=function(fn)actionFn=fn end,
      popSelf=function()stack.pop(def,key)end}
    def.push(toolContext,param)
  end
  function stack.pop(def,key)
    if tool~=def then return end
    if def.name=='FreeCam'then assert(key==nil,'use the native default FreeCam key when returning to the map')end
    local old,param,ctx=tool,toolParam,toolContext
    tool,toolParam,toolContext,actionFn=nil,nil,nil,nil
    if old.pop then old.pop(ctx,param)end
  end
  modules['game_react_globals.tl'].getDefaultToolStackApi=function()return stack end
  api.type={ComponentType={STATION_GROUP=1},Vec4f={new=function(...)return {...}end}}
  local genericGet=api.gui.genericRep.get
  api.gui.genericRep.get=function(path)
    if path:find('selection_colors',1,true)then return {data={default={selectionColor={1,1,1,0},
      selectionOutlineColor={1,1,1,1},selectionCircleColor={1,1,1,1},crosshairColor={1,1,1,1}}}}end
    return genericGet(path)
  end
  contexts.LinnanBulbSettingsContentNative={}
  local parent=render('LinnanBulbSettingsContentNative',{aliases=aliasState,lines={},
    viewport={x=400,y=300},geometry=S.geometry({x=400,y=300}),color=settingsParam.color})
  local entry
  walk(parent,function(kind,p)if kind=='Button' and p.meta.id=='linnan.bulb.settings.stations'then entry=p end end)
  assert(entry,'station associations are accessible in ordinary settings')
  entry.onClick();assert(stationInventories==1)
  local param=windowParam
  local window=render('LinnanBulbStationWindowNative',param)
  assert(window.kind=='Window' and window.param.id=='linnan.bulb.station.window')
  local function draw()
    local widgets={}
    walk(render('LinnanBulbStationContentNative',param),function(kind,p)
      if p.meta and p.meta.id then widgets[p.meta.id]=p end
      if kind=='TextView' and p.meta.styleSheet.size[1]>0 then
        local units=math.max(2,math.floor(p.meta.styleSheet.size[1]/19)*2)
        assert(P.wrap(p.text,units,false)==p.text,'station labels fit the native controls')
      end
    end)
    return widgets
  end
  local widgets=draw()
  assert(widgets['linnan.bulb.station.pick'],'station linking must start with native map picking')
  assert(param.width==328 and param.listHeight==32 and param.y*300+param.listHeight+260<=300,
    'station window fits a 400x300 GUI viewport')
  assert(not widgets['linnan.bulb.station.select.a'] and not widgets['linnan.bulb.station.search.a'],
    'station selection lists and searches have been replaced')
  widgets['linnan.bulb.station.add'].onClick();assert(calls==0 and not tool,'no implicit selection or write on open')
  tool={name='FreeCam',pop=function()freePops=freePops+1 end}
  widgets['linnan.bulb.station.pick'].onClick()
  assert(tool and tool.name=='LinnanBulbStationPick' and freePops==1,'return from cockpit to the map before picking')
  local function selector()
    local result
    walk(assert(actionFn)(),function(kind,p)
      if kind=='Selector'then result=p end
      if kind=='HudIconManagerConfig'then assert(#p.preFilter==1 and p.preFilter[1]==1,'show only native station icons')end
    end)
    return assert(result)
  end
  local pick=selector()
  assert(pick.filter(100) and not pick.filter(999))
  pick.onSelect(100,{},nil);widgets=draw()
  assert(widgets['linnan.bulb.station.chosen.a'].meta.tooltip:find('#100',1,true))
  assert(actionFn().param.highlightedEntities[1]==100,'keep the first picked station highlighted on the map')
  assert(widgets['linnan.bulb.station.add'].meta.enabled==false)
  pick.onSelect(100,{},nil);assert(calls==0 and tool,'the same station cannot be picked twice')
  pick.onSelect(101,{},nil);widgets=draw()
  assert(not tool and not actionFn and calls==0,'two clicks finish picking without writing before confirmation')
  assert(widgets['linnan.bulb.station.chosen.b'].meta.tooltip:find('#101',1,true))
  pick.onSelect(102,{},nil);assert(draw()['linnan.bulb.station.chosen.b'].meta.tooltip:find('#101',1,true),
    'stale native selection callbacks cannot replace the completed pair')
  widgets['linnan.bulb.station.add'].onClick();widgets['linnan.bulb.station.add'].onClick()
  assert(calls==1,'pending saves cannot be double-submitted')
  join();widgets=draw()
  assert(aliases.__stationLinks['100:101'] and widgets['linnan.bulb.station.remove.100:101'])
  widgets['linnan.bulb.station.add'].onClick();assert(calls==1,'duplicate direct links are rejected')
  tick();assert(collectedLinks==aliases.__stationLinks,'the live HUD receives persisted associations')
  widgets['linnan.bulb.station.remove.100:101'].onClick();join();widgets=draw()
  assert(not aliases.__stationLinks['100:101'])
  fail=true;widgets['linnan.bulb.station.add'].onClick();join()
  assert(not aliases.__stationLinks['100:101'],'failed commands must not show an optimistic saved link')
  fail=false;widgets=draw()
  local bus=pickStations[101];pickStations[101]=nil
  local before=calls;widgets['linnan.bulb.station.add'].onClick();assert(calls==before,'revalidate deleted stations at confirmation')
  pickStations[101]=bus
  widgets['linnan.bulb.station.pick'].onClick();pick=selector();pick.onSelect(100,{})
  tool.shelve(toolContext,toolParam,true);assert(not actionFn,'pause/shelved tools cannot intercept map clicks')
  pick.onSelect(101,{});assert(tool and not draw()['linnan.bulb.station.add'].meta.enabled)
  tool.shelve(toolContext,toolParam,false);pick=selector();pick.onSelectSecondary()
  widgets=draw();assert(not tool and widgets['linnan.bulb.station.add'].meta.enabled==false,'right-click cancels incomplete selection')
  aliases.__stationLinks['100:999']={a={id=100,name='杭州站'},b={id=999,name='拆除的公交站'}}
  widgets=draw();assert(widgets['linnan.bulb.station.remove.100:999'])
  widgets['linnan.bulb.station.remove.100:999'].onClick();join();assert(not aliases.__stationLinks['100:999'])
  widgets=draw();widgets['linnan.bulb.station.pick'].onClick();pick=selector();pick.onSelect(100,{})
  widgets=draw();widgets['linnan.bulb.station.cancel'].onClick();assert(not tool and not actionFn)
  widgets=draw();widgets['linnan.bulb.station.pick'].onClick();pick=selector()
  pick.onSelect(100,{});pick.onSelect(102,{})
  assert(not tool and draw()['linnan.bulb.station.chosen.b'].meta.tooltip:find('#102',1,true),
    'rapid clicks work without an intervening render and preserve same-name station identity')
  widgets=draw();widgets['linnan.bulb.station.pick'].onClick();pick=selector()
  window.param.onClose();assert(windowParam==nil and not tool and not actionFn,'closing the window releases the picker')
  before=calls;pick.onSelect(101,{});assert(calls==before)
  assert(stationInventories==1,'map picking and HUD ticks never rescan the inventory')
  api.gui.genericRep.get=genericGet
  aliases=previousAliases
end
-- Charles de Gaulle example: one M icon for 1/6, then a separate RER A row.
snapshot.lines=nil;snapshot.next=2;snapshot.passed=1
snapshot.route={lineId=900,name='示例电车 · 同类换乘并列',mode='TRAM',color='#006db8',stops={
  {name='戴高乐站',transfers={{id=20,name='RER A',mode='TRAIN',color='#ed1c2a'},
    {id=6,name='地铁六号线',mode='TRAIN',color='#72c695'},
    {id=1,name='地铁一号线',mode='TRAM',color='#ffcd02'}}},
  {name='下一站',transfers={{id=6,name='地铁六号线',mode='TRAIN',color='#72c695'},
    {id=1,name='地铁一号线',mode='TRAM',color='#ffcd02'}}}}}
aliases={__options={flashNextStop=true},['900']={name=snapshot.route.name,shortName='T1'},
  ['20']={name='RER A',shortName='A',displayMode='RER'},
  ['6']={name='地铁六号线',shortName='6',displayMode='METRO'},
  ['1']={name='地铁一号线',shortName='1',displayMode='METRO'}}
tick();tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
walk(tree,function(kind,param)if kind=='Component' and param.meta.id=='linnan.bulb.canvas'then canvas=param end end)
local grouped={}
local cw,ch=table.unpack(canvas.meta.styleSheet.size)
for _,child in ipairs(canvas.layout.param.children)do
  local pos=child.param
  if pos.item.kind=='Component' and pos.item.param.meta.class=='bulb-transfer-group'then
    grouped[#grouped+1]={x=pos.h*cw,y=pos.v*ch,param=pos.item.param}
  end
end
assert(#grouped==3,'two metro lines share one row at each station; RER uses a separate row')
assert(grouped[1].param.meta.styleSheet.size[1]==76 and grouped[2].param.meta.styleSheet.size[1]==47)
assert(math.abs(grouped[1].x+9-24)<.001 and grouped[1].x==grouped[2].x,
  'mode icons align vertically on the station connector, independent of badge count')
assert(math.abs(grouped[2].y-grouped[1].y-28)<.001 and grouped[3].y==grouped[1].y)
local icons,metroLabels=0,{}
walk(grouped[1].param,function(kind,param)
  if kind=='Component' and param.meta.class=='bulb-mode-icon'then icons=icons+1 end
  if kind=='TextView' and param.meta.class=='bulb-transfer-label'then metroLabels[param.text]=true end
end)
assert(icons==1 and metroLabels['1'] and metroLabels['6'],'HUD must render M 1 6 with a shared icon')
local groupFixed=false
for _,rule in ipairs(css)do
  if rule.selector=='FloatingLayout!bulb-fixed-layout'then
    groupFixed=rule.style.gravity[1]==0 and rule.style.gravity[2]==0
  end
end
local groupExtent=grouped[1].param.layout.param.children[1].param.item.param
assert(groupFixed and groupExtent.meta.class=='bulb-layout-extent' and groupExtent.mouseTransparent==true
  and groupExtent.meta.styleSheet.size[1]==76 and groupExtent.meta.styleSheet.size[2]==24,
  'group floating layout must measure and retain its explicitly reserved bounds')
for _,mode in ipairs({'METRO','RER','TRAM'})do
  snapshot.route={lineId=900,name='实际完整线路名称 '..mode,mode=mode,color='#006db8',stops={
    {name='起点',transfers={}},{name='普通站',transfers={}},
    {name='换乘站',transfers={{id=6,name='地铁六号线',mode='TRAIN',color='#72c695'}}},
    {name='未来站',transfers={}},{name='终点',transfers={}}}}
  aliases['900']={name=snapshot.route.name,shortName=mode=='TRAM' and 'T4' or mode=='RER' and 'B' or '1'}
  snapshot.next=3;snapshot.passed=0;tick()
  render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  contexts.LinnanBulbFlashingStationNative[1]:set(false)
  tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  walk(tree,function(kind,param)if kind=='Component' and param.meta.id=='linnan.bulb.canvas'then canvas=param end end)
  local track,stripes,markers=nil,0,{}
  for _,child in ipairs(canvas.layout.param.children)do
    local node=child.param.item
    if node.kind=='Component'then
      local class=node.param.meta.class
      if class=='bulb-track'then track=node.param.meta.styleSheet end
      if class=='bulb-track-stripe'then stripes=stripes+1 end
      if class=='bulb-station-marker'then markers[#markers+1]=node.param end
    end
  end
  local expectedRail=mode=='METRO' and 6 or mode=='RER' and 18 or 8
  local expectedDot=mode=='METRO' and 18 or mode=='RER' and 10 or 14
  assert(track.size[2]==expectedRail and #markers==5)
  assert(stripes==(mode=='TRAM' and 1 or 0),'only the tram uses a contrasting center stripe')
  assert(markers[2].meta.styleSheet.size[1]==expectedDot)
  local function layers(marker)
    local result={}
    walk(marker,function(kind,param)
      if (kind=='ImageView' or kind=='Component') and param.meta.class~='bulb-station-marker'then
        local s=param.meta.styleSheet
        result[param.meta.class]={color=s.color or s.backgroundColor,kind=kind,path=param.path}
      end
    end)
    return result
  end
  local ordinary=layers(markers[2])
  assert(not ordinary['bulb-station-outline'],'ordinary stops have no interchange outline')
  local fill=ordinary['bulb-station-fill'].color
  assert(fill[1]==1 and fill[2]==1 and fill[3]==1 and fill[4]==1,
    'passed ordinary stations must paint white, independent of the line color')
  local interchange=layers(markers[3])
  assert(interchange['bulb-station-outline'] and interchange['bulb-station-fill']
    and not interchange['bulb-station-light'] and interchange['bulb-station-fill'].color[1]==1)
  assert(interchange['bulb-station-outline'].path:match('/station%-outline.tga$')
    and interchange['bulb-station-fill'].path:match('/circle.tga$'),'interchanges retain their original circular rings')
  local terminus=layers(markers[1])
  assert(terminus['bulb-station-outline'] and terminus['bulb-station-interior'] and terminus['bulb-station-fill'],
    'terminus retains its center and original circular rings')
  local core=terminus['bulb-station-fill'].color
  assert(core[1]==1 and core[2]==1 and core[3]==1 and core[4]==1,
    'the passed origin core must paint white rather than the line color')
  assert(terminus['bulb-station-outline'].kind=='ImageView'
    and terminus['bulb-station-outline'].path:match('/station%-outline.tga$')
    and terminus['bulb-station-interior'].path:match('/station%-interior.tga$')
    and terminus['bulb-station-fill'].path:match('/circle.tga$'),
    'only the terminal name box changes shape; terminal station dots remain circular')
  contexts.LinnanBulbFlashingStationNative[1]:set(true)
  local flashing=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  local flashingInterchange
  walk(flashing,function(kind,param)
    if kind=='Component' and param.meta.class=='bulb-station-marker' and param.meta.tooltip=='换乘站'then
      flashingInterchange=layers(param)
    end
  end)
  assert(flashingInterchange['bulb-station-outline'] and flashingInterchange['bulb-station-light'],
    'a blinking interchange retains its structural black rim')
  -- Reflow the same native components, rather than checking only formulas.
  for _,viewport in ipairs({{x=320,y=240},{x=640,y=360},{x=1280,y=720},{x=1920,y=1080}})do
    local drawn=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport=viewport})
    for _,child in ipairs(drawn.param.children)do
      local pos=child.param
      local size=pos.item.param.meta.styleSheet.size
      local anchor=pos.item.param.meta.styleSheet.anchorPoint
      local left,top=pos.h*viewport.x-anchor[1]*size[1],pos.v*viewport.y-anchor[2]*size[2]
      assert(left>=0 and left+size[1]<=viewport.x and top>=0 and top+size[2]<=viewport.y,
        'identity and bottom diagram fit the viewport after GUI scale changes')
      if pos.item.param.meta.id=='linnan.bulb.canvas'then
        assert(math.abs(left+size[1]/2-viewport.x/2)<.001 and math.abs(top+size[2]-(viewport.y-32))<.001)
      end
    end
  end
end
-- Exit with a pending read, then immediately enter a different vehicle.
-- No hidden-component timer is allowed to wake or reveal the old route.
do
  local priorRead=collect.read
  local fresh={vehicle=201,next=2,passed=1,route={lineId=201,name='新车辆线路',mode='TRAM',color='#006db8',stops={
    {name='起点',transfers={}},{name='终点',transfers={}}}}}
  timers.LinnanBulbCockpitHudNative()
  free.FreeCamTool.pop()
  assert(hudVisible==false)
  collect.read=function(vehicle)
    assert(phase=='join' and vehicle==201,'pending reads must use the current vehicle')
    return fresh
  end
  free.FreeCamTool.push({}, {cockpitCameraForEntity=201})
  assert(hudVisible==false,'rapid entry cannot reveal stale route pixels')
  join()
  assert(hudVisible==true and contexts.LinnanBulbCockpitHudNative[1]:old()==fresh,
    'entry must reveal freshly collected data without a visible HUD timer')
  unmounts.LinnanBulbCockpitHudNative()
  free.FreeCamTool.pop();free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
  assert(#joins==1,'only the visible parent may queue bounds work after the HUD is unmounted')
  local priorState=contexts.LinnanBulbCockpitHudNative[1]:old()
  join()
  assert(contexts.LinnanBulbCockpitHudNative[1]:old()==priorState,'unmounted HUD cannot retain a camera-entry callback')
  collect.read=priorRead
  mounts.LinnanBulbCockpitHudNative();join()
end
-- A BUS interchange is one group even when its line badges wrap.
do
  aliases={__options={language='zh'},};snapshot.lines=nil;snapshot.next=2;snapshot.passed=1
  local transfers={}
  for i=1,4 do transfers[i]={id=1000+i,name=tostring(1000+i),mode='BUS',color='#ffcc00'}end
  transfers[5]={id=2100,name='F1',mode='BOAT',color='#00a077'}
  snapshot.route={lineId=900,name='公交换乘换行',mode='TRAM',color='#006db8',stops={
    {name='换乘站',transfers=transfers},{name='终点',transfers={}}}}
  tick();local drawn=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  local panel
  walk(drawn,function(kind,p)if kind=='Component' and p.meta.id=='linnan.bulb.canvas'then panel=p end end)
  local groups={}
  local pw,ph=table.unpack(panel.meta.styleSheet.size)
  for _,child in ipairs(panel.layout.param.children)do
    local pos=child.param
    if pos.item.kind=='Component' and pos.item.param.meta.class=='bulb-transfer-group'then
      groups[#groups+1]={y=pos.v*ph,param=pos.item.param}
    end
  end
  assert(#groups==2,'four buses must share one wrapped BUS group, followed by the separate ferry group')
  local buses=groups[1].param;local icons=0;local labels={}
  walk(buses,function(kind,p)if kind=='Component' and p.meta.class=='bulb-mode-icon'then icons=icons+1 end end)
  local bw,bh=table.unpack(buses.meta.styleSheet.size)
  for _,child in ipairs(buses.layout.param.children)do
    local pos=child.param
    if pos.item.kind=='TextView' and pos.item.param.meta.class=='bulb-transfer-label'then
      labels[pos.item.param.text]={x=pos.h*bw,y=pos.v*bh}
    end
  end
  assert(icons==1 and labels['1001'] and labels['1002'] and labels['1003'] and labels['1004'],
    'all four bus numbers must be served by a single BUS icon')
  assert(math.abs(labels['1004'].x-labels['1001'].x)<.001,'continuation aligns with the first badge column')
  assert(labels['1002'].y==labels['1001'].y and labels['1003'].y==labels['1001'].y)
  local step=labels['1004'].y-labels['1001'].y
  assert(step>15.3 and step<28,'BUS continuation rows must be tighter than separate-mode rows without overlapping')
  assert(groups[2].y>=groups[1].y+bh+4,'a following transport mode must clear the entire wrapped BUS group')
  assert(groups[2].y+groups[2].param.meta.styleSheet.size[2]<=ph,
    'canvas height must include compact continuation rows and following modes')
end
-- Flashing is opt-in. No animation recipe/timer exists while disabled.
do
  aliases={__options={language='zh'},};snapshot.lines=nil;snapshot.next=2;snapshot.passed=1
  snapshot.route={lineId=900,name='开关测试',mode='TRAM',color='#006db8',stops={
    {name='起点',transfers={}},{name='终点',transfers={}}}}
  tick();local drawn=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  assert(not timers.LinnanBulbFlashingStationNative,'default OFF must not mount an animation timer')
  local function lit(tree)
    local count=0;walk(tree,function(k,p)if p.meta and p.meta.class=='bulb-station-light'then count=count+1 end end)
    return count
  end
  assert(lit(drawn)==1,'only the next station is steady yellow when flashing is off')
  local nextLayers={}
  walk(drawn,function(kind,p)
    if kind=='Component' and p.meta.class=='bulb-station-marker' and p.meta.tooltip=='终点'then
      for _,child in ipairs(p.layout.param.children)do
        local image=child.param.item.param
        nextLayers[image.path:match('([^/]+)$')]=image.meta.styleSheet
      end
    end
  end)
  assert(nextLayers['station-interior.tga'].color[2]==.82
    and nextLayers['circle.tga'].color[2]==.82,
    'steady yellow must cover the normal terminus collar and core, not just its tiny center')
  assert(nextLayers['station-outline.tga'].color[1]==0,
    'steady yellow preserves the terminus black outline')
  for i=1,8 do tick()end
  assert(lit(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}}))==1)
  local optionsWrites,requests=0,{}
  local staleAliases=aliases
  local readOptions=modules['aliases.lua'].read
  modules['aliases.lua'].read=function()aliasReads=aliasReads+1;return staleAliases,0 end
  modules['aliases.lua'].saveOptions=function(value,callback)
    optionsWrites=optionsWrites+1;requests[#requests+1]={value=value,callback=callback}
  end
  contexts.LinnanBulbSettingsContentNative={}
  local params={aliases=aliasState,lines={},viewport={x=1280,y=720},geometry=S.geometry({x=1280,y=720}),color=settingsParam.color}
  local function drawFlash()
    local control,flashTexts
    flashTexts=0
    walk(render('LinnanBulbSettingsContentNative',params),function(k,p)
      if p.meta and p.meta.id=='linnan.bulb.settings.flash'then control=p end
      if k=='TextView' and p.text:find('闪烁',1,true)then flashTexts=flashTexts+1 end
    end)
    assert(control and flashTexts==1 and control.meta.tooltip==nil,
      'flash setting shows only its name and on/off state, without auxiliary text or tooltip')
    return control
  end
  local toggle=drawFlash()
  assert(toggle.value==0 and toggle.content.param.text=='黄灯闪烁：关闭','default OFF')
  local readsBefore=aliasReads
  toggle.onValueChange(1)
  local applying=drawFlash()
  assert(applying.value==1 and applying.content.param.text=='黄灯闪烁：开启',
    'the first click must change both native toggle value and caption before the save callback')
  assert(applying.meta.enabled==false,'disable the control while its save is in flight')
  toggle.onValueChange(1);assert(optionsWrites==1,'rapid clicks cannot submit the same pending toggle twice')
  local caption=applying.content.param
  assert(caption.meta.class=='font-scale-body' and caption.useUnicodeCompatibilityFont==false
    and not caption.meta.styleSheet.fontSize,'use the same native scaled locale font as official controls')
  local flashRule
  for _,rule in ipairs(css)do if rule.selector=='ToggleButton!bulb-settings-flash'then flashRule=rule.style end end
  assert(flashRule and flashRule.padding[1]==4 and flashRule.padding[2]==8
    and flashRule.gravity[1]==.5,'toggle padding and centered caption must match native button metrics')
  aliases['unchanged']={name='并发编辑',identifier='9'}
  requests[1].callback(nil,true);join()
  assert(optionsWrites==1 and aliases.__options.flashNextStop and aliases.unchanged.identifier=='9',
    'acknowledged toggle must merge into current aliases, even when engine reads lag behind')
  assert(aliasReads==readsBefore,'save acknowledgment must not read back a stale game-script snapshot')
  toggle=drawFlash();assert(toggle.value==1 and toggle.meta.enabled==true)
  render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  assert(timers.LinnanBulbFlashingStationNative,'enabling mounts only the isolated next-station animation')
  toggle.onValueChange(0);assert(drawFlash().value==0,'turn OFF on the first click too')
  requests[2].callback(nil,false);join()
  toggle=drawFlash();assert(toggle.value==1 and toggle.content.param.text=='黄灯闪烁：开启'
    and toggle.meta.enabled==true and aliases.__options.flashNextStop,'failed save rolls back the caption and unlocks the control')
  toggle.onValueChange(0);requests[3].callback(nil,true);join()
  toggle=drawFlash();assert(toggle.value==0 and toggle.content.param.text=='黄灯闪烁：关闭')
  render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
  assert(not timers.LinnanBulbFlashingStationNative,'disabling must unmount the animation immediately')
  local saveOptions=modules['aliases.lua'].saveOptions
  modules['aliases.lua'].saveOptions=function()error('simulated command submission failure')end
  toggle.onValueChange(1)
  toggle=drawFlash()
  assert(toggle.value==0 and toggle.meta.enabled==true and not aliases.__options.flashNextStop,
    'synchronous submission failure must roll back and release the toggle too')
  modules['aliases.lua'].saveOptions=saveOptions
  toggle.onValueChange(1)
  for _,state in ipairs(contexts.LinnanBulbSettingsContentNative)do state.expired=true end
  requests[4].callback(nil,true);join()
  assert(aliases.__options.flashNextStop,'closing settings must not discard an acknowledged option')
  modules['aliases.lua'].read=readOptions
end
print('native layouts, restricted timer/main-thread join, HUD, blink, counted omissions, UTF-8 and alias save cases passed')
