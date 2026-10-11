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
for _,name in ipairs({'native_model.lua','mode_marks.lua','diagnostics.lua','settings.lua','city_settings.lua','station_settings.lua','camera_state.lua'})do
  modules[name]=dofile(base..name)
end
ug_require=function(path)return assert(modules[path:match('([^/]+)$')],path)end
assert(loadfile(base..'install.script.lua'))()
data().replace({ReplaceRecipe=react.GloballyReplaceRecipeBeforeInitInternal})
local queries=0
api.gui.byId={setVisible=function()end,getSize=function(id)
  queries=queries+1
  return id=='linnan.bulb.gauge' and {x=100/1280,y=100/720} or {x=1,y=1}
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
local function draw()
  ctx.index=0;_react.recipes[host.recipeId](ctx,host.props)
  local function hud(id)
    local n=nodes[id];local p=n.props.props[1]
    if names[n.recipeId]=='LinnanBulbCockpitHudNative'then return n end
    for _,key in ipairs({'item','layout'})do if p and p[key]then local found=hud(p[key]);if found then return found end end end
    for _,child in ipairs(p and p.children or {})do local found=hud(child);if found then return found end end
  end
  return hud(ctx.result[1])
end
assert(not draw());ctx.mount();_reactDoExecuteJoins()
local initialQueries=queries
for i=1,2000 do ctx.timer();_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()end
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
ctx.timer();_reactDoExecuteDeferredSteps();_reactDoExecuteJoins()
assert(ctx.writes==writes,'disposed root cannot receive camera events or queued updates')
print('PASS: actual React adapter; 50 keyed HUD lifetimes, removal without child rendering, stable active identities, idle budget and unsubscription')
