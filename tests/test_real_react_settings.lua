-- Run from the bundle directory, passing the installed build's extracted
-- gui/main/react.lua. It is intentionally not redistributed with the mod.
-- Execute the real metadata/wrapper code; only C++ nodes and hooks are mocked.
local reactPath=assert(arg[1],'usage: lua tests/test_real_react_settings.lua /path/to/game/react.lua')
local nodes,names,nextNode,nextRecipe={},{[1]='WithComponentParams',[39]='Window'},0,1000
_react={builtin={WithComponentParams=1,Window=39},recipes={},recipeMetas={},
  originalRecipeFn={},recipeReplace={},extensionPoints={},tools={},recipeReplacementAllowed=true}
log={verbose=function()end,warning=function(m)error(m)end,error=function(m)error(m)end}
api={gui={react={detail={makeRecipeId=function(name)
  nextRecipe=nextRecipe+1;names[nextRecipe]=name;return nextRecipe
end,IAHandle={new=function()return {}end}},params={builtin={}},fireEvent=function()end}}}
local builtinNames={'Window','BoxLayout','FloatingLayout','FloatingLayoutChild','ImageView','ToggleButton','Component','TextView','Button','ComboBox','ComboBoxItem','TextInputField',
  'Slider','ScrollArea','ActionDescriptor','Selector','HudIconManagerConfig','UseDefaultHudIcon'}
