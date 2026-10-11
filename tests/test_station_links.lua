-- Separate station groups can represent a walkable interchange without
-- changing the route's real stop identities or the game's passenger routing.
local base='mod/content/gui/bulb_cockpit/'
ug_require=function(path)return dofile(base..path:match('([^/]+)$'))end
local types={NAME='NAME',LINE='LINE',COLOR='COLOR',TRANSPORT_VEHICLE='TRANSPORT_VEHICLE',
  STATION_GROUP='STATION_GROUP',GAME_SCRIPT='GAME_SCRIPT'}
local entities={}
for id,name in pairs({[100]='杭州火车站',[101]='火车站公交站',[102]='站前地铁站',[103]='杭州火车站',[104]='终点'})do
  entities[id]={NAME={name=name},STATION_GROUP={stations={id+1000}}}
end
local services={[100]={10},[101]={20,20,30,10},[102]={40,20},[103]={50},[104]={10}}
local tm={TRAIN=1,BUS=2,TRAM=3}
for id,kind in pairs({[10]='TRAIN',[20]='BUS',[30]='TRAIN',[40]='TRAM',[50]='BUS'})do
  entities[id]={NAME={name='线路 '..id},LINE={stops={{stationGroup=id==20 and 101 or 100},{stationGroup=104}},
    vehicleInfo={transportModes={[tm[kind]]=true}}},COLOR={color={x=id/100,y=0,z=1}}}
  entities[id+200]={TRANSPORT_VEHICLE={line=id,stopIndex=1,state='EN_ROUTE',config={capacities={id==30 and 0 or 50}}}}
end
local stateValue={lines={['10']={name='线路 10',shortName='A'}},busNaming={enabled=false,districts={}}}
local reads,enumerations={},0
api={type={ComponentType=types,['enum']={TransportMode=tm,
  TransportVehicleState={EN_ROUTE='EN_ROUTE',AT_TERMINAL='AT_TERMINAL'}}},engine={
  entityExists=function(id)return entities[id]~=nil end,
  getComponent=function(id,kind)
    if id==999 and kind=='GAME_SCRIPT'then return {state=stateValue}end
    return entities[id] and entities[id][kind]
  end,
  forEachEntityWithComponent=function(fn,kind)
    assert(kind=='STATION_GROUP');enumerations=enumerations+1
    for id,e in pairs(entities)do if e[kind]then fn(id)end end
  end,
  system={gameScriptSystem={getEntityForGameScript=function()return 999 end},
    transportVehicleSystem={getLineVehicles=function(id)return {id+200}end},lineSystem={
      getLines=function()return {10,20,30,40,50}end,
      getLinesForStationGroup=function(id)reads[id]=(reads[id] or 0)+1;return services[id] or {}end}}},
  res={cargoTypeRep={getPassengerCargoTypeId=function()return 0 end}}}
local C=dofile(base..'collect.lua')
local A=dofile(base..'aliases.lua')
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local S=env.data()
local subscribed={}
local state={get=function()return stateValue end,set=function(_,value)stateValue=value end,
  subscribeToEvent=function(_,event)subscribed[event]=true end}
S.update({},state)
api.cmd={makeScriptingSendEventCmd=function(src,id,name,param)return {src=src,id=id,name=name,param=param}end,
  sendCommand=function(cmd,callback)S.handleEvent({},state,cmd.src,cmd.id,cmd.name,cmd.param);callback(cmd,true)end}
