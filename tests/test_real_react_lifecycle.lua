-- Use Build 40420's actual React Lua adapter for node identity, metadata,
-- timers and joins. C++ rendering/disposal still requires in-game validation.
local reactPath=assert(arg[1],'pass the extracted gui/main/react.lua')
local nodes,names,nextNode,nextRecipe={}, {[1]='WithComponentParams'},0,1
_react={builtin={WithComponentParams=1},recipes={},recipeMetas={},originalRecipeFn={},
  recipeReplace={},extensionPoints={},tools={},recipeReplacementAllowed=true}
log={verbose=function()end,warning=function(m)error(m)end,error=function(m)error(m)end}
api={gui={react={detail={makeRecipeId=function(name)
  nextRecipe=nextRecipe+1;names[nextRecipe]=name;return nextRecipe
end},params={builtin={WithComponentParams={new=function()return {}end}}},fireEvent=function()end}}}
local saved=require
require=function(path)if path=='/scripts/string_util.tl'then return {format=function(s)return s end}end;return saved(path)end
ug_require=function(path)assert(path=='/scripts/util.tl');return {}end
local react=dofile(reactPath);require=saved
local builtin={type={FloatingLayoutOverflowMode={KeepInside=1}}}
for _,name in ipairs({'Component','FloatingLayout','FloatingLayoutChild','BoxLayout','Window'})do
  nextRecipe=nextRecipe+1;_react.builtin[name]=nextRecipe;names[nextRecipe]=name
  api.gui.react.params.builtin[name]={new=function()return {}end}
  builtin[name]=react.DeclareBuiltinWithUserdata(name,function()end)
end
local free={FreeCamOptions=react.RegisterRecipe('FreeCamOptions',function()end),
  FreeCamTool={push=function()end,pop=function()end}}
local base='mod/content/gui/bulb_cockpit/'
local modules={['react.lua']=react,['builtin.lua']=builtin,['free_cam_options.tl']=free,
  ['styleutil.tl']={makeStyle=function(v)return v end},['collect.lua']={},
  ['aliases.lua']={read=function()return {},0 end},['game_react_globals.tl']={}}
for _,name in ipairs({'localization.lua','native_model.lua','mode_marks.lua','diagnostics.lua','settings.lua','city_settings.lua','station_settings.lua','camera_state.lua'})do
  modules[name]=dofile(base..name)
end
modules['statistics_react_util.tl']=dofile('tests/carrier_filter_fixture.lua')(builtin)
ug_require=function(path)return assert(modules[path:match('([^/]+)$')],path)end
assert(loadfile(base..'install.script.lua'))()
data().replace({ReplaceRecipe=react.GloballyReplaceRecipeBeforeInitInternal})
local queries,laidOut=0,false
api.gui.byId={setVisible=function()end,getSize=function(id)
  queries=queries+1
  return id=='linnan.bulb.gauge' and (laidOut and {x=100/800,y=100/600} or {x=0,y=0}) or {x=1,y=1}
end}
local function context()
  local ctx={states={},index=0,writes=0,internals={}}
  function ctx:makeNodeWithProps(id,key,props)
    nextNode=nextNode+1;nodes[nextNode]={recipeId=id,key=key,props=props};return nextNode
  end
  function ctx:setResult(result)self.result=result end
  function ctx:declareState(value)
    self.index=self.index+1
    local h=self.states[self.index]
    if not h then
      h={value=value,old=function(s)return s.value end,get=function(s)return s.value end,
        set=function(s,v)s.value=v;ctx.writes=ctx.writes+1 end,hasExpired=function()return false end}
      self.states[self.index]=h
    end
    return h
  end
  ctx.declareRef=ctx.declareState
  function ctx:declareSelfRef()return {get=function()return nil end}end
  function ctx:useComponentInternals()return self.internals end
  function ctx:onMount(fn)self.mount=fn end
  function ctx:onUnmount(fn)self.unmount=fn end
  function ctx:onStepTimer(fn)self.timer=fn end
  return ctx
