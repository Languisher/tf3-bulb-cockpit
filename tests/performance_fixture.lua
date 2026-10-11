-- Deterministic engine fixture. Counters measure API work, not game FPS.
return function(base,count,stopCount,relatedCount)
  relatedCount=relatedCount or count
  local f={components={},calls={},lines={},vehicles={},stationLines={},townMap={}}
  local function hit(key)f.calls[key]=(f.calls[key] or 0)+1 end
  local tm={BUS=1,TRAIN=2,TRAM=3}
  local kinds={}
  for _,k in ipairs({'NAME','COLOR','LINE','TRANSPORT_VEHICLE','STATION_GROUP','TOWN'})do kinds[k]=k end
  f.components[90000]={NAME={name='杭州'},TOWN={}}
  local function station(id,label)
    if f.components[id]then return end
    f.components[id]={NAME={name=label},STATION_GROUP={stations={id+20000}}}
    f.townMap[id+20000]=90000;f.stationLines[id]={}
  end
  for i=1,stopCount do station(10000+i,'车站 '..i)end
  for i=1,count do
    local stops={}
    for j=1,stopCount do
      -- Each bus shares four stops with the main line, and has independent
      -- remaining stops. Membership queries agree with the actual routes.
      local id=(i==1 or (i<=relatedCount and (i+j)%8==0)) and 10000+j or 10000+i*stopCount+j
      station(id,'公交站 '..i..'-'..j)
      stops[j]={stationGroup=id}
      local at=f.stationLines[id];at[#at+1]=i
    end
    f.lines[i]=i
    f.components[i]={NAME={name=(i==1 and '铁路 ' or '公交 ')..i},
      COLOR={color={x=.1,y=.4,z=.8}},
      LINE={stops=stops,vehicleInfo={transportModes={[i==1 and tm.TRAIN or tm.BUS]=true}}}}
    local v=100000+i;f.vehicles[i]={v}
    f.components[v]={TRANSPORT_VEHICLE={line=i,stopIndex=12,state='EN_ROUTE',config={capacities={50}}}}
  end
  f.vehicle=100001
  api={type={ComponentType=kinds,['enum']={TransportMode=tm,
    TransportVehicleState={EN_ROUTE='EN_ROUTE',AT_TERMINAL='AT_TERMINAL'}}},engine={
    entityExists=function(id)hit('exists');return f.components[id]~=nil end,
    getComponent=function(id,kind)hit('component');hit(kind);return f.components[id] and f.components[id][kind]end,
    system={lineSystem={getLines=function()hit('roster');return f.lines end,
      getLinesForStationGroup=function(id)hit('transfers');return f.stationLines[id] or {}end},
      transportVehicleSystem={getLineVehicles=function(id)hit('fleet');return f.vehicles[id] or {}end},
      stationSystem={getTown=function(id)hit('town');return f.townMap[id]end,getStation2TownMap=function()hit('townMap');return f.townMap end}}},
    res={cargoTypeRep={getPassengerCargoTypeId=function()hit('cargo');return 0 end}}}
  ug_require=function(path)return dofile(base..path:match('([^/]+)$'))end
  f.collect=dofile(base..'collect.lua')
  function f.reset()f.calls={}end
  return f
end
