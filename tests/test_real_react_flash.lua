-- Validate the animation recipe against the installed game's React Lua,
-- including layout returns, metadata/local keys and timer isolation.
local reactPath=assert(arg[1],'pass the extracted Build 40420 gui/main/react.lua')
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
local builtin={type={ImageViewScaling={Stretch=1,AutoFit=2},FloatingLayoutOverflowMode={KeepInside=1}}}
for _,name in ipairs({'Component','FloatingLayout','FloatingLayoutChild','BoxLayout','TextView','ImageView','Window'})do
  nextRecipe=nextRecipe+1;_react.builtin[name]=nextRecipe;names[nextRecipe]=name
  api.gui.react.params.builtin[name]={new=function()return {}end}
  builtin[name]=react.DeclareBuiltinWithUserdata(name,function()end)
end
local base='mod/content/gui/bulb_cockpit/'
local vehicle=200
local modules={['react.lua']=react,['builtin.lua']=builtin,['free_cam_options.tl']={},
  ['styleutil.tl']={makeStyle=function(v)return v end},['collect.lua']={},['aliases.lua']={},
  ['game_react_globals.tl']={},['camera_state.lua']={getEntity=function()return vehicle end}}
for _,name in ipairs({'localization.lua','native_model.lua','mode_marks.lua','diagnostics.lua','settings.lua','city_settings.lua','station_settings.lua'})do
  modules[name]=dofile(base..name)
end
modules['statistics_react_util.tl']=dofile('tests/carrier_filter_fixture.lua')(builtin)
ug_require=function(path)return assert(modules[path:match('([^/]+)$')],path)end
assert(loadfile(base..'install.script.lua'))()
local flashId
for id,name in pairs(names)do if name=='LinnanBulbFlashingStationNative'then flashId=id end end
assert(flashId)
local function context()
  local ctx={states={},index=0,writes=0,expired=false}
  function ctx:makeNodeWithProps(id,key,props)
    nextNode=nextNode+1;nodes[nextNode]={recipeId=id,key=key,props=props};return nextNode
  end
  function ctx:setResult(result)self.result=result end
  function ctx:declareState(value)
    self.index=self.index+1
    local h=self.states[self.index]
    if not h then
      h={value=value,old=function(self)return self.value end,
        set=function(self,v)self.value=v;ctx.writes=ctx.writes+1 end,
        hasExpired=function()return ctx.expired end}
      self.states[self.index]=h
    end
    return h
  end
  function ctx:onStepTimer(fn,interval,jitter)
    assert(interval==.5 and jitter==false);self.timer=fn
  end
  return ctx
end
local function render(param,ctx)
  ctx.index=0;_react.recipes[flashId](ctx,{props={param}})
  assert(names[nodes[ctx.result[1]].recipeId]=='FloatingLayout','a recipe child must be a layout')
  return ctx.result[1]
end
local function tick(ctx)ctx.timer();_reactDoExecuteDeferredSteps()end
local function light(root)
  local found=false
  local function visit(id)
    local node=assert(nodes[id]);local p=node.props.props[1]
    if names[node.recipeId]=='WithComponentParams' and p.styleSheet then
      if p.styleSheet.color and p.styleSheet.color[1]==1 and p.styleSheet.color[2]==.82 then found=true end
      if p.styleSheet.backgroundColor and p.styleSheet.backgroundColor[1]==1 and p.styleSheet.backgroundColor[2]==.82 then found=true end
    end
    for _,key in ipairs({'item','layout'})do if p[key]then visit(p[key])end end
    for _,child in ipairs(p.children or {})do visit(child)end
  end
  visit(root);return found
