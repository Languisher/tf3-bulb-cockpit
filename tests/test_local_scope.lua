local base='mod/content/gui/bulb_cockpit/'
local fixture=dofile('tests/performance_fixture.lua')
-- Keep 8 actual transfers while adding unrelated lines and associations.
local function run(count,cities)
  local f=fixture(base,count,32,9)
  local links={{a={id=10001},b={id=10002}}}
  for i=1,200 do
    local a,b=700000+i*2,700001+i*2
    f.components[a]={STATION_GROUP={}};f.components[b]={STATION_GROUP={}}
    links[#links+1]={a={id=a},b={id=b}}
  end
  local raw=api.engine.getComponent
  api.engine.getComponent=function(id,kind)
    assert(id<700000,'unrelated station associations must not be queried')
    if id<count and id>9 then error('unrelated line read: '..id)end
    return raw(id,kind)
  end
  local cache={}
  for tick=0,119 do
    local value=f.collect.read(f.vehicle,cities,links,cache,tick*.5)
    assert(value and #value.lines==9)
  end
  assert(not f.calls.roster and not f.calls.townMap,'HUD must never request global indexes')
  assert(f.calls.transfers==32,'only initialize current route transfers once')
  assert(f.calls.component<(cities and 480 or 220),'local route component-read budget')
  return f.calls.component
end
for _,cities in ipairs({false,true})do
  assert(run(20,cities)==run(300,cities),'unrelated map size cannot increase HUD component queries')
end
print('PASS: local current-line/transfer/association scope; zero global HUD indexes; world-size independent API budget')
