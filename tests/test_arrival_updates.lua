local base='mod/content/gui/bulb_cockpit/'
local fixture=dofile('tests/performance_fixture.lua')
local f=fixture(base,300,32,9)
local C,cache=f.collect,{}
local tv=f.components[f.vehicle].TRANSPORT_VEHICLE
tv.stopIndex=1
local first=C.read(f.vehicle,true,nil,cache,0)
assert(first and #first.lines==9 and first.next==2)
local originalGet=api.engine.getComponent
local function vehicleOnly()
  api.engine.getComponent=function(id,kind)
    assert(id==f.vehicle and kind=='TRANSPORT_VEHICLE','after initialization only read the current vehicle')
    return originalGet(id,kind)
  end
  for _,system in ipairs({'lineSystem','transportVehicleSystem','stationSystem'})do
    for name in pairs(api.engine.system[system])do
      api.engine.system[system][name]=function()error('ride must not query '..system..'.'..name)end
    end
  end
end
vehicleOnly()
f.reset()
for tick=1,2000 do
  assert(C.read(f.vehicle,true,nil,cache,tick*.5)==first,'elapsed time cannot change the snapshot')
end
assert(f.calls.component==2000 and f.calls.TRANSPORT_VEHICLE==2000,'one component read per progress poll')
-- World edits are deliberately deferred until the next cockpit entry.
f.components[1].NAME.name='改名后的线路'
f.components[1].COLOR.color={x=1,y=0,z=0}
f.components[10001].NAME.name='改名后的车站'
assert(C.read(f.vehicle,true,nil,cache,3600)==first)
tv.state='AT_TERMINAL'
local arrived=C.read(f.vehicle,true,nil,cache,3601)
assert(arrived~=first and arrived.next==3 and arrived.passed==2)
assert(arrived.route.name==first.route.name and arrived.route.color==first.route.color)
assert(first.next==2 and first.passed==1,'older display snapshots remain immutable')
for tick=1,8 do assert(C.read(f.vehicle,true,nil,cache,3601+tick*.5)==arrived)end
tv.stopIndex=2;tv.state='EN_ROUTE'
assert(C.read(f.vehicle,true,nil,cache,3606)==arrived,'departure cannot rebuild the already updated arrival diagram')
for tick=1,8 do assert(C.read(f.vehicle,true,nil,cache,3606+tick*.5)==arrived)end
-- A very short stop may finish between polls. An advanced stopIndex still
-- represents a completed stop and must catch up exactly once.
tv.stopIndex=3
local caughtUp=C.read(f.vehicle,true,nil,cache,3611)
assert(caughtUp~=arrived and caughtUp.next==4 and caughtUp.passed==3)
assert(C.read(f.vehicle,true,nil,cache,3612)==caughtUp)
tv.state='IN_DEPOT'
assert(C.read(f.vehicle,true,nil,cache,3613)==nil and next(cache)==nil)

-- Real cached shuttle sequence: arrive at each terminus, then depart without
-- changing the diagram a second time. The return lamp gets a new identity.
f=fixture(base,12,6);C=f.collect;cache={}
tv=f.components[f.vehicle].TRANSPORT_VEHICLE
f.components[1].LINE.stops={{stationGroup=10001},{stationGroup=10002},{stationGroup=10003},{stationGroup=10002}}
tv.stopIndex=2
local outbound=C.read(f.vehicle,false,nil,cache)
tv.state='AT_TERMINAL'
local returning=C.read(f.vehicle,false,nil,cache)
local P=dofile(base..'native_model.lua')
assert(returning.route.stops[1].id==10003 and returning.next==2 and returning.passed==1)
assert(P.nextKey(outbound)~=P.nextKey(returning))
tv.stopIndex=3;tv.state='EN_ROUTE'
assert(C.read(f.vehicle,false,nil,cache)==returning)
tv.state='AT_TERMINAL'
local last=C.read(f.vehicle,false,nil,cache)
tv.stopIndex=0;tv.state='EN_ROUTE'
assert(C.read(f.vehicle,false,nil,cache)==last)
tv.state='AT_TERMINAL'
local newOutbound=C.read(f.vehicle,false,nil,cache)
assert(newOutbound.route.stops[1].id==10001 and newOutbound.next==2)
tv.stopIndex=1;tv.state='EN_ROUTE'
assert(C.read(f.vehicle,false,nil,cache)==newOutbound)

-- Invalid indices must not wrap to a previously valid target.
tv.stopIndex=5
assert(C.read(f.vehicle,false,nil,cache)==nil and next(cache)==nil)
f.components[1].LINE.stops={{stationGroup=10001}};tv.stopIndex=0;tv.state='EN_ROUTE'
local single=C.read(f.vehicle,false,nil,cache)
tv.state='AT_TERMINAL'
local singleArrived=C.read(f.vehicle,false,nil,cache)
assert(single.next==1 and singleArrived.next==0 and singleArrived.passed==1)
assert(C.read(f.vehicle,false,nil,cache)==singleArrived)
print('PASS: initialize once; vehicle-only polling; arrival-only snapshots; departure reuse; missed short stops; shuttle and single-stop arrivals')
