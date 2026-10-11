-- Match the installed TF3 namespace: enums live under api.type["enum"].
-- Deliberately omit api.type.TransportMode so an invalid namespace fails here.
local base='mod/content/gui/bulb_cockpit/'
local tm={TRAM=5,BUS=3,TRAIN=7,ELECTRIC_TRAM=6,ELECTRIC_TRAIN=8,
  TRUCK=4,SHIP=10,SMALL_SHIP=12,AIRCRAFT=9,SMALL_AIRCRAFT=11,HELICOPTER=13,TRAM_TRACK=14,ELECTRIC_TRAM_TRACK=15}
local components = {
  [10]={NAME={name='tram 乘客-杭州-LO-1'}, LINE={vehicleInfo={transportModes={[tm.TRAM]=true}},stops={{stationGroup=100},{stationGroup=101}}}},
  [20]={NAME={name='Bus 乘客-杭州-LO-1001'}, COLOR={color={x=0.5,y=0,z=1}}, LINE={vehicleInfo={transportModes={[tm.BUS]=true}}}},
  [30]={NAME={name='货运'},LINE={vehicleInfo={transportModes={[tm.TRAIN]=true}}}},
  [40]={NAME={name='另一个同名站的线路'},LINE={vehicleInfo={transportModes={[tm.TRAM]=true}}}},
  [100]={NAME={name='杭州火车站'}},[101]={NAME={name='北江路'}},
  [200]={TRANSPORT_VEHICLE={line=10,stopIndex=1,state='EN_ROUTE',config={capacities={0,50}}}},
  [201]={TRANSPORT_VEHICLE={line=20,config={capacities={0,20}}}},
  [202]={TRANSPORT_VEHICLE={line=30,config={capacities={100,0}}}},
  [203]={TRANSPORT_VEHICLE={line=40,config={capacities={0,20}}}},
}
local vehicles={[10]={200},[20]={201},[30]={202},[40]={203}}
local following=200
api={type={ComponentType={NAME='NAME',COLOR='COLOR',LINE='LINE',TRANSPORT_VEHICLE='TRANSPORT_VEHICLE'},
  ['enum']={TransportMode=tm,TransportVehicleState={EN_ROUTE='EN_ROUTE',AT_TERMINAL='AT_TERMINAL'}}},
  engine={entityExists=function(id)return components[id]~=nil end,getComponent=function(id,kind)return components[id][kind] end,
  system={transportVehicleSystem={getLineVehicles=function(id)return vehicles[id] or {} end},lineSystem={
    getLines=function()return {10,20,30,40} end,
    getLinesForStationGroup=function(id) return id==100 and {10,20,20,30} or {10} end,
  }}},res={cargoTypeRep={getPassengerCargoTypeId=function()return 1 end}},
  gui={camera={getFollowEntity=function()return {following,0} end}}}
ug_require=function(path)return dofile(base..path:match('([^/]+)$')) end
local collect=dofile(base..'collect.lua')
local result=collect.read(200)
assert(result.route.name=='tram 乘客-杭州-LO-1')
assert(result.route.mode=='TRAM')
assert(#result.lines==2,'collect only the current line and actual passenger transfers')
local roster={}
for _,line in ipairs(result.lines) do roster[line.id]=line end
assert(roster[10].mode=='TRAM' and roster[30]==nil and roster[40]==nil and roster[20].color=='#8000ff')
components[10].COLOR={color={x=0.25,y=0.75,z=0.5}}
assert(collect.read(200).route.color=='#40bf80','read the main line color from the live game')
components[10].COLOR.color={x=1,y=0.125,z=0}
assert(collect.read(200).route.color=='#ff2000','a color edit appears on the next refresh')
assert(result.route.stops[1].name=='杭州火车站')
assert(#result.route.stops[1].transfers==1,'deduplicate and exclude self/cargo/different station groups')
assert(result.route.stops[1].transfers[1].name=='Bus 乘客-杭州-LO-1001')
assert(result.route.stops[1].transfers[1].color=='#8000ff')
assert(result.route.stops[1].transfers[1].mode=='BUS')
assert(result.next==2 and result.passed==1)
assert(#collect.listLines()==4,'all lines available for independent alias configuration')
components[10].LINE.vehicleInfo.transportModes={[tm.ELECTRIC_TRAM]=true}
assert(collect.read(200).route.mode=='TRAM','electric tram uses the actual enum namespace')
components[10].LINE.vehicleInfo.transportModes={[tm.ELECTRIC_TRAIN]=true}
assert(collect.read(200).route.mode=='TRAIN')
components[10].LINE.vehicleInfo.transportModes={[tm.ELECTRIC_TRAM_TRACK]=true}
assert(collect.read(200).route.mode=='TRAM','light rail modes must not fall back to BUS')
components[10].LINE.vehicleInfo.transportModes={[tm.TRAM]=true}
components[200].TRANSPORT_VEHICLE.state='AT_TERMINAL'
result=collect.read(200)
assert(result.route.stops[1].id==101 and result.route.stops[2].id==100,'reverse two-stop route at terminus')
following=-1
assert(collect.read(200)~=nil,'cockpit remains readable when the ordinary follow camera is empty')
following=200
assert(collect.read()==nil,'ordinary following alone must not display a cockpit diagram')
api.gui.camera.getFollowEntity=function()error('ordinary follow API must not be read')end
assert(collect.read(200)~=nil and collect.read(-1)==nil)
print('collector API boundary cases passed')
