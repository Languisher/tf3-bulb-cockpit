local base='mod/content/gui/bulb_cockpit/'
local f=dofile('tests/performance_fixture.lua')(base,300,8,1)
local C,P=f.collect,dofile(base..'native_model.lua')
local aliases={}
for id=1,2 do
  local stations=id==1 and {1,2,3,2} or {4,3}
  local stops={};for _,station in ipairs(stations)do stops[#stops+1]={stationGroup=10000+station}end
  f.components[id].LINE.stops=stops
  f.components[id].LINE.vehicleInfo.transportModes={[2]=true}
  aliases[tostring(id)]={name=f.components[id].NAME.name,displayMode='RER',prefix='',identifier='A',suffix=''}
end
f.reset()
local map=assert(C.readLine(1,false,nil,aliases))
assert(map.static and not map.vehicle and map.next==0 and map.passed==0)
assert(map.route.stops[1].id==10001 and map.route.stops[3].id==10003,'static outbound order starts at original origin')
assert(map.network and #map.network.nodes==4)
assert(not f.calls.roster and not f.calls.vehicles,'only selected route and configured members are loaded')
local plan=P.plan(map,aliases,false,2000)
for _,stop in ipairs(plan.stops)do
  assert(not stop.lit and not stop.isNext,'static diagram has no vehicle status or flashing lamp')
  for _,transfer in ipairs(stop.transfers)do assert(type(transfer.id)=='number','transfer navigation retains real line IDs')end
end
assert(C.readLine(-1,false,nil,aliases)==nil)
assert(C.readLine(999999,false,nil,aliases)==nil,'deleted line returns no diagram')
-- Neither collector nor planner retains visited graphs.
map,plan=nil,nil
collectgarbage('collect');local heap=collectgarbage('count')
local weak=setmetatable({},{__mode='v'})
for i=1,301 do weak[i]=assert(C.readLine(i%2+1,false,nil,aliases))end
collectgarbage('collect');collectgarbage('collect')
assert(next(weak)==nil and collectgarbage('count')-heap<128)
print('PASS: on-demand static lines, merged paths, outbound order, navigable transfers and released snapshots')
