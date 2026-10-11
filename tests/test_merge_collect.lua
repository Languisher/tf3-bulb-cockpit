local base='mod/content/gui/bulb_cockpit/'
local fixture=dofile('tests/performance_fixture.lua')
local f=fixture(base,300,8,1)
local C,cache=f.collect,{}
local aliases={}
local function path(id,ids)
  local stops={};for _,station in ipairs(ids)do stops[#stops+1]={stationGroup=10000+station}end
  f.components[id].LINE.stops=stops
  f.components[id].LINE.vehicleInfo.transportModes={[2]=true}
  aliases[tostring(id)]={name=f.components[id].NAME.name,displayMode='RER',prefix='',identifier='A',suffix=''}
end
path(1,{1,2,3,2});path(2,{1,2,4,2});path(3,{4,5,6,5})
f.components[f.vehicle].TRANSPORT_VEHICLE.stopIndex=1
local first=C.read(f.vehicle,false,nil,cache,aliases)
assert(first.network and #first.network.services==3 and #first.network.nodes==6)
assert(not f.calls.roster, 'membership comes from configured badges, not all game lines')
local original=api.engine.getComponent
api.engine.getComponent=function(id,kind)
  assert(id==f.vehicle and kind=='TRANSPORT_VEHICLE', 'after initialization only read the followed vehicle')
  return original(id,kind)
end
f.reset()
for i=1,2000 do assert(C.read(f.vehicle,false,nil,cache,aliases)==first)end
assert(f.calls.component==2000)
f.components[f.vehicle].TRANSPORT_VEHICLE.state='AT_TERMINAL'
local arrived=C.read(f.vehicle,false,nil,cache,aliases)
assert(arrived~=first and arrived.network==first.network and arrived.passed==2, 'arrivals reuse the immutable graph')
api.engine.getComponent=original
-- A whole group containing two trees stays separate, even with nearby-stop links.
path(3,{5,6,7,6});cache={}
local links={{a={id=10004},b={id=10005}}}
local separate=C.read(f.vehicle,false,links,cache,aliases)
assert(not separate.network and separate.mergeWarning, 'manual nearby associations cannot make a shared terminus')
-- Live station/track edits are only read on re-entry; no construction polling.
path(3,{4,5,6,5})
assert(C.read(f.vehicle,false,links,cache,aliases)==separate)
assert(C.read(f.vehicle,false,links,{},aliases).network)
aliases['3'].suffix='支线'
local after=C.read(f.vehicle,false,links,cache,aliases)
-- Alias store publishes new tables; in-place mutation above is intentionally
-- ignored just like all other cached configuration data.
local changed={};for k,v in pairs(aliases)do changed[k]=v end
after=C.read(f.vehicle,false,links,cache,changed)
assert(after.network and #after.network.services==2, 'changing membership rebuilds only this group')
assert(not f.calls.roster)
-- Enter/leave repeatedly without retaining previous immutable graphs.
first,arrived,separate,after=nil,nil,nil,nil;cache={}
collectgarbage('collect');local heap=collectgarbage('count')
local graphs=setmetatable({},{__mode='v'})
for session=1,501 do
  local state={}
  local snapshot=C.read(f.vehicle,false,nil,state,aliases)
  assert(snapshot.network);graphs[session]=snapshot.network
  assert(C.read(nil,false,nil,state,aliases)==nil and next(state)==nil)
end
collectgarbage('collect');collectgarbage('collect')
assert(next(graphs)==nil, 'no old branch graphs survive exit')
local delta=collectgarbage('count')-heap
assert(delta<256, 'branch sessions must not accumulate Lua memory: '..delta..' KiB')
print(string.format('retention: 501 sessions; surviving graphs=0; heap delta=%.1f KiB',delta))
print('PASS: configured-member initialization, vehicle-only riding, graph reuse, all-or-nothing connectivity and deferred world edits')