end
for _,kind in ipairs({'ordinary','interchange','terminus'})do
  local param={stop={key='line:0>1',fullName='下一站',markerKind=kind,markerSize=18,lit=false},
    track={ordinaryFill='white'},lineColor={0,.4,.8,1},vehicle=200}
  local ctx=context();assert(light(render(param,ctx)),'new lamp begins ON')
  assert(param.stop.lit==false,'animation must not mutate cached plan data')
  tick(ctx);assert(not light(render(param,ctx)),'lamp changes without a collector or parent render')
  tick(ctx);assert(light(render(param,ctx)))
  vehicle=nil;local count=ctx.writes;tick(ctx);assert(ctx.writes==count,'no animation outside the cockpit')
  vehicle=200;ctx.expired=true;tick(ctx);assert(ctx.writes==count,'no work after unmount')
  local fresh=context();assert(light(render(param,fresh)),'new direction/target context starts ON')
end
-- The endpoint lamp must remain conspicuous on a yellow-colored route too.
-- Inspect the actual native image wrappers: brighten the full inner disc in
-- ON, and use a dark core/white collar in OFF without adding drawing layers.
local function markerLayers(root)
  local layers,count={},0
  local function visit(id)
    local node=nodes[id];local p=node.props.props[1]
    if names[node.recipeId]=='WithComponentParams' and p.item then
      local item=nodes[p.item]
      if names[item.recipeId]=='ImageView'then
        local path=item.props.props[1].path
        layers[path:match('([^/]+)$')]=p.styleSheet;count=count+1
      end
    end
    for _,key in ipairs({'item','layout'})do if p[key]then visit(p[key])end end
    for _,child in ipairs(p.children or {})do visit(child)end
  end
  visit(root);return layers,count
end
do
  vehicle=200
  local param={stop={key='yellow:0>1',fullName='终点',markerKind='terminus',markerSize=18,lit=false},
    track={ordinaryFill='white'},lineColor={1,.82,0,1},vehicle=200}
  local ctx=context()
  local on,count=markerLayers(render(param,ctx))
  assert(count==3,'retain the three existing circular endpoint layers')
  assert(on['station-interior.tga'].color[2]==.82,
    'the full terminus interior must glow yellow, not just its tiny center')
  tick(ctx)
  local off=markerLayers(render(param,ctx))
  assert(off['station-interior.tga'].color[1]==1 and off['station-interior.tga'].color[2]==1)
  assert(off['circle.tga'].color[1]<.15 and off['circle.tga'].color[2]<.15,
    'the OFF core must contrast with yellow line colors')
  assert(on['station-outline.tga'].color[1]==0 and off['station-outline.tga'].color[1]==0,
    'preserve the endpoint black circular outline in both phases')
  assert(not param.stop.flashing,'animation must not mutate the cached marker plan')
end
-- Native marker layers retain the same scale through both animation phases.
for _,scale in ipairs({.1,.37,1,1.75,4})do
  local param={stop={key='scaled:0>1',fullName='Terminus',markerKind='terminus',markerSize=18,lit=false},
    track={ordinaryFill='white'},lineColor={1,.82,0,1},vehicle=200,scale=scale}
  local ctx=context()
  local on=markerLayers(render(param,ctx));tick(ctx);local off=markerLayers(render(param,ctx))
  for _,layers in ipairs({on,off})do
    assert(math.abs(layers['station-outline.tga'].size[1]-18*scale)<.00001)
    assert(math.abs(layers['station-interior.tga'].size[1]-14.4*scale)<.00001)
  end
end
local parent=react.RegisterRecipe('FlashMetadataTest',function()
  return _react.originalRecipeFn[flashId]({meta={localKey='flash:200:line:0>1',
    styleSheet={size={18,18},anchorPoint={.5,.5}}}})
end)
local parentCtx=context();_react.recipes[react.GetRecipeId(parent)](parentCtx,{props={}})
local outer=nodes[parentCtx.result[1]]
assert(names[outer.recipeId]=='WithComponentParams')
local inner=nodes[outer.props.props[1].item]
assert(inner.recipeId==flashId and inner.key=='flash:200:line:0>1',
  'target-specific keys reach the actual engine constructor for remounting')
print('PASS: actual React animation layout, ON/OFF phases, immutable marker, expired/hidden timers and target local keys')
