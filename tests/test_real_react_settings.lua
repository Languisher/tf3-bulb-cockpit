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
  'ScrollArea','ActionDescriptor','Selector','HudIconManagerConfig','UseDefaultHudIcon'}
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
local function state(value)
  return {value=value,old=function(self)return self.value end,get=function(self)return self.value end,set=function(self,v)self.value=v end,
    transform=function(self,fn)self.value=fn(self.value)end,hasExpired=function()return false end}
end
local function context()
  local ctx={states={},actions={},index=0}
  function ctx:makeNodeWithProps(recipeId,key,props)
    nextNode=nextNode+1;nodes[nextNode]={recipeId=recipeId,props=props};return nextNode
  end
  function ctx:setResult(result)self.result=result end
  function ctx:declareState(value)
    self.index=self.index+1
    self.states[self.index]=self.states[self.index] or state(value)
    return self.states[self.index]
  end
  ctx.declareRef=ctx.declareState
  function ctx:onUnmount(fn)self.unmount=fn end
  function ctx:onMount(fn)self.mount=fn end
  function ctx:useComponentInternals()
    return {setInputActionConfig=function(_,action,config)self.actions[action]=config end}
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
  ctx=ctx or context();ctx.index=0
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
local citySettings=dofile('mod/content/gui/bulb_cockpit/city_settings.lua').create(react,builtin,
  function(value)return {styleSheet=value}end,{}, {getDefaultWindowApi=function()return wc end},P)
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
    resolveStation=function(id)if id==100 or id==101 then return {id=id,name='站 '..id}end end})
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
local staticLoads=0
local Entry=S.create(react,builtin,testStyle,P,B,
  {listLines=function()return {{id=10,name='Tram 乘客-杭州-LO-1',mode='TRAM'}}end,
    readLine=function(id)
      staticLoads=staticLoads+1
      return {static=true,next=0,passed=0,lines={},route={lineId=id,name='Tram 乘客-杭州-LO-1',mode='TRAM',color='#006db8',stops={}}}
    end}, optionStore,
  {note=function()end},{getDefaultWindowApi=function()return wc end},citySettings,stationSettings,
  {badge=badge,mark=mark,draw=function()
    return builtin.Component{meta=testStyle{size={1600,200}},layout=builtin.BoxLayout{children={testText('静态图',14,1600,200)}}}
  end})
local entryId=react.GetRecipeId(Entry)
local aliases=state({})
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
  local lineButton,lineButtonMeta
  for id,node in pairs(nodes)do
    if id>firstNode and node.recipeId==1 and node.props.props[1].id=='linnan.bulb.browser.line.10' then
      lineButtonMeta=node.props.props[1]
      lineButton=nodes[lineButtonMeta.item].props.props[1]
    end
  end
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
  local scroll,back
  local measuredHeader=false
  for id,node in pairs(nodes)do if id>firstNode then
    if names[node.recipeId]=='ScrollArea'then scroll=node end
    if node.recipeId==1 and node.props.props[1].id=='linnan.bulb.browser.back'then back=nodes[node.props.props[1].item].props.props[1]end
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
  assert(scroll and back and measuredHeader,'static page and fixed header convert through actual game React')
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
  cityCtx.actions.IA_MENU_BACK.handlerFn();assert(windowParam==nil)
  stationSettings.open{aliases=aliases,viewport=viewport}
  local stationWindow,stationCtx=render(react.GetRecipeId(windowFn),windowParam)
  assert(stationWindow.recipeId==39 and stationWindow.props.props[1].id=='linnan.bulb.station.window',
    'station association settings must return a direct native Window')
  assert(#windowParam.stations==2)
  stationCtx.actions.IA_BACK.handlerFn();assert(windowParam==nil)
  stationSettings.open{aliases=aliases,viewport=viewport};stationSettings.close();assert(windowParam==nil)
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
local contentId
for id,name in pairs(names)do if name=='LinnanBulbSettingsContentNative'then contentId=id end end
assert(contentId)
local flashAliases=state({__options={flashNextStop=false,otherOption=true}})
local flashParam={aliases=flashAliases,lines={},geometry=S.geometry({x=1280,y=720}),color=function()return {1,1,0,1}end}
local flashCtx=context()
local function drawFlash()
  lowerBound=nextNode
  render(contentId,flashParam,flashCtx)
  local result=control('linnan.bulb.settings.flash')
  local captionMeta=nodes[result.params.content].props.props[1]
  result.caption=nodes[captionMeta.item].props.props[1]
  assert(result.caption.useUnicodeCompatibilityFont==false)
  return result
end
local first=drawFlash();assert(first.params.value==0 and first.caption.text=='已关闭')
first.params.onValueChange(1)
local pending=drawFlash()
assert(pending.params.value==1 and pending.caption.text=='已开启' and pending.meta.enabled==false)
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
  local config=state({['20']={name='公交乙',prefix='',identifier='1001',suffix='',displayMode='BUS'}})
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
