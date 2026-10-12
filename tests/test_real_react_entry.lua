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
local scriptExports
ug_require=function(path)assert(path=='/scripts/util.tl');return {useFn=function(ref)
  assert(ref=='linnan_bulb_cockpit::/gui/bulb_cockpit/install.script@mainButton')
  return scriptExports.mainButton
end}end
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
ug_require=function(path)return assert(modules[path:match('([^/]+)$')],path)end
assert(loadfile(base..'install.script.lua'))()
scriptExports=data()
scriptExports.replace({ReplaceRecipe=react.GloballyReplaceRecipeBeforeInitInternal})
local queries=0
api.gui.byId={setVisible=function()end,getSize=function(id)
  queries=queries+1
  if id=='linnan.bulb.entry-gauge' then return {x=16/1280,y=16/720} end
  assert(id=='mainView','toolbar must not measure the free-camera host')
  return {x=1,y=1}
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
-- Another UI mod wins the replacement slot. Its native controls must still
-- work, and our ordinary-map toolbar entry must remain independently usable.
local competitor=react.RegisterRecipe('OtherModFreeCam',function()
  return builtin.FloatingLayout{children={}}
end)
react.GloballyReplaceRecipeBeforeInitInternal(free.FreeCamOptions,competitor)
local cameraParent=react.RegisterRecipe('CameraParent',function()return free.FreeCamOptions({})end)
local cameraCtx=context();_react.recipes[react.GetRecipeId(cameraParent)](cameraCtx,{props={}})
assert(names[nodes[cameraCtx.result[1]].recipeId]=='OtherModFreeCam')

local descriptorFile=loadfile(base..'main_button.res.lua')
local descriptor
if descriptorFile then descriptorFile();descriptor=data()end
api.res={genericRep={getAllOfType=function(kind)
  return descriptor and kind==descriptor.type and {1} or {}
end,get=function(id)assert(id==1);return {data=descriptor.data}end}}
local extension=react.RegisterExtensionPoint0('','MainModButtonAreaExtension')
local plugins=react.getPlugins(extension)
assert(#plugins==1,'ordinary-map entry disappears when another mod replaces FreeCamOptions')
local toolbar=react.RegisterRecipe('TestToolbar',function()
  return builtin.BoxLayout{children={plugins[1].recipe()}}
end)
local toolbarCtx=context();_react.recipes[react.GetRecipeId(toolbar)](toolbarCtx,{props={}})
local function unwrap(id)
  local n=nodes[id]
  if names[n.recipeId]=='WithComponentParams'then return unwrap(n.props.props[1].item)end
  return n
end
local entry=unwrap(nodes[toolbarCtx.result[1]].props.props[1].children[1])
local ctx=context()
local function draw()
  ctx.index=0;_react.recipes[entry.recipeId](ctx,entry.props)
  local settings
  local function visit(id)
    local n=unwrap(id);local p=n.props.props[1]
    if names[n.recipeId]=='LinnanBulbSettingsNative'then settings=p end
    for _,key in ipairs({'item','layout'})do if p and p[key]then visit(p[key])end end
    for _,child in ipairs(p and p.children or {})do visit(child)end
  end
  visit(ctx.result[1]);return settings
end
local params=assert(draw());ctx.mount();_reactDoExecuteJoins()
params=assert(draw());assert(type(params.aliases:old())=='table')
assert(not ctx.timer,'toolbar must not register an idle timer')
local initialQueries=queries
for i=1,2000 do _reactDoExecuteDeferredSteps();_reactDoExecuteJoins()end
assert(queries==initialQueries,'toolbar performs zero idle geometry polling')
local opened
params.prepareOpen(function(v)opened=v end)
assert(not opened,'GUI measurements must be deferred to the main thread')
_reactDoExecuteJoins()
assert(opened.x==1280 and opened.y==720,'size settings without any free-camera host')
params.prepareOpen(function()error('disposed toolbar must cancel queued opens')end)
ctx.unmount();_reactDoExecuteJoins()
print('PASS: official toolbar survives a competing FreeCam replacement, sizes independently, does no idle polling and cancels disposed work')
