local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local lines={
  {id=40,name='杭州地铁1号线',mode='TRAIN'},
  {id=30,name='另一条电车',mode='TRAM'},
  {id=10,name='铁路南线',mode='TRAIN'},
  {id=50,name='公交1001',mode='BUS'},
  {id=20,name='电车北线',mode='TRAM'},
}
assert(P.mode(lines[1],{})=='TRAIN','all unconfigured railways default to Train, regardless of name')
assert(P.mode(lines[2],{})=='TRAM','unconfigured trams stay TRAM')
for _,actual in ipairs({'TRAIN','TRAM'}) do
  local line={id=1,name='可配置线路',mode=actual}
  for _,choice in ipairs({'TRAIN','RER','METRO','TRAM'}) do
    assert(P.mode(line,{['1']={name=line.name,displayMode=choice}})==choice,
      actual..' can be manually displayed as '..choice)
  end
  assert(P.mode(line,{['1']={name='different save',displayMode='METRO'}})==P.mode(line,{}),
    'stale configuration cannot change another line with the same ID')
end
assert(P.mode({id=1,name='legacy',mode='TRAM'},{['1']={name='legacy',displayMode='TRAIN'}})=='TRAIN',
  'the previous railway selection remains a train/RER after upgrading')
local defaults=P.defaults(lines,{})
assert(defaults['10'].shortName=='A' and defaults['40'].shortName=='B')
assert(defaults['20'].shortName=='T1' and defaults['30'].shortName=='T2')
assert(defaults['50']==nil,'bus numbering is unchanged')
assert(lines[1].id==40,'default numbering must not mutate the settings list order')
assert(P.alias(lines[1],{},defaults)=='B')
assert(P.alias(lines[1],{['40']={name=lines[1].name,shortName='RE7'}},defaults)=='RE7',
  'user abbreviations take precedence over automatic lettering')
assert(P.alias(lines[1],{['40']={name=lines[1].name,shortName=''}},defaults)=='B',
  'clearing an abbreviation restores the default')
local reverse={lines[5],lines[4],lines[3],lines[2],lines[1],lines[1]}
local again=P.defaults(reverse,{})
for id,entry in pairs(defaults) do
  assert(again[id].shortName==entry.shortName,'API enumeration order and duplicates do not change numbers')
end
local renamed={id=40,name='改名后',mode='TRAIN'}
local changed=P.defaults({renamed,lines[3]}, {})
assert(changed['40'].shortName=='B','renaming must not reorder letters')
assert(P.alias(renamed,{['40']={name=lines[1].name,shortName='OLD'}},changed)=='B')
local many={}
for i=1,28 do many[i]={id=i,name='火车'..i,mode='TRAIN'} end
local alphabet=P.defaults(many,{})
assert(alphabet['1'].shortName=='A' and alphabet['26'].shortName=='Z'
  and alphabet['27'].shortName=='AA' and alphabet['28'].shortName=='AB','continue after Z without collisions')
local aliases={['20']={name='电车北线',shortName='',displayMode='RER'},
  ['40']={name='杭州地铁1号线',shortName='',displayMode='METRO'}}
local selected=P.defaults(lines,aliases)
assert(selected['10'].shortName=='A' and selected['20'].shortName=='A')
assert(selected['30'].shortName=='T1' and selected['40'].shortName=='1',
  'type overrides switch to the matching numbering scheme')
local snapshot={lines=lines,next=2,passed=1,route={lineId=30,name='另一条电车',mode='TRAM',color='#123456',stops={
  {name='共用站',transfers={{id=20,name='电车北线',mode='TRAM',color='#ab4567'},
    {id=40,name='杭州地铁1号线',mode='TRAIN',color='#57a123'}}},
  {name='终点',transfers={}}}}}
local plan=P.plan(snapshot,aliases,true,1280)
assert(plan.mode=='TRAM' and plan.badge=='T1')
assert(plan.stops[1].transfers[1].mode=='RER' and plan.stops[1].transfers[1].text=='A')
assert(plan.stops[1].transfers[2].mode=='METRO' and plan.stops[1].transfers[2].text=='1')
assert(plan.stops[1].transfers[1].color=='#ab4567','type selection preserves the game line color')
snapshot.route={lineId=20,name='电车北线',mode='TRAM',stops=snapshot.route.stops}
plan=P.plan(snapshot,aliases,false,1280)
assert(plan.mode=='RER' and plan.badge=='A','the same line keeps its badge in the main diagram and in transfers')
print('PASS: railway/tram manual RER/metro/tram types; default A–Z/AA and T numbering; overrides and transfer consistency')