local userdataNames={'WithComponentParams'}
for _,name in ipairs(builtinNames)do userdataNames[#userdataNames+1]=name end
for _,name in ipairs(userdataNames) do
  api.gui.react.params.builtin[name]={new=function()return {}end}
  if not _react.builtin[name] then
    nextRecipe=nextRecipe+1;_react.builtin[name]=nextRecipe;names[nextRecipe]=name
  end
end
local defaultRequire=require
require=function(path)
  if path=='/scripts/string_util.tl' then return {format=function(s)return s end} end
  return defaultRequire(path)
end
ug_require=function(path)assert(path=='/scripts/util.tl',path);return {}end
local react=dofile(reactPath)
require=defaultRequire
local builtin={type={ImageViewScaling={AutoFit='auto-fit',Stretch='stretch'},Orientation={Horizontal=0,Vertical=1},
  ScrollBarPolicy={AlwaysOff=0,AsNeeded=1}}}
for _,name in ipairs(builtinNames) do
  builtin[name]=react.DeclareBuiltinWithUserdata(name,function()end)
end
local function state(value,owner)
  local result={value=value,dependents={},old=function(self)return self.value end,get=function(self)return self.value end,
    getUnderlyingState=function(self)return self end,hasExpired=function()return false end}
  function result:set(v)
    if self.value==v then return end
    self.value=v;if owner then owner.dirty=true end
    for _,dependent in ipairs(self.dependents)do dependent:set(v)end
  end
  function result:transform(fn)self:set(fn(self.value))end
  return result
end
local function context()
  local ctx={states={},actions={},index=0,internals={}}
  function ctx:makeNodeWithProps(recipeId,key,props)
    nextNode=nextNode+1;nodes[nextNode]={recipeId=recipeId,props=props};return nextNode
  end
  function ctx:setResult(result)self.result=result end
  function ctx:declareState(value)
    self.index=self.index+1
    self.states[self.index]=self.states[self.index] or state(value,self)
    return self.states[self.index]
  end
  function ctx:declareStateLazy(initializer)
    self.index=self.index+1
    self.states[self.index]=self.states[self.index] or state(initializer(),self)
    return self.states[self.index]
  end
  function ctx:declareDependentState(source)
    self.index=self.index+1
    if not self.states[self.index]then
      local mirror=state(source:old(),self)
      self.states[self.index]=mirror;source.dependents[#source.dependents+1]=mirror
    end
    return self.states[self.index]
  end
  ctx.declareRef=ctx.declareState
  function ctx:onUnmount(fn)self.unmount=fn end
  function ctx:onMount(fn)self.mount=fn end
  function ctx:useComponentInternals()
    self.internals.setInputActionConfig=function(_,action,config)self.actions[action]=config end
    return self.internals
  end
  function ctx:checkRecipeMatch(nodeId,expected)
    local actual=assert(nodes[nodeId]).recipeId
    assert(actual==expected,'Wrapper recipe must return child: expected '..names[expected]
      ..', returned '..tostring(names[actual]))
    return true
  end
  return ctx
end
local function render(recipeId,param,ctx)
  ctx=ctx or context();ctx.index=0;ctx.dirty=false
  _react.recipes[recipeId](ctx,{props={param}})
  return nodes[assert(ctx.result[1])],ctx
end
local S=dofile('mod/content/gui/bulb_cockpit/settings.lua')
local windowFn,windowParam,closeCount
local wc={addSingletonWindow=function(fn,param)windowFn,windowParam=fn,param end,
  removeAllWindows=function(fn)
    if fn==windowFn then windowParam=nil;closeCount=(closeCount or 0)+1 end
  end}
local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local I=dofile('mod/content/gui/bulb_cockpit/localization.lua')
local citySettings=dofile('mod/content/gui/bulb_cockpit/city_settings.lua').create(react,builtin,
  function(value)return {styleSheet=value}end,{}, {getDefaultWindowApi=function()return wc end},P,I)
local mapTool,mapParam,mapCtx,mapAction
local mapStack={getActiveTool=function()return mapTool end}
function mapStack.push(def,key,param,stacking)
  assert(stacking and key=='linnan.bulb.station.pick')
  mapTool,mapParam=def,param
  mapCtx={setActionFn=function(fn)mapAction=fn end,popSelf=function()mapStack.pop(def,key)end}
  def.push(mapCtx,param)
end
function mapStack.pop(def)
  if def~=mapTool then return end
  local ctx,param=mapCtx,mapParam
  mapTool,mapParam,mapCtx,mapAction=nil,nil,nil,nil
  def.pop(ctx,param)
end
local stationSettings=dofile('mod/content/gui/bulb_cockpit/station_settings.lua').create(react,builtin,
  function(value)return {styleSheet=value}end,{}, {getDefaultWindowApi=function()return wc end,
    getDefaultToolStackApi=function()return mapStack end},P,
  {listStationGroups=function()return {{id=100,name='杭州站'},{id=101,name='站前公交'}}end,
    resolveStation=function(id)if id==100 or id==101 then return {id=id,name='站 '..id}end end},I)
local optionRequests={}
local optionStore={saveOptions=function(value,callback)optionRequests[#optionRequests+1]={value=value,callback=callback}end,
  read=function()error('a command acknowledgment must not read a stale GAME_SCRIPT component')end}
local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local function testStyle(value)return {styleSheet=value}end
local function testText(value,font,width,height,ink,fill,class)
  local meta=testStyle{size={width,height},fontSize=font,color=ink};meta.class=class
  return builtin.TextView{text=value,meta=meta}
end
local mark,group,badge=B.create(builtin,testStyle,testText,function()return builtin.Component{}end)
local nativeFilterUtility=dofile('tests/carrier_filter_fixture.lua')(builtin)
if arg[2]then
  local previous=ug_require
  local function copy(value)
    if type(value)~='table'then return value end
    local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
  end
  ug_require=function(path)
    if path:match('/builtin.lua$')then return builtin end
    if path:match('/react.lua$')then return react end
    if path:match('/table_util.tl$')then return {copy=copy}end
    return {}
  end
  nativeFilterUtility=assert(loadfile(arg[2]))()
  ug_require=previous
  -- Test the original carrier factory and callbacks with real React nodes;
  -- native focus navigation is outside this test's C++ boundary.
  nativeFilterUtility.createFocusBar=function(buttons)
    return builtin.BoxLayout{orientation=builtin.type.Orientation.Horizontal,children=buttons}
  end
end
local staticLoads=0
local presetEditor=dofile('mod/content/gui/bulb_cockpit/preset_settings.lua').create(react,builtin,testStyle,optionStore,I,B,
  dofile('mod/content/gui/bulb_cockpit/presets.lua'))
local Entry=S.create(react,builtin,testStyle,P,B,
  {listLines=function()return {{id=10,name='Tram 乘客-杭州-LO-1',mode='TRAM'}}end,
    readLine=function(id)
      staticLoads=staticLoads+1
      return {static=true,next=0,passed=0,lines={},route={lineId=id,name='Tram 乘客-杭州-LO-1',mode='TRAM',color='#006db8',stops={}}}
    end}, optionStore,
  {note=function()end},{getDefaultWindowApi=function()return wc end,
    getDefaultToolStackApi=function()return mapStack end},citySettings,stationSettings,
  {badge=badge,mark=mark,draw=function()
    return builtin.Component{meta=testStyle{size={1600,200}},layout=builtin.BoxLayout{children={testText('静态图',14,1600,200)}}}
  end},I,nativeFilterUtility,presetEditor)
local entryId=react.GetRecipeId(Entry)
local aliases=state({__options={language='zh'}})
local function toggleFrom(root)
  local wrapped=nodes[root.props.props[1].children[1]]
  assert(wrapped.recipeId==1,'toggle metadata should use WithComponentParams')
  local toggle=nodes[wrapped.props.props[1].item]
  assert(names[toggle.recipeId]=='ToggleButton')
  return toggle.props.props[1]
end
-- Exercise the real button callback and wrapper validation for both layouts.
for _,viewport in ipairs({{x=1280,y=720},{x=400,y=300}}) do
  local param={aliases=aliases,viewport=viewport,color=function()return {.1,.4,.8,1}end}
  local root,entryCtx=render(entryId,param)
  local toggle=toggleFrom(root)
  assert(toggle.value==0)
  toggle.onValueChange(1)
  assert(windowFn and windowParam and #windowParam.lines==1)
  local window,windowCtx=render(react.GetRecipeId(windowFn),windowParam)
  assert(window.recipeId==39,'wrapper must return the direct native Window')
  assert(window.props.style.class=='bulb-settings-window')
  assert(window.props.props[1].content and window.props.props[1].closable)
  assert(window.props.props[1].id=='linnan.bulb.settings.window')
  -- Width belongs to the sized content, not a metadata layout around Window.
  local content=nodes[window.props.props[1].content].props.props[1]
  assert(content.geometry.content+24==S.geometry(viewport).width)
  local browserNode=nodes[window.props.props[1].content]
  assert(names[browserNode.recipeId]=='LinnanBulbBrowserNative','directory is the first settings page')
  local firstNode=nextNode
  local _,browserCtx=render(browserNode.recipeId,content)
  local lineButton,lineButtonMeta,cityButton,configButton
  for id,node in pairs(nodes)do
    if id>firstNode and node.recipeId==1 and node.props.props[1].id=='linnan.bulb.browser.line.10' then
      lineButtonMeta=node.props.props[1]
      lineButton=nodes[lineButtonMeta.item].props.props[1]
    end
    if id>firstNode and node.recipeId==1 then
      local meta=node.props.props[1]
      if meta.id=='linnan.bulb.settings.city'then
        cityButton=nodes[meta.item];assert(names[cityButton.recipeId]=='Button')
      elseif meta.id=='linnan.bulb.browser.configure'then configButton=nodes[meta.item]end
    end
  end
  assert(not cityButton and configButton,'directory home links to the line settings subpage')
  local configCaption=nodes[nodes[configButton.props.props[1].content].props.props[1].item]
  assert(configCaption.props.props[1].text=='线路设置')
  assert(lineButton and type(lineButton.onClick)=='function')
  assert(lineButtonMeta.styleSheet.size[1]==44 and lineButtonMeta.styleSheet.size[2]==32)
  local badgeNode=nodes[lineButton.content]
  assert(badgeNode.recipeId==1,'native badge anchor must survive WithComponentParams conversion')
  local badgeStyle=badgeNode.props.props[1].styleSheet
  assert(badgeStyle.size[1]==24 and badgeStyle.size[2]==24)
  assert(badgeStyle.anchorPoint[1]==.5 and badgeStyle.anchorPoint[2]==.5,
    'native button content must center on its hit target, independently of its internal mask anchors')
  local badgeComponent=nodes[badgeNode.props.props[1].item]
  local badgeLayout=nodes[badgeComponent.props.props[1].layout]
  assert(names[badgeLayout.recipeId]=='FloatingLayout' and badgeLayout.props.style.class=='bulb-fixed-layout',
    'class-only internal layout must stay a native Layout without a Component metadata wrapper')
  lineButton.onClick()
  firstNode=nextNode;render(browserNode.recipeId,content,browserCtx)
  local staticNode
  for id,node in pairs(nodes)do if id>firstNode and names[node.recipeId]=='LinnanBulbStaticRouteNative'then staticNode=node end end
  assert(staticNode,'selected line gets its own keyed child recipe')
  firstNode=nextNode
  local _,staticCtx=render(staticNode.recipeId,staticNode.props.props[1])
  staticCtx.mount();_reactDoExecuteJoins()
  firstNode=nextNode;render(staticNode.recipeId,staticNode.props.props[1],staticCtx)
  local scroll,back,pin,pinMeta
  local measuredHeader=false
  for id,node in pairs(nodes)do if id>firstNode then
    if names[node.recipeId]=='ScrollArea'then scroll=node end
    if node.recipeId==1 and node.props.props[1].id=='linnan.bulb.browser.back'then back=nodes[node.props.props[1].item].props.props[1]end
    if node.recipeId==1 and node.props.props[1].id=='linnan.bulb.browser.locate'then
      pinMeta=node.props.props[1];pin=nodes[pinMeta.item].props.props[1]
    end
    if names[node.recipeId]=='Component' and node.props.style and node.props.style.class=='bulb-mode-mark'then
      local layout=nodes[node.props.props[1].layout]
      assert(names[layout.recipeId]=='FloatingLayout' and layout.props.style.class=='bulb-fixed-layout')
      local firstChild=nodes[layout.props.props[1].children[1]]
      assert(names[firstChild.recipeId]=='FloatingLayoutChild')
      local extent=nodes[firstChild.props.props[1].item]
      assert(extent.recipeId==1)
      local bounds=extent.props.props[1].styleSheet.size
      assert(bounds[1]==70 and bounds[2]==38,'full header mark must measure both the mode icon and badge')
      local extentComponent=nodes[extent.props.props[1].item]
      assert(names[extentComponent.recipeId]=='Component' and extentComponent.props.props[1].mouseTransparent==true)
      measuredHeader=true
    end
  end end
  assert(scroll and back and pin and measuredHeader,'static page and fixed header convert through actual game React')
  assert(pinMeta.enabled and pinMeta.styleSheet.size[1]==24 and pinMeta.styleSheet.size[2]==24)
  local imageMeta=nodes[pin.content].props.props[1]
  local image=nodes[imageMeta.item]
  assert(names[image.recipeId]=='ImageView' and image.props.props[1].path=='::/gui/line_vehicle_mgmt/icons/symbol_locate_20.tga')
  assert(imageMeta.styleSheet.size[1]==20 and imageMeta.styleSheet.anchorPoint[1]==.5)
  assert(type(staticNode.props.props[1].onClose)=='function','browser must pass window close to the static pin')
  local scrollContent=nodes[scroll.props.props[1].content]
  assert(scrollContent.recipeId==1 and names[nodes[scrollContent.props.props[1].item].recipeId]=='Component',
    'ScrollArea receives Component metadata, never a Layout')
  back.onClick()
  assert(staticCtx.states[1]:get().snapshot==nil,'return releases snapshot before native unmount')
  staticCtx.unmount();browserCtx.unmount()
  root=render(entryId,param,entryCtx);assert(toggleFrom(root).value==1)
  windowCtx.actions.IA_MENU_BACK.handlerFn()
  assert(windowParam==nil and closeCount)
  root=render(entryId,param,entryCtx);assert(toggleFrom(root).value==0)
  toggleFrom(root).onValueChange(1)
  entryCtx.unmount();assert(windowParam==nil)
  citySettings.open{aliases=aliases,viewport=viewport,lines={},towns={}}
  local cityWindow,cityCtx=render(react.GetRecipeId(windowFn),windowParam)
  assert(cityWindow.recipeId==39 and cityWindow.props.props[1].id=='linnan.bulb.city.window',
    'batch naming must return the direct native Window as well')
  local cityContent=nodes[cityWindow.props.props[1].content]
  firstNode=nextNode;render(cityContent.recipeId,cityContent.props.props[1])
  local cityToggle
  for id,node in pairs(nodes)do if id>firstNode then
    assert(names[node.recipeId]~='ComboBox','bus enablement must not use a dropdown')
    if node.recipeId==1 and node.props.props[1].id=='linnan.bulb.city.enabled'then
      cityToggle=nodes[node.props.props[1].item]
    end
  end end
  assert(cityToggle and names[cityToggle.recipeId]=='ToggleButton' and cityToggle.props.props[1].value==0)
  cityCtx.actions.IA_MENU_BACK.handlerFn();assert(windowParam==nil)
  stationSettings.open{aliases=aliases,viewport=viewport}
  local stationWindow,stationCtx=render(react.GetRecipeId(windowFn),windowParam)
  assert(stationWindow.recipeId==39 and stationWindow.props.props[1].id=='linnan.bulb.station.window',
    'station association settings must return a direct native Window')
  assert(#windowParam.stations==2)
  stationCtx.actions.IA_BACK.handlerFn();assert(windowParam==nil)
  stationSettings.open{aliases=aliases,viewport=viewport};stationSettings.close();assert(windowParam==nil)
end
-- Click the pin after conversion through the real React parameter adapter.
do
  local located,closed=0,0
  api.type={ComponentType={LINE=1}}
  api.engine={entityExists=function(id)return id==10 end,getComponent=function(id,kind)
    assert(id==10 and kind==1);return {}
  end}
  api.gui.camera={followEntity=function(id,animate)assert(id==10 and animate);located=located+1 end}
  local staticId
  for id,name in pairs(names)do if name=='LinnanBulbStaticRouteNative'then staticId=id end end
  local ctx=context()
  local param={lineId=10,aliases=aliases,lines={},geometry=S.geometry({x=1280,y=720}),viewport={x=1280,y=720},
    color=function()return {.1,.4,.8,1}end,onReady=function()end,home=function()end,navigate=function()end,
    onClose=function()assert(ctx.states[1]:get().snapshot==nil);closed=closed+1 end}
  render(staticId,param,ctx);ctx.mount();_reactDoExecuteJoins()
  local first=nextNode;render(staticId,param,ctx)
  local pin
  for id,node in pairs(nodes)do
    if id>first and node.recipeId==1 and node.props.props[1].id=='linnan.bulb.browser.locate'then
      pin=nodes[node.props.props[1].item].props.props[1]
    end
  end
  assert(pin);pin.onClick();pin.onClick()
  assert(located==1 and closed==1,'native callback locates once and releases the full diagram before closing')
  ctx.unmount()
end
-- Convert the map picker with the actual game's Lua node/metadata rules.
api.type={ComponentType={STATION_GROUP=1},Vec4f={new=function(...)return {...}end}}
api.gui.genericRep={find=function()return 1 end,get=function()return {data={default={
  selectionColor={1,1,1,1},selectionOutlineColor={1,1,1,1},selectionCircleColor={1,1,1,1},
  crosshairColor={1,1,1,1}}}}end}
ug_require=function(path)
  assert(path=='::/gui/hud/hud_react_util.tl',path)
  return {makeDefaultVisibilityThresholds=function()return {}end}
end
stationSettings.open{aliases=aliases,viewport={x=1280,y=720}}
local stationWindow=render(react.GetRecipeId(windowFn),windowParam)
local contentNode=nodes[stationWindow.props.props[1].content]
local lowerBound=nextNode
local _,contentCtx=render(contentNode.recipeId,contentNode.props.props[1])
local function control(id)
  local found,foundId
  for nodeId,node in pairs(nodes)do
    local props=node.props.props[1]
    if nodeId>lowerBound and node.recipeId==1 and props.id==id and (not foundId or nodeId>foundId)then
      found,foundId={meta=props,params=nodes[props.item].props.props[1]},nodeId
    end
  end
  return assert(found,'missing native control '..id)
end
assert(control('linnan.bulb.station.add').meta.enabled==false)
control('linnan.bulb.station.pick').params.onClick()
assert(mapTool and mapAction)
local Action=react.RegisterRecipe('TestStationPickAction',function()return assert(mapAction)()end)
local action=render(react.GetRecipeId(Action),{})
assert(names[action.recipeId]=='ActionDescriptor')
local children=action.props.props[1].children
local icons,selector=nodes[children[1]],nodes[children[2]]
assert(names[icons.recipeId]=='HudIconManagerConfig' and names[selector.recipeId]=='Selector')
assert(icons.props.props[1].visibilityThresholds.cameraHeightLowerCutoff==0)
assert(icons.props.props[1].preFilter[1]==api.type.ComponentType.STATION_GROUP)
local callback=selector.props.props[1].onSelect
assert(callback(100,{},nil) and callback(101,{},nil),'two map clicks must work before a rerender')
assert(mapTool==nil and mapAction==nil,'completed pick must release the tool')
render(contentNode.recipeId,contentNode.props.props[1],contentCtx)
assert(control('linnan.bulb.station.add').meta.enabled==true)
assert(control('linnan.bulb.station.chosen.a').params.text=='① #100 站 100')
assert(control('linnan.bulb.station.chosen.b').params.text=='② #101 站 101')
stationSettings.close();contentCtx.unmount()
assert(windowParam==nil and mapTool==nil)
-- Build the actual settings content through the game's Lua React adapter.
-- Pending C++ command completion must not delay the controlled toggle/caption.
local contentId,browserId
for id,name in pairs(names)do
  if name=='LinnanBulbSettingsContentNative'then contentId=id end
  if name=='LinnanBulbBrowserNative'then browserId=id end
end
assert(contentId and browserId)
local flashAliases=state({__options={flashNextStop=false,otherOption=true,language='zh'}})
local flashParam={aliases=flashAliases,lines={},viewport={x=1280,y=720},geometry=S.geometry({x=1280,y=720}),color=function()return {1,1,0,1}end}
local flashCtx=context()
local function drawFlash()
  lowerBound=nextNode
  render(contentId,flashParam,flashCtx)
  local result=control('linnan.bulb.settings.flash')
  local captionMeta=nodes[result.params.content].props.props[1]
  result.caption=nodes[captionMeta.item].props.props[1]
  assert(result.caption.useUnicodeCompatibilityFont==false and result.meta.tooltip==nil)
  assert(control('linnan.bulb.settings.city'),'bus configuration belongs to the line settings subpage')
  return result
end
local first=drawFlash();assert(first.params.value==0 and first.caption.text=='黄灯闪烁：关闭')
first.params.onValueChange(1)
local pending=drawFlash()
assert(pending.params.value==1 and pending.caption.text=='黄灯闪烁：开启' and pending.meta.enabled==false)
first.params.onValueChange(1);assert(#optionRequests==1,'guard repeated input before a command finishes')
optionRequests[1].callback(nil,true);_reactDoExecuteJoins()
local enabled=drawFlash()
assert(enabled.params.value==1 and enabled.meta.enabled==true and flashAliases:old().__options.flashNextStop
  and flashAliases:old().__options.otherOption,'merge the acknowledged option into shared root state')
enabled.params.onValueChange(0)
assert(drawFlash().params.value==0)
optionRequests[2].callback(nil,false);_reactDoExecuteJoins()
assert(drawFlash().params.value==1,'restore the native toggle after a failed command')
-- Edit two rows, including one hidden by a name filter, then apply once.
-- Use the real game React metadata adapter and defer the engine callback.
do
  local requests={}
  optionStore.saveAll=function(changes,callback,defaults)
    requests[#requests+1]={changes=changes,callback=callback,defaults=defaults}
  end
  local roster={{id=10,name='电车甲',mode='TRAM'},{id=20,name='公交乙',mode='BUS'},
    {id=30,name='铁路丙',mode='TRAIN'}}
  local config=state({__options={language='zh'},['20']={name='公交乙',prefix='',identifier='1001',suffix='',displayMode='BUS'}})
  local param={aliases=config,lines=roster,geometry=S.geometry({x=1280,y=720}),
    color=function()return {1,.8,0,1}end}
  local ctx=context()
  local function drawEditor()
    lowerBound=nextNode;render(contentId,param,ctx)
    local rows={}
    for id,node in pairs(nodes)do
      if id>lowerBound and names[node.recipeId]=='LinnanBulbAliasRowNative'then
        rows[node.props.props[1].line.id]=node
      end
    end
    return rows
  end
  local function drawRow(node,rowCtx)
    lowerBound=nextNode
    local _,result=render(node.recipeId,node.props.props[1],rowCtx)
    return result
  end
  local rows=drawEditor()
  assert(control('linnan.bulb.settings.scope').params.value==2,'name search is the initial choice')
  local apply=control('linnan.bulb.settings.apply-all').params
  drawRow(rows[10]);assert(control('linnan.bulb.identifier.10').params.placeholderText=='1')
  local types=control('linnan.bulb.mode.10').params
  assert(#types.items==9 and types.value==4,'default tram selects its single actual type')
  local typeLabels={}
  for _,id in ipairs(types.items)do
    local item=nodes[id].props.props[1]
    local textMeta=nodes[item.content].props.props[1]
    local text=nodes[textMeta.item].props.props[1].text
    assert(not typeLabels[text],'native dropdown must not duplicate a type')
    typeLabels[text]=true
  end
  assert(typeLabels.RER and not typeLabels['火车 RER'],'railway and RER share one native option')
  local badgeFound=false
  for id,node in pairs(nodes)do
    if id>lowerBound and node.recipeId==1 then
      local props=node.props.props[1]
      local component=nodes[props.item]
      if component and names[component.recipeId]=='Component' and component.props.style
        and component.props.style.class=='bulb-line-tile' then
        badgeFound=true
        assert(props.styleSheet.anchorPoint[1]==.5 and props.styleSheet.anchorPoint[2]==.5,
          'badges use a center anchor in their dedicated fixed column')
      end
    end
  end
  assert(badgeFound,'automatic numbers have a route badge')
  drawRow(rows[20])
  local manualFound=false
  for id,node in pairs(nodes)do
    if id>lowerBound and names[node.recipeId]=='TextView' and node.props.props[1].text=='1001' then manualFound=true end
  end
  assert(manualFound,'manually assigned numbers have inline badges too')
  drawRow(rows[10])
  control('linnan.bulb.prefix.10').params.onTyping('T')
  control('linnan.bulb.identifier.10').params.onTyping('7')
  control('linnan.bulb.suffix.10').params.onTyping('b')
  drawEditor();control('linnan.bulb.settings.search').params.onTyping('公交')
  rows=drawEditor();assert(rows[20] and not rows[10])
  drawRow(rows[20]);control('linnan.bulb.identifier.20').params.onTyping('1002')
  drawEditor();apply=control('linnan.bulb.settings.apply-all').params
  apply.onClick();apply.onClick()
  assert(#requests==1 and #requests[1].changes==2,'apply all includes hidden drafts and ignores untouched rows')
  assert(requests[1].changes[1].shortName=='T7b' and requests[1].changes[2].shortName=='1002')
  assert(config:old()['10']==nil and config:old()['20'].identifier=='1001','wait for command acknowledgment')
  drawEditor();assert(control('linnan.bulb.settings.apply-all').meta.enabled==false)
  requests[1].callback(nil,false);_reactDoExecuteJoins()
  drawEditor();assert(control('linnan.bulb.settings.apply-all').meta.enabled==true)
  control('linnan.bulb.settings.apply-all').params.onClick()
  assert(#requests==2 and #requests[2].changes==2,'failure preserves both drafts for retry')
  config:old().__options={flashNextStop=true}
  requests[2].callback(nil,true);_reactDoExecuteJoins()
  assert(config:old()['10'].shortName=='T7b' and config:old()['20'].shortName=='1002'
    and config:old().__options.flashNextStop,'accepted edits preserve concurrent unrelated settings')
  drawEditor();control('linnan.bulb.settings.search').params.onTyping('T7b')
  control('linnan.bulb.settings.scope').params.onValueChange(1)
  rows=drawEditor();assert(rows[10] and not rows[20],'complete rendered badge is searchable in the actual native UI')
  drawRow(rows[10]);assert(control('linnan.bulb.identifier.10').params.value=='7','remount sees the applied draft')
  drawEditor();control('linnan.bulb.settings.apply-all').params.onClick()
  assert(#requests==2,'no changes means no new command')
  drawRow(rows[10]);control('linnan.bulb.identifier.10').params.onTyping('bad-1')
  drawEditor();control('linnan.bulb.settings.apply-all').params.onClick()
  assert(#requests==2,'invalid input blocks the entire submission')
  rows=drawEditor();drawRow(rows[10]);control('linnan.bulb.identifier.10').params.onTyping('8')
  drawEditor();control('linnan.bulb.settings.apply-all').params.onClick()
  assert(#requests==3)
  for _,localState in ipairs(ctx.states)do localState.hasExpired=function()return true end end
  requests[3].callback(nil,true);_reactDoExecuteJoins()
  assert(config:old()['10'].shortName=='T8b','closing the editor does not discard an accepted save')
end
print('PASS: actual game react.lua converts native settings, inline badges and bulk edits across filters, retry and confirmation')
-- The native wrapper and dependent content must switch on the first click.
do
  local config=state({__options={flashNextStop=true,language='zh'}})
  local viewport={x=400,y=600}
  local param={aliases=config,lines={},viewport=viewport,geometry=S.geometry(viewport),color=function()return {1,1,0,1}end,
    onClose=function()end,session={closed=false,lines={},owners={}}}
  local ctx=context()
  local function caption(ctrl)
    local content=ctrl.params.content
    if ctrl.params.items then
      for _,id in ipairs(ctrl.params.items)do
        local item=nodes[id].props.props[1]
        if item.value==ctrl.params.value then content=item.content end
      end
    end
    local node=nodes[content]
    if node.recipeId==1 then node=nodes[node.props.props[1].item]end
    return node.props.props[1]
  end
  local function draw()
    lowerBound=nextNode;render(browserId,param,ctx)
    return assert(control('linnan.bulb.browser.language'))
  end
  local windowId
  for id,name in pairs(names)do if name=='LinnanBulbSettingsWindowNative'then windowId=id end end
  local fresh=state({})
  local freshParam={};for key,value in pairs(param)do freshParam[key]=value end
  freshParam.aliases=fresh;freshParam.geometry=S.geometry(viewport,'en')
  local freshWindow=render(assert(windowId),freshParam)
  local freshEntry=render(entryId,freshParam)
  assert(freshWindow.props.props[1].title=='Route maps'
    and nodes[freshEntry.props.props[1].children[1]].props.props[1].tooltip=='Route maps',
    'first mount defaults to English for the existing window and entry')
  lowerBound=nextNode;render(browserId,freshParam)
  assert(caption(control('linnan.bulb.browser.language')).text=='English'
    and caption(control('linnan.bulb.browser.configure')).text=='Line settings'
    and fresh:old().__options==nil,'fresh directory is English without writing a preference')
  local window,windowCtx=render(assert(windowId),param)
  local entry,entryCtx=render(entryId,param)
  local function windowTitle()
    -- A parent does not re-render just because a foreign state was read.
    -- Only run contexts dirtied by their own/dependent state, as the engine does.
    if windowCtx.dirty then window=render(windowId,param,windowCtx)end
    assert(window.recipeId==39,'language updates retain the direct Window contract')
    return window.props.props[1].title
  end
  local function entryTooltip()
    if entryCtx.dirty then entry=render(entryId,param,entryCtx)end
    return nodes[entry.props.props[1].children[1]].props.props[1].tooltip
  end
  assert(windowTitle()=='线路图设置' and entryTooltip()=='线路图设置')
  local first=draw();assert(caption(first).text=='简体中文' and caption(first).useUnicodeCompatibilityFont)
  local before=#optionRequests
  first.params.onValueChange(1)
  local switched=draw()
  assert(caption(switched).text=='English' and switched.meta.enabled==false)
  assert(caption(control('linnan.bulb.browser.configure')).text=='Line settings')
  first.params.onValueChange(1);assert(#optionRequests==before+1)
  assert(optionRequests[#optionRequests].value.language=='en' and config:old().__options.flashNextStop)
  assert(windowTitle()=='Route maps','switching language must invalidate the existing window title')
  assert(entryTooltip()=='Route maps','the already-mounted entry tooltip must update without a click')
  optionRequests[#optionRequests].callback(nil,true);_reactDoExecuteJoins()
  local saved=draw();assert(saved.meta.enabled and config:old().__options.language=='en')
  saved.params.onValueChange(2);assert(config:old().__options.language=='zh')
  assert(windowTitle()=='线路图设置' and entryTooltip()=='线路图设置','switching back updates mounted text')
  optionRequests[#optionRequests].callback(nil,false);_reactDoExecuteJoins()
  assert(config:old().__options.language=='en' and caption(draw()).text=='English')
  assert(windowTitle()=='Route maps' and entryTooltip()=='Route maps','failed saves restore mounted text too')
  toggleFrom(entry).onValueChange(1)
  assert(entryTooltip()=='Close route maps','open entry uses the English close hint')
  -- English line-editor geometry includes a full-width narrow-screen search.
  local englishParam={};for k,v in pairs(param)do englishParam[k]=v end
  englishParam.geometry=S.geometry(viewport,'en')
  lowerBound=nextNode;render(contentId,englishParam,context())
  assert(control('linnan.bulb.settings.search').params.placeholderText=='Search name')
  assert(control('linnan.bulb.settings.search').meta.styleSheet.size[1]==englishParam.geometry.content-8)
  assert(caption(control('linnan.bulb.settings.flash')).text=='Blinking: On')
end
print('PASS: actual game React bilingual switch, direct Window title and narrow English controls')

-- Execute the same original factory used by the game's line manager.
do
  api.type={['enum']={Carrier={ROAD=1,TRAM=2,RAIL=3,WATER=4,AIR=5}}}
  local id
  for key,name in pairs(names)do if name=='LinnanBulbCarrierFilterNative'then id=key end end
  local filters=state({category={}})
  local param={state=filters,aliases=state({__options={language='en'}})}
  local ctx=context()
  local function toggles()
    lowerBound=nextNode;render(assert(id),param,ctx)
    local found={}
    for key=lowerBound+1,nextNode do
      if names[nodes[key].recipeId]=='ToggleButton'then found[#found+1]=nodes[key].props.props[1]end
    end
    return found
  end
  local buttons=toggles();assert(#buttons==5)
  buttons[1].onValueChange(1);assert(filters:old().category[1])
  buttons=toggles();assert(buttons[1].value==1 and buttons[2].value==0)
  buttons[3].onValueChange(1);assert(filters:old().category[1] and filters:old().category[3])
  buttons[1].onValueChange(0);assert(not filters:old().category[1] and filters:old().category[3])
  print('PASS: original carrier-filter factory, native ToggleButtons and multi-select callback contract')
end

-- Use the original React mouse-listener binding and native Slider recipe.
do
  local previousRequire=ug_require
  ug_require=function(path)
    local locale=path:match('/locales/([%w-]+)%.lua$')
    if locale then return dofile('mod/content/gui/bulb_cockpit/locales/'..locale..'.lua')end
    return previousRequire(path)
  end
  local scaleId
  for id,name in pairs(names)do if name=='LinnanBulbMapScaleNative'then scaleId=id end end
  api.gui.mouse={Event={Type={Pressed=1,Released=2}}}
  local config=state({__options={language='fr',flashNextStop=true}})
  local param={aliases=config,width=400,session={closed=false}}
  local ctx=context()
  local function draw()
    lowerBound=nextNode;render(assert(scaleId),param,ctx)
    return control('linnan.bulb.settings.scale')
  end
  local before=#optionRequests
  local slider=draw()
  assert(slider.params.min==10 and slider.params.max==400 and slider.params.step==1)
  ctx.internals.mouseListener({button=0,type=1})
  slider.params.onValueChange(173);slider.params.onValueChange(174)
  assert(#optionRequests==before and draw().params.value==174)
  ctx.internals.mouseListener({button=0,type=2})
  assert(#optionRequests==before+1 and not draw().meta.enabled)
  optionRequests[#optionRequests].callback(nil,true);_reactDoExecuteJoins()
  assert(config:old().__options.routeMapScale==174 and draw().meta.enabled)
  assert(config:old().__options.language=='fr' and config:old().__options.flashNextStop)
  control('linnan.bulb.settings.scale-reset').params.onClick()
  optionRequests[#optionRequests].callback(nil,true);_reactDoExecuteJoins()
  assert(draw().params.value==100 and config:old().__options.routeMapScale==100)
  ctx.unmount();ug_require=previousRequire
  print('PASS: original React Slider, mouse drag coalescing, option acknowledgment and reset')
end

-- Real native ComboBox metadata and dependent-state notification, including a
-- command acknowledged after the preset child unmounts.
do
  local previousRequire=ug_require
  ug_require=function(path)
    local locale=path:match('/locales/([%w-]+)%.lua$')
    if locale then return dofile('mod/content/gui/bulb_cockpit/locales/'..locale..'.lua')end
    return previousRequire(path)
  end
  local ctx=context()
  local config=state({__options={language='fr',routeMapScale=137}})
  local param={aliases=config,width=400,height=400,session={closed=false}}
  local id=react.GetRecipeId(presetEditor)
  local function draw()
    lowerBound=nextNode;render(id,param,ctx)
    return control('linnan.bulb.presets.metro')
  end
  local before=#optionRequests
  assert(draw().params.value==1)
  control('linnan.bulb.presets.all').params.onValueChange(3)
  assert(#optionRequests==before+1 and draw().params.value==2 and not draw().meta.enabled)
  config:transform(function(latest)latest.__options.language='de';return latest end)
  optionRequests[#optionRequests].callback(nil,true);_reactDoExecuteJoins()
  assert(draw().meta.enabled and config:old().__options.linePresets.TRAM=='paris')
  draw().params.onValueChange(4)
  param.session.closed=true
  for _,item in pairs(ctx.states)do item.hasExpired=function()return true end end
  optionRequests[#optionRequests].callback(nil,true);_reactDoExecuteJoins()
  assert(config:old().__options.linePresets.METRO=='munich' and config:old().__options.linePresets.TRAM=='paris')
  assert(config:old().__options.routeMapScale==137 and config:old().__options.language=='de')
  ug_require=previousRequire
  print('PASS: original React ComboBox metadata, global/per-mode preset persistence and late acknowledgment')
end
