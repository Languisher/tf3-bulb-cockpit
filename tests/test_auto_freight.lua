local base='mod/content/gui/bulb_cockpit/'
local f=dofile('tests/performance_fixture.lua')(base,300,8,3)
local P=dofile(base..'native_model.lua')
local main=f.components[100001].TRANSPORT_VEHICLE
main.stopIndex=2;main.config={capacities={0,0},allCaps={0,100}}
f.components[2].LINE.vehicleInfo.transportModes={[2]=true}
f.components[100002].TRANSPORT_VEHICLE.config={capacities={0,50},allCaps={0,50}}
f.components[3].LINE.vehicleInfo.transportModes={[2]=true}
f.components[100003].TRANSPORT_VEHICLE.config={capacities={50,0},allCaps={50,0}}
f.components[4].LINE.vehicleInfo.transportModes={[2]=true};f.vehicles[4]={}
local lines=f.collect.listLines()
local byId={};for _,line in ipairs(lines)do byId[line.id]=line end
assert(byId[1].mode=='FREIGHT_TRAIN' and byId[2].mode=='FREIGHT_TRAIN','cargo rail must classify without manual overrides, including auto-load wagons')
assert(byId[3].mode=='TRAIN' and byId[4].mode=='TRAIN','passenger and empty fleets retain Train')
local aliases={__defaults={['1']={name=byId[1].name,mode='TRAIN',index=1,shortName='A',railTypesVersion=2}}}
assert(P.defaults(lines,aliases)['1'].shortName=='72001','old auto passenger letters migrate to cargo numbers')
assert(P.mode(byId[1],{['1']={name=byId[1].name,displayMode='TRAIN'}})=='TRAIN','explicit user types still win')
assert(P.alias(byId[1],{['1']={name=byId[1].name,prefix='F-',identifier='55001',suffix=''}},P.defaults(lines,aliases))=='F-55001')
f.reset();local cache={};local snap=assert(f.collect.read(f.vehicle,false,nil,cache,aliases))
assert(snap.route.mode=='FREIGHT_TRAIN')
assert(not f.calls.roster and not f.calls.townMap,'cockpit never discovers all lines')
assert(f.calls.fleet<=3,'related fleet capabilities are cached once during initialization')
local seen={};for _,line in ipairs(snap.lines)do seen[line.id]=true end
assert(seen[2] and not seen[3],'cargo route shows cargo connections only')
f.reset()
for i=1,120 do assert(f.collect.read(f.vehicle,false,nil,cache,aliases)==snap)end
assert(f.calls.component==120 and not f.calls.fleet and not f.calls.roster and not f.calls.cargo,'no recurring capability scans')
main.config={capacities={50,100},allCaps={50,100}}
assert(f.collect.readLine(1).route.mode=='TRAIN','mixed passenger/cargo remains passenger Train')
print('PASS: automatic rail freight, auto-load capacity, empty and mixed fleets, old numbering, manual overrides and scoped API budget')