end
local parent=react.RegisterRecipe('TestParent',function()return free.FreeCamOptions({meta={id='react.game-free-cam'}})end)
local parentCtx=context();_react.recipes[react.GetRecipeId(parent)](parentCtx,{props={}})
local host=nodes[nodes[parentCtx.result[1]].props.props[1].item]
local ctx=context()
local calibration
local function draw()
  calibration=nil
  ctx.index=0;_react.recipes[host.recipeId](ctx,host.props)
  local function hud(id)
    local n=nodes[id];local p=n.props.props[1]
    if names[n.recipeId]=='LinnanBulbCalibrationNative'then calibration=n end
    if names[n.recipeId]=='LinnanBulbCockpitHudNative'then return n end
    for _,key in ipairs({'item','layout'})do if p and p[key]then local found=hud(p[key]);if found then return found end end end
    for _,child in ipairs(p and p.children or {})do local found=hud(child);if found then return found end end
  end
  return hud(ctx.result[1])
end
assert(not draw() and calibration);ctx.mount();_reactDoExecuteJoins()
assert(not draw() and calibration,'retry only while layout is unavailable')
local retry=context()
_react.recipes[calibration.recipeId](retry,calibration.props)
assert(retry.timer and not ctx.timer,'the disposable calibration child owns the retry timer')
laidOut=true
retry.timer();_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()
assert(not draw() and not calibration,'valid 800x600 calibration must remove retries even when fallback dimensions match')
local initialQueries=queries
assert(not ctx.timer,'actual root context must not register an idle timer')
for i=1,2000 do retry.timer();_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()end
assert(queries==initialQueries,'real React timer/deferred/join chain must do zero idle geometry reads')
local previousKey
for i=1,50 do
  free.FreeCamTool.push({}, {cockpitCameraForEntity=200});_reactDoExecuteJoins()
  local current=assert(draw());assert(current.key~=previousKey,'each entry must own a new native HUD identity')
  previousKey=current.key
  assert(draw().key==current.key,'ordinary root rerenders preserve the active HUD identity')
  free.FreeCamTool.pop()
  assert(not draw(),'visible parent removes HUD without executing the hidden HUD recipe')
end
ctx.unmount();local writes=ctx.writes
free.FreeCamTool.push({}, {cockpitCameraForEntity=200})
_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()
assert(ctx.writes==writes,'disposed root cannot receive camera events or queued updates')
print('PASS: actual React adapter; 50 keyed HUD lifetimes, removal without child rendering, stable active identities, idle budget and unsubscription')

-- An unavailable gauge cannot leave a timer retrying for the whole game.
do
  modules['game_react_globals.tl'].getDefaultWindowApi=function()return nil end
  local mainId
  for id,name in pairs(names)do if name=='LinnanBulbMainButtonNative'then mainId=id end end
  local plugin=context();_react.recipes[assert(mainId)](plugin,{props={{}}});plugin.unmount()
  laidOut=false
  local root=context()
  local function drawCalibration()
    root.index=0;_react.recipes[host.recipeId](root,host.props)
    local function visit(id)
      local node=nodes[id];local p=node.props.props[1]
      if names[node.recipeId]=='LinnanBulbCalibrationNative'then return node end
      for _,key in ipairs({'item','layout'})do if p[key]then local found=visit(p[key]);if found then return found end end end
      for _,child in ipairs(p.children or {})do local found=visit(child);if found then return found end end
    end
    return visit(root.result[1])
  end
  local warnings={};local oldWarning=log.warning;log.warning=function(m)warnings[#warnings+1]=m end
  assert(drawCalibration());root.mount();_reactDoExecuteJoins()
  local child=assert(drawCalibration());local retry=context()
  _react.recipes[child.recipeId](retry,child.props)
  for i=1,20 do retry.timer();_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()end
  assert(not drawCalibration() and #warnings==1,'startup failure stops retrying and falls back once')
  local count=queries
  for i=1,2000 do retry.timer();_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()end
  assert(queries==count,'even stale startup callbacks must perform zero later queries')
  root.unmount();log.warning=oldWarning
  print('PASS: bounded startup calibration; failed gauge stops its timer and later GUI queries')
end
