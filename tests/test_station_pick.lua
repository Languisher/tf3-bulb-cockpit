-- Resolve native map/icon hits to the same station-group IDs used by saved links.
local base='mod/content/gui/bulb_cockpit/'
ug_require=function(path)return dofile(base..path:match('([^/]+)$'))end
local types={NAME='NAME',STATION='STATION',STATION_GROUP='STATION_GROUP',CONSTRUCTION='CONSTRUCTION'}
local entities={
  [100]={NAME={name='杭州站'},STATION_GROUP={stations={1000,1001}}},
  [101]={NAME={name='站前公交'},STATION_GROUP={stations={1002}}},
  [102]={NAME={name='杭州站'},STATION_GROUP={stations={1003}}},
  [1000]={STATION={}},[1001]={STATION={}},[1002]={STATION={}},[1003]={STATION={}},
  [2000]={CONSTRUCTION={stations={1000,1001}}},
  [2001]={CONSTRUCTION={stations={1000,1002}}},
  [2002]={CONSTRUCTION={stations={}}},[3000]={NAME={name='普通建筑'}},
}
local groups={[1000]=100,[1001]=100,[1002]=101,[1003]=102}
local enumerations=0
api={type={ComponentType=types},gui={SelectionDetails={Type={Station=1,Stop=2,World=3}}},engine={
  entityExists=function(id)return entities[id]~=nil end,
  getComponent=function(id,kind)return entities[id] and entities[id][kind]end,
  forEachEntityWithComponent=function()enumerations=enumerations+1;error('picking must not scan all stations')end,
  system={stationGroupSystem={getStationGroup=function(station)return groups[station] or -1 end}},
}}
local C=dofile(base..'collect.lua')
assert(type(C.resolveStation)=='function','map picking needs a native hit-to-station resolver')
assert(C.resolveStation(100).id==100 and C.resolveStation(100).name=='杭州站')
assert(C.resolveStation(1002).id==101,'individual bus/tram platforms resolve to their group')
assert(C.resolveStation(2000).id==100,'multi-platform railway construction resolves unambiguously')
local station,message=C.resolveStation(2001)
assert(not station and message:find('图标',1,true),'ambiguous multi-group construction asks for the station icon')
assert(not C.resolveStation(2002) and not C.resolveStation(3000),'depots and ordinary buildings are rejected')
assert(C.resolveStation(-1,{data={kind=1,stationGroup=101}}).id==101,'native station icon detail takes precedence')
assert(C.resolveStation(2001,{data={kind=2,station={stationGroup=102}}}).id==102,
  'stop detail identifies one group even when the construction contains multiple groups')
assert(C.resolveStation(102).id~=C.resolveStation(100).id,'same-name stations remain distinct')
for _,id in ipairs({-1,999,1.5,'100',false})do assert(not C.resolveStation(id))end
assert(not C.resolveStation(nil))
entities[101]=nil
assert(not C.resolveStation(1002) and not C.resolveStation(-1,{data={kind=1,stationGroup=101}}),
  'deleted groups cannot be selected or confirmed from stale details')
assert(enumerations==0)
print('PASS: native station/icon/stop/construction picking; distinct same-name groups; ambiguous, invalid and deleted hits rejected without scanning')
