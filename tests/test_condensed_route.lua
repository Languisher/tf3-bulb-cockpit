local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local route={lineId=500,name='长线路',mode='TRAM',stops={}}
for i=1,64 do route.stops[i]={id=1000+i,name='车站 '..i,transfers={}}end
local snapshot={route=route,next=32,passed=31}
local plan=P.plan(snapshot,{},true,640)
assert(plan.stops[1].index==1 and plan.stops[#plan.stops].index==64,
  'condensed routes must retain the actual origin and terminus, not a page')
assert(plan.gaps and #plan.gaps>0,'omitted stops must be explicit counted rail segments')
local shown,hidden,nextVisible=0,0,false
for _,stop in ipairs(plan.stops)do
  shown=shown+1
  nextVisible=nextVisible or stop.index==32
  assert(stop.lit==(stop.index==32),'only the condensed next stop lights')
end
for _,gap in ipairs(plan.gaps)do
  assert(gap.count==gap.last-gap.first+1 and gap.count>0)
  assert(gap.text:find(tostring(gap.count),1,true),'omission labels expose the hidden station count')
  hidden=hidden+gap.count
end
assert(nextVisible and shown+hidden==64,'each real station is either visible or counted exactly once')
for _,stop in ipairs(P.plan(snapshot,{},false,640).stops)do
  assert(not stop.lit,'the condensed next station still has a real OFF phase')
end
local bus={}
for i=1,8 do bus[i]={text=tostring(1000+i),fullName='公交 '..i,mode='BUS',color='#ffcc00'}end
local groups,_,rows=P.transferGroups(bus,1600)
assert(rows==3 and #groups[1].rows[1].lines==3 and #groups[1].rows[3].lines==2,
  'bus transfers wrap after three even with abundant horizontal space')
local g=B.geometry('BUS',true)
assert(g.width<38 and g.font>9 and math.abs(g.width/g.height-20/9)<.001,
  'small bus blocks are more compact, with a larger font and the BULB aspect ratio')
local label,size=B.fit('1001',g.width*.8,g.font,g.minFont)
assert(label=='1001' and size>=11,'standard four-digit bus numbers stay readable without truncation')
local short={lineId=1,name='混合站距',mode='TRAM',stops={
  {name='一',transfers={}},{name='二',transfers={}},{name='三',transfers={}},
  {name='四',transfers={}}, {name='五',transfers={}}}}
for i=1,3 do short.stops[3].transfers[i]={id=i+100,name='Bus '..(1000+i),mode='BUS'}end
plan=P.plan({route=short,next=3,passed=2},{},true,1280)
assert(#plan.stops==5 and #plan.gaps==0,'short routes remain complete')
assert(plan.stops[4].x-plan.stops[3].x>plan.stops[2].x-plan.stops[1].x,
  'a busy interchange has more horizontal room than adjacent simple stations')
for _,width in ipairs({240,272,400,640,1280,1600})do
  for _,target in ipairs({1,2,3,31,32,62,63,64})do
    snapshot.next=target;snapshot.passed=target-1
    plan=P.plan(snapshot,{},true,width)
    assert(plan.geometry.width<=width and plan.stops[1].index==1 and plan.stops[#plan.stops].index==64)
    local actual,counted={},0
    for _,stop in ipairs(plan.stops)do actual[stop.index]=true;counted=counted+1 end
    assert(actual[target],'next station remains visible throughout the route')
    for _,gap in ipairs(plan.gaps)do
      for index=gap.first,gap.last do assert(not actual[index]);actual[index]=true;counted=counted+1 end
    end
    assert(counted==64,'no station disappears from the condensed accounting')
  end
end
-- Hidden stations must not all incur text/transfer layout on each HUD refresh.
local huge={lineId=1,name='超长线',mode='TRAM',stops={}}
for i=1,2000 do huge.stops[i]={name='站 '..i,transfers={}}end
local originalGroups,layouts=P.transferGroups,0
P.transferGroups=function(...)layouts=layouts+1;return originalGroups(...)end
local bounded=P.plan({route=huge,next=1000,passed=999},{},true,640)
P.transferGroups=originalGroups
assert(layouts<=64,'hidden stations must not require full transfer layout')
assert(bounded.stops[1].index==1 and bounded.stops[#bounded.stops].index==2000)
print('PASS: origin/next/terminus condensation, counted omissions, variable spacing and compact readable bus badges with three per row')
