-- The r7 failure had no mount/bounds logs. Diagnostics must still run when
-- every component timer is silent, and must never prevent React joins.
local messages,frames,geometryReads={},{},0
log={verbose=function(v)messages[#messages+1]=v end,warning=function(v)messages[#messages+1]=v end}
local following=-1
local ids={
  ['linnan.bulb.host']={size={x=1,y=1},visible=true,recursive=false},
  ['react.game-free-cam']={size={x=0,y=0},visible=false,recursive=false},
  ['linnan.bulb.gauge']={size={x=100/1280,y=100/720},visible=true,recursive=false},
  ['linnan.bulb.hud']={size={x=0.25,y=0.2},visible=true,recursive=false},
  ['linnan.bulb.canvas']={size={x=0.25,y=0.2},visible=true,recursive=false},
  ['linnan.bulb.settings']={size={x=148/1280,y=46/720},visible=true,recursive=false},
  ['react.game-ui-root']={size={x=1,y=1},visible=false,recursive=false},
}
api={gui={camera={getFollowEntity=function()return {following,0}end},byId={
  getSize=function(id)geometryReads=geometryReads+1;return assert(ids[id],id).size end,
  isVisible=function(id)return assert(ids[id],id).visible end,
  isVisibleRecursive=function(id)return assert(ids[id],id).recursive end,
}}}
local failOriginal=false
local original=function(arg)
  if failOriginal then error('original join failure') end
  frames[#frames+1]={arg};return 'preserved',nil,42
end
_reactDoExecuteJoins=original
local D=dofile('mod/content/gui/bulb_cockpit/diagnostics.lua')
assert(D.install()==false and _reactDoExecuteJoins==original,'normal gameplay must not wrap the global join processor')
D.note('hud.render');D.watch('hud',{},{});_reactDoExecuteJoins('no observer')
assert(geometryReads==0 and #messages==0,'default diagnostics must do no GUI work or retain watched state')
frames={}
local cockpit=82579
D.setCameraReader(function()return cockpit end)
assert(D.install(true))
local observer=_reactDoExecuteJoins
assert(D.install(true) and observer==_reactDoExecuteJoins,'do not nest observers')
local a,b,c=_reactDoExecuteJoins('first')
assert(a=='preserved' and b==nil and c==42 and frames[1][1]=='first','preserve original call and returns')
local function contains(s)
  for _,m in ipairs(messages)do if m:find(s,1,true)then return true end end
  return false
end
assert(geometryReads==7,'observer runs without any mounted recipe or component callback')
assert(contains('follow=-1; cockpit=82579'),'distinguish cockpit entity from the ordinary camera')
assert(contains('host=raw=1.000000x1.000000, visible=true, recursive=false'),'distinguish hidden ancestors')
assert(contains('hud=raw=0.250000x0.200000'),'do not round fractional screen dimensions to zero')
assert(contains('canvas=raw=0.250000x0.200000'),'observe the explicit canvas separately from the recipe')
assert(contains('root.render=0') and contains('hud.refresh=0'),'record absent lifecycle callbacks')
local expired=false
local state={hasExpired=function()return expired end,old=function()return {route={lineId=10,stops={{}}},next=1,passed=0} end}
local ref={get=function()return {getPosition=function(_,x,y)return {x=x,y=y}end}end}
D.watch('hud',ref,state)
D.note('root.render');D.note('hud.refresh');D.note('hud.render','route=10')
following=200
ids['linnan.bulb.host'].recursive=true
for _=1,120 do _reactDoExecuteJoins('next') end
assert(contains('follow=200') and contains('hud.ref=0.000,0.000..1.000,1.000'))
assert(contains('host=raw=1.000000x1.000000, visible=true, recursive=true')
  and contains('native=raw=0.000000x0.000000, visible=false, recursive=false'),
  'observe the independent host and native control visibility separately')
assert(contains('hud.state=line=10, stops=1, next=1, passed=0'),'observe whether state updates actually reached the component')
expired=true
ids['linnan.bulb.hud']=nil
for _=1,120 do _reactDoExecuteJoins() end
assert(contains('hud.stateExpired=true') and contains('hud=unavailable:'))
assert(#frames==241,'missing UI IDs must not stop the original join processor')
local oldCamera=api.gui.camera.getFollowEntity
api.gui.camera.getFollowEntity=function()error('restricted in test')end
for _=1,120 do _reactDoExecuteJoins() end
assert(contains('follow=unavailable:') and #frames==361,'isolate each failed read')
api.gui.camera.getFollowEntity=oldCamera
failOriginal=true
local ok,err=pcall(_reactDoExecuteJoins)
assert(not ok and tostring(err):find('original join failure',1,true),'preserve original exceptions')
print('PASS: diagnostics observe silent/hidden/expired UI without altering React joins')
