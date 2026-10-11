local base='mod/content/gui/bulb_cockpit/'
local fixture=dofile('tests/performance_fixture.lua')
for _,cities in ipairs({false,true})do
  local f=fixture(base,300,32)
  local cache,first={},nil
  for tick=0,119 do
    local value=f.collect.read(f.vehicle,cities,nil,cache,tick*.5)
    assert(value and #value.lines==300 and #value.route.stops==32)
    if tick==0 then first=value else assert(value==first,'no station progression means no new display snapshot')end
  end
  assert(not f.calls.roster and f.calls.transfers==32,'only one initialization of relevant transfers per ride')
  assert(f.calls.component<(cities and 9800 or 1400),'300 actual transfers, 32 stops, cold-start 60-second component-read budget')
end
local f=fixture(base,12,6)
f.components[f.vehicle].TRANSPORT_VEHICLE.stopIndex=1
local C=f.collect;local cache={}
local a=C.read(f.vehicle,true,nil,cache,0)
f.reset();assert(C.read(f.vehicle,true,nil,cache,.5)==a)
assert(f.calls.component==1 and not f.calls.roster and not f.calls.transfers and not f.calls.fleet,
  'steady progress poll reads only the current vehicle')
local tv=f.components[f.vehicle].TRANSPORT_VEHICLE
tv.stopIndex=2
local b=C.read(f.vehicle,true,nil,cache,1)
assert(b~=a and b.next==3 and b.passed==2 and a.next==2,'missed short stops still advance immutable progress')
tv.state='AT_TERMINAL'
b=C.read(f.vehicle,true,nil,cache,1.5)
assert(b.next==4 and not f.calls.roster,'arrival uses cached topology')
f.components[1].COLOR.color={x=1,y=0,z=0}
f.components[1].NAME.name='新的实际线路名称'
assert(C.read(f.vehicle,true,nil,cache,3600)==b,'world metadata edits are deferred until re-entry')
local reentered=C.read(f.vehicle,true,nil,{},3600)
assert(reentered.route.color=='#ff0000' and reentered.route.name=='新的实际线路名称')
-- Explicit settings changes can refresh the active route without re-entry.
f.stationLines[10001]={1};f.stationLines[10002]={2}
local links={{a={id=10001,name='火车站'},b={id=10002,name='门口公交'}}}
local linked=C.read(f.vehicle,true,links,cache,3)
assert(#linked.route.stops[1].transfers==1 and linked.route.stops[1].transfers[1].id==2)
f.reset()
local equivalent={{a={id=10002,name='新公交名'},b={id=10001,name='新火车站名'}}}
assert(C.read(f.vehicle,true,equivalent,cache,3.5)==linked and f.calls.component==1,
  'reloading identical association IDs cannot initialize topology a second time')
local unlinked=C.read(f.vehicle,true,{},cache,4)
assert(#unlinked.route.stops[1].transfers==0)
f.reset();assert(C.read(f.vehicle,true,nil,cache,4.5)==unlinked and f.calls.component==1,
  'empty and absent association settings have the same meaning')
-- Other services, colors and route edits remain frozen for the current ride.
f.stationLines[10001]={1,2};f.components[2].COLOR.color={x=0,y=1,z=0}
local services=C.read(f.vehicle,false,nil,cache,5)
assert(services.route.stops[1].transfers[1].color=='#00ff00')
f.components[f.vehicles[2][1]].TRANSPORT_VEHICLE.config.capacities={0}
f.components[1].LINE.stops[1]={stationGroup=10006}
f.reset();assert(C.read(f.vehicle,false,nil,cache,3600)==services and f.calls.component==1)
local fresh=C.read(f.vehicle,false,nil,{},3600)
assert(fresh.route.stops[1].id==10006 and #fresh.route.stops[2].transfers==0)
-- Switching line or vehicle starts a new local initialization.
tv.line=2;tv.stopIndex=0;tv.state='EN_ROUTE'
local other=C.read(f.vehicle,false,nil,cache,3601)
assert(other.route.lineId==2)
f.reset();assert(C.read(f.vehicle,false,nil,cache,0)==other and f.calls.component==1,
  'elapsed/reset clocks cannot force topology work')
f.components[f.vehicles[3][1]].TRANSPORT_VEHICLE.stopIndex=0
local different=C.read(f.vehicles[3][1],false,nil,cache,3602)
assert(different.vehicle==f.vehicles[3][1] and different.route.lineId==3)
tv.state='IN_DEPOT'
assert(C.read(f.vehicle,false,nil,cache,3603)==nil and next(cache)==nil)
assert(C.read(nil,false,nil,cache,3604)==nil and next(cache)==nil)
-- City classification runs once on initialization, even across arrivals.
do
  local f=fixture(base,300,32,9);local C=f.collect;local cache={}
  local first=C.read(f.vehicle,true,nil,cache,0)
  f.components[90001]={NAME={name='旅顺'},TOWN={}}
  local group=f.components[2].LINE.stops[1].stationGroup
  local station=f.components[group].STATION_GROUP.stations[1]
  f.townMap[station]=90001
  f.reset();assert(C.read(f.vehicle,true,nil,cache,3600)==first)
  f.components[f.vehicle].TRANSPORT_VEHICLE.state='AT_TERMINAL'
  local arrived=C.read(f.vehicle,true,nil,cache,3601)
  assert(arrived~=first and not f.calls.town and not f.calls.transfers and f.calls.component==2,
    'arrivals only update progress, never reclassify buses or query transfer services')
  local reentered=C.read(f.vehicle,true,nil,{},3602)
  local found;for _,line in ipairs(reentered.lines)do if line.id==2 then found=line end end
  assert(found and found.busScope=='express' and f.calls.town and not f.calls.townMap)
  f.reset();C.read(f.vehicle,false,nil,cache,3603)
  assert(not f.calls.town and not f.calls.townMap,'disabling city naming performs no city queries')
end
print('PASS: one initialization/API budget; vehicle-only progress; explicit settings/re-entry; frozen metadata/cities; immutable snapshots')