assert(type(A.saveStationLink)=='function','manual station associations must persist through the script')
assert(subscribed[A.stationEvent],'association updates must work while game speed is paused')
local stations=C.listStationGroups()
assert(#stations==0 and enumerations==0,'association window with no saved links reads no station inventory')
local function station(id)return {id=id,name=entities[id].NAME.name}end
local function save(a,b,remove)
  local called=false
  A.saveStationLink(station(a),station(b),remove,function(_,ok)called=ok end)
  assert(called)
end
local function transfers(vehicle)
  reads={}
  local snapshot=C.read(vehicle,false,A.read().__stationLinks)
  local result={}
  for _,t in ipairs(snapshot.route.stops[1].transfers)do result[#result+1]=t.id end
  table.sort(result)
  return table.concat(result,','),snapshot
end
assert(transfers(210)=='','different station groups, including same-name ones, stay separate by default')
save(100,101,false)
local saved=A.read().__stationLinks
local relevant=C.listStationGroups(saved)
assert(#relevant==2 and enumerations==0,'association settings check only stations named in saved links')
assert(saved['100:101'] and stateValue.lines['10'].shortName=='A' and stateValue.busNaming.enabled==false)
local ids,snapshot=transfers(210)
assert(ids=='20','linked bus lines appear on the railway diagram; exclude self, duplicates and cargo')
assert(snapshot.route.stops[1].id==100 and snapshot.route.stops[1].name=='杭州火车站'
  and snapshot.route.stops[1].sourceIndex==0 and snapshot.route.stops[2].id==104
  and snapshot.next==2 and snapshot.passed==1,'preserve real stop IDs, name, sequence and journey state')
assert(snapshot.route.stops[1].transfers[1].mode=='BUS' and snapshot.route.stops[1].transfers[1].color=='#3300ff')
assert(transfers(220)=='10','association is symmetric, including boarding the bus')
save(101,102,false);save(102,100,false)
assert(transfers(210)=='20,40','transitive multi-station hub and cycles must terminate')
assert(reads[100]==1 and reads[101]==1 and reads[102]==1,'query each linked group once per route snapshot')
local oldStops=entities[10].LINE.stops
entities[10].LINE.stops={{stationGroup=100},{stationGroup=101},{stationGroup=104}}
local _,multiple=transfers(210)
assert(multiple.route.stops[1].id==100 and multiple.route.stops[2].id==101,
  'two linked groups on the same line remain separate physical stops')
assert(reads[100]==1 and reads[101]==1 and reads[102]==1,'linked stops on the route share one query cache')
entities[10].LINE.stops=oldStops
entities[100].NAME.name='杭州东站'
assert(transfers(210)=='20,40','renaming a station keeps its explicit ID association')
entities[102]=nil
assert(transfers(210)=='20','deleted station groups and their edges are ignored')
assert(enumerations==0,'neither HUD nor association settings scan the complete station inventory')
-- Independent event families must preserve each other's saved state.
S.handleEvent({},state,'',A.id,A.event,{lineId=10,name='线路 10',shortName='B'})
assert(A.read().__stationLinks['100:101'] and stateValue.busNaming)
S.handleEvent({},state,'',A.id,A.busEvent,{enabled=false,districts={},targets={},format='code_table',expressCode='51'})
assert(A.read().__stationLinks['100:101'] and stateValue.lines['10'].shortName=='B')
save(101,100,true)
assert(not A.read().__stationLinks['100:101'] and transfers(210)=='',
  'removing a reversed pair takes effect immediately; deleted nodes cannot bridge remaining links')
assert(dofile(base..'aliases.lua').read().__stationLinks['100:102'],'reload persisted links, including removable stale entries')
local before=stateValue
for _,param in ipairs({{}, {a=station(100),b=station(100),remove=false},
  {a={id=-1,name='坏站'},b=station(101),remove=false},
  {a={id=1.2,name='坏站'},b=station(101),remove=false},
  {a=station(100),b=station(101),remove='yes'}})do
  S.handleEvent({},state,'',A.id,A.stationEvent,param)
  assert(stateValue==before,'malformed events must not mutate saved configuration')
end
assert(not pcall(A.saveStationLink,station(100),station(100),false,function()end))
print('PASS: manual station links persist, merge, reload, unlink, expand symmetrically/transitively; cargo/self/stale groups excluded')
