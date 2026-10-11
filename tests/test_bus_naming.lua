local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local A=dofile('mod/content/gui/bulb_cockpit/aliases.lua')
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local script=env.data()
local value={lines={['10']={name='市内甲',shortName='旧10',displayMode='BUS'}}}
local state={get=function()return value end,set=function(_,nextValue)value=nextValue end,subscribeToEvent=function()end}
local types={NAME='NAME',TOWN='TOWN',LINE='LINE',STATION_GROUP='STATION_GROUP',COLOR='COLOR',GAME_SCRIPT='GAME_SCRIPT'}
local modes={BUS=1,TRAIN=2,TRUCK=3,TRAM=4}
local entities={
  [100]={NAME={name='杭州'},TOWN={}},[200]={NAME={name='旅顺'},TOWN={}},
  [1]={STATION_GROUP={stations={1100}}},[2]={STATION_GROUP={stations={1101}}},
  [3]={STATION_GROUP={stations={1200}}},[4]={STATION_GROUP={stations={}}},
  [5]={STATION_GROUP={stations={1100,1200}}},
}
local function line(id,name,mode,stops)
  local converted={};for _,group in ipairs(stops)do converted[#converted+1]={stationGroup=group}end
  entities[id]={NAME={name=name},LINE={vehicleInfo={transportModes={[modes[mode]]=true}},stops=converted}}
end
line(10,'市内甲','BUS',{1,2});line(11,'市内乙','BUS',{2,1});line(20,'旅顺公交','BUS',{3})
line(30,'跨城','BUS',{1,3});line(40,'中途出城再返回','BUS',{1,3,2})
line(50,'城市不明','BUS',{1,4});line(60,'铁路','TRAIN',{1,3});line(70,'货运','TRUCK',{1,3})
line(80,'多城市合并站','BUS',{5});line(90,'空线路','BUS',{})
local mappingReads=0
api={type={ComponentType=types,['enum']={TransportMode=modes}},engine={
  entityExists=function(id)return entities[id]~=nil end,
  getComponent=function(id,kind)if id==999 and kind=='GAME_SCRIPT'then return {state=value}end;return entities[id] and entities[id][kind]end,
  forEachEntityWithComponent=function(fn,kind)for id,entity in pairs(entities)do if entity[kind]then fn(id)end end end,
  system={lineSystem={getLines=function()return {90,80,70,60,50,40,30,20,11,10}end},
    stationSystem={getTown=function(id)return ({[1100]=100,[1101]=100,[1200]=200})[id]end,getStation2TownMap=function()mappingReads=mappingReads+1;return {[1100]=100,[1101]=100,[1200]=200}end},
    gameScriptSystem={getEntityForGameScript=function()return 999 end}}},
  cmd={makeScriptingSendEventCmd=function(src,id,name,param)return {src=src,id=id,name=name,param=param}end,
    sendCommand=function(cmd,callback)script.handleEvent({},state,cmd.src,cmd.id,cmd.name,cmd.param);callback(cmd,true)end}}
ug_require=function()return dofile('mod/content/gui/bulb_cockpit/model.lua')end
local C=dofile('mod/content/gui/bulb_cockpit/collect.lua')
local plain=C.listLines();assert(mappingReads==0,'disabled HUD must avoid the extra station/town lookup')
local lines=C.listLines(true);assert(mappingReads==0,'use indexed station lookups, never fetch the whole world town map')
local byId={};for _,l in ipairs(lines)do byId[l.id]=l end
assert(byId[10].busScope=='local' and byId[10].towns[1].id==100)
assert(byId[30].busScope=='express' and byId[40].busScope=='express','inspect intermediate stops, not just endpoints')
assert(byId[80].busScope=='express','inspect all stations in a group')
assert(byId[50].busScope=='unknown' and byId[90].busScope=='unknown','do not guess missing city information')
assert(byId[60].busScope==nil and byId[70].busScope==nil,'exclude rail and freight road lines')
assert(#C.listTowns()==2)
local aliases=A.read();assert(aliases.__busNaming==nil and P.alias(byId[10],aliases,P.defaults(lines,aliases))=='旧10')
local config={enabled=true,format='code_table',expressCode='51',
  districts={['100']={name='杭州',code='10'},['200']={name='旅顺',code='20'}}}
A.saveBusNaming(config,lines,function(_,success)assert(success)end)
aliases=A.read();local defaults=P.defaults(lines,aliases)
assert(P.alias(byId[10],aliases,defaults)=='1001' and P.alias(byId[11],aliases,defaults)=='1002')
assert(P.alias(byId[20],aliases,defaults)=='2001')
assert(P.alias(byId[30],aliases,defaults)=='5101' and P.alias(byId[40],aliases,defaults)=='5102')
assert(P.alias(byId[80],aliases,defaults)=='5103')
assert(aliases.__busNaming.format=='code_table' and aliases.__busNaming.expressCode=='51',
  'store the Express mapping and format alongside the city table')
assert(P.identifier(byId[30],aliases,defaults)=='5101','search/sort uses the complete generated number')
local list=dofile('mod/content/gui/bulb_cockpit/settings.lua')
local found=list.list(lines,aliases,'1001','number','number_asc',P)
assert(#found==1 and found[1].id==10,'identifier search matches the full mapped bus number')
assert(P.parts(byId[10],aliases,defaults).prefix=='' and P.parts(byId[10],aliases,defaults).identifier=='')
assert(P.alias(byId[50],aliases,defaults)=='城市不明' and P.alias(byId[60],aliases,defaults)=='A')
local plan=P.plan({route={lineId=10,name='市内甲',mode='BUS',color='#006db8',stops={
  {name='一站',transfers={{id=30,name='跨城',mode='BUS',color='#ff0000'}}},
  {name='二站',transfers={}}}},lines=lines,next=2,passed=1},aliases,true,800)
assert(plan.badge=='1001' and plan.stops[1].transfers[1].text=='5101','main and transfer badges use the same batch names')
A.save({id=10,name='市内甲'},'快9b',function()end,'BUS',{prefix='快',identifier='9',suffix='b'})
aliases=A.read();assert(aliases.__busNaming.enabled and aliases['10'].autoBus==false)
assert(P.alias(byId[10],aliases,P.defaults(lines,aliases))=='快9b','per-line apply overrides batch naming')
config.enabled=false;A.saveBusNaming(config,lines,function()end)
aliases=A.read();assert(not aliases.__busNaming.enabled and P.alias(byId[10],aliases,P.defaults(lines,aliases))=='快9b')
assert(P.alias(byId[11],aliases,P.defaults(lines,aliases))=='市内乙','disable removes generated names')
assert(value.lines['10'].name=='市内甲' and entities[10].NAME.name=='市内甲','never rename actual game entities')
config.enabled=true;A.saveBusNaming(config,lines,function()end)
aliases=A.read();assert(P.alias(byId[10],aliases,P.defaults(lines,aliases))=='1001','batch reapply resets manual exemptions')
entities[100].NAME.name='新杭州';lines=C.listLines(true);aliases=A.read()
byId={};for _,l in ipairs(lines)do byId[l.id]=l end
assert(P.alias(byId[10],aliases,P.defaults(lines,aliases))~='1001','renamed cities do not inherit stale mappings')
entities[100].NAME.name='杭州';lines=C.listLines(true)
byId={};for _,l in ipairs(lines)do byId[l.id]=l end
local seeded=P.busCodeTable({{id=500,name='甲城'},{id=100,name='乙城'}},{})
assert(not seeded.enabled and seeded.districts['100'].code=='10' and seeded.districts['500'].code=='11'
  and seeded.expressCode=='51','seed by city ID, not name order; keep default off')
local fresh=P.busCodeTable({{id=300,name='新城'}},config)
assert(fresh.districts['100'].code=='10' and fresh.districts['200'].code=='20'
  and fresh.districts['300'].code=='11','new cities use an available prefix without changing existing mappings')
local many={};for i=1,50 do many[i]={id=i,name='城市'..i}end
local table50=P.busCodeTable(many,{})
for _,district in pairs(table50.districts)do assert(district.code~='51','reserve the Express prefix when seeding cities')end
local migrated=P.busCodeTable({{id=100,name='杭州'}},{enabled=true,districts={['100']={name='杭州',code='杭'}}})
assert(migrated.districts['100'].code=='10' and migrated.expressCode=='51','migrate old text prefixes to numeric table defaults')
assert(P.validateBusCodes(config))
assert(not P.validateBusCodes({expressCode='51',districts={['100']={name='杭州',code='51'}}}),'reject duplicate mappings')
assert(not P.validateBusCodes({expressCode='E',districts={}}),'prefixes are numeric')
local hundred={};for i=1,100 do hundred[i]={id=i,name='公交'..i,mode='BUS',busScope='local',towns={{id=100,name='杭州'}}}end
local zeroConfig={enabled=true,format='code_table',expressCode='051',districts={['100']={name='杭州',code='01'}}}
local hundredDefaults=P.defaults(hundred,{__busNaming=zeroConfig})
assert(hundredDefaults['1'].shortName=='0101' and hundredDefaults['99'].shortName=='0199'
  and hundredDefaults['100'].shortName=='01100','preserve leading zeroes; never truncate the serial after 99')
config.districts['100'].code='01';config.expressCode='051'
A.saveBusNaming(config,lines,function()end)
aliases=A.read();defaults=P.defaults(lines,aliases)
assert(aliases.__busNaming.districts['100'].code=='01' and aliases.__busNaming.expressCode=='051',
  'numeric prefixes are saved as strings, preserving zeroes')
assert(P.alias(byId[30],aliases,defaults)=='05101')
config.districts['100'].code='';config.expressCode=''
A.saveBusNaming(config,lines,function()end)
aliases=A.read();defaults=P.defaults(lines,aliases)
assert(P.alias(byId[11],aliases,defaults)=='市内乙' and P.alias(byId[30],aliases,defaults)=='跨城',
  'empty mappings explicitly skip that group')
local before=value
for _,bad in ipairs({{enabled='true',districts={},targets={}},
  {enabled=true,districts={['100']={name='杭州',code={}}},targets={}},
  {enabled=true,districts={},targets={{id=-1,name='bad'}}},
  {enabled=true,format='code_table',expressCode='51',districts={['100']={name='杭州',code='51'}},targets={}},
  {enabled=true,format='code_table',expressCode='E',districts={},targets={}},
  {enabled=true,format='code_table',expressCode='51',districts={['100']={name='杭州',code='杭'}},targets={}}})do
  script.handleEvent({},state,'',A.id,A.busEvent,bad);assert(value==before,'reject invalid batch commands atomically')
end
print('PASS: numeric city/Express mapping table, two-digit serials, migration, validation, persistence, manual overrides and transfer consistency')
