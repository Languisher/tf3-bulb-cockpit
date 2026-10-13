local base='mod/content/gui/bulb_cockpit/'
local S,P,B=dofile(base..'settings.lua'),dofile(base..'native_model.lua'),dofile(base..'mode_marks.lua')
local lines={{id=1,name='Bus T1',mode='BUS'},{id=2,name='Cargo road',mode='TRUCK'},
  {id=3,name='Tram T1',mode='TRAM'},{id=4,name='Rail T1',mode='TRAIN'},
  {id=5,name='Ship',mode='BOAT'},{id=6,name='Air',mode='AIR'}}
local aliases={['1']={name=lines[1].name,displayMode='RER',identifier='1',prefix='T',suffix=''},
  ['3']={name=lines[3].name,displayMode='TRAIN'},['4']={name=lines[4].name,displayMode='METRO'}}
local road=S.list(lines,aliases,'','all','name',P,{[1]=true})
assert(#road==2 and road[1].id==1 and road[2].id==2,'road includes bus/truck regardless of custom display type')
assert(#S.list(lines,aliases,'T1','number','name',P,{[1]=true})==1,'combine final badge search and carrier filter')
assert(#S.list(lines,aliases,'','all','name',P,{[2]=true})==1,'tram uses its actual carrier')
local rail=S.list(lines,aliases,'','all','name',P,{[3]=true})
assert(#rail==1 and rail[1].id==4,'manual Metro on rail remains in the rail filter')
assert(#S.list(lines,aliases,'','all','name',P,{[4]=true})==1)
assert(#S.list(lines,aliases,'','all','name',P,{[5]=true})==1)
assert(#S.list(lines,aliases,'','all','name',P,{[1]=true,[3]=true})==3,'multiple choices are a union')
assert(#S.list(lines,aliases,'','all','name',P,{})==6,'no selected categories shows all lines, like the native control')
local fr=dofile(base..'locales/fr.lua')['返回线路目录']
local width=S.backWidth(fr,500,B)
assert(width>=B.textWidth(fr,19)+24,'French back caption fits the largest native body font')
assert(S.backWidth(fr,120,B)==120,'narrow layouts retain an explicit bound')
print('PASS: native carrier filters, actual transport vs display type, query intersection, multi-select and French return width')
local f=assert(io.open('tests/test_native.lua'));local harness=f:read('*a');f:close()
assert(load(harness..[=[
do
  aliases={__options={language='en'}}
  local roster={{id=1,name='Road',mode='BUS'},{id=2,name='Tram',mode='TRAM'},{id=3,name='Rail',mode='TRAIN'}}
  contexts.LinnanBulbSettingsContentNative={}
  local param={aliases=aliasState,lines=roster,geometry=S.geometry({x=1280,y=720},'en'),color=function()return {1,1,0,1}end}
  local function find(v,recipe,result)
    if type(v)~='table'then return end
    if v.recipe==recipe then result[#result+1]=v.param;return end
    for _,child in pairs(v)do if type(child)=='table'then find(child,recipe,result)end end
  end
  local function shown()
    local tree=render('LinnanBulbSettingsContentNative',param);local rows,filter={},{}
    find(tree,'LinnanBulbAliasRowNative',rows);find(tree,'LinnanBulbCarrierFilterNative',filter)
    return rows,assert(filter[1])
  end
  local rows,filter=shown();assert(#rows==3)
  api.type={['enum']={Carrier={ROAD=1,TRAM=2,RAIL=3,WATER=4,AIR=5}}}
  local function buttons()
    local list={}
    walk(render('LinnanBulbCarrierFilterNative',filter),function(kind,p)
      if kind=='ToggleButton'then list[#list+1]=p end
    end)
    return list
  end
  local before=reads
  buttons()[1].onValueChange(1)
  rows=shown();assert(#rows==1 and rows[1].line.mode=='BUS')
  buttons()[3].onValueChange(1)
  rows=shown();assert(#rows==2)
  buttons()[1].onValueChange(0);buttons()[3].onValueChange(0)
  rows=shown();assert(#rows==3 and reads==before,'filter changes reuse the already loaded roster')
  assert(not timers.LinnanBulbCarrierFilterNative)
  print('PASS: actual settings row filtering, multi-select/no-selection reset, zero vehicle reads and no filter timer')
end
]=],'@carrier_filter_ui'))()
