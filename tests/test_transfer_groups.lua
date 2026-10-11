local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local aliases={}
local function line(id,mode,label,color)
  local value={id=id,name='actual '..mode..id,mode=mode,color=color or '#006db8'}
  aliases[tostring(id)]={name=value.name,displayMode=mode,shortName=label}
  return value
end
local metro6=line(6,'METRO','6','#72c695')
local metro1=line(1,'METRO','1','#ffcd02')
local rer=line(20,'TRAIN','A','#ed1c2a')
local route={lineId=99,name='main',mode='TRAM',stops={
  {name='Charles de Gaulle',transfers={rer,metro6,metro1}},
  {name='Next stop',transfers={metro1,metro6}}}}
local snapshot={route=route,next=1,passed=0}
local plan=P.plan(snapshot,aliases,true,1280)
local groups=plan.stops[1].transferGroups
assert(groups and #groups==2,'one station must group its metro transfers separately from RER')
assert(groups[1].mode=='METRO' and groups[2].mode=='RER','metro precedes RER as in the reference')
assert(#groups[1].lines==2 and #groups[2].lines==1)
assert(groups[1].lines[1].text=='1' and groups[1].lines[2].text=='6')
assert(groups[1].lines[1].color=='#ffcd02' and groups[1].lines[2].color=='#72c695')
assert(plan.transferRows==2 and plan.transferHeight==56,'two metro badges occupy one row, not two')
do
  local bus={}
  for i=1,7 do bus[i]={mode='BUS',text=tostring(1000+i),fullName='公交 '..i}end
  local wrapped,_,rows,height=P.transferGroups(bus,180)
  assert(rows==3 and #wrapped[1].rows[1].lines==3 and #wrapped[1].rows[3].lines==1)
  assert(height<rows*28 and wrapped[1].height==height-4,'compact BUS height must replace the old per-row mode spacing')
  local mixed={bus[1],bus[2],bus[3],bus[4],{mode='BOAT',text='F1',fullName='轮渡'}}
  local modes,_,_,mixedHeight=P.transferGroups(mixed,180)
  assert(#modes==2 and mixedHeight==modes[1].height+4+modes[2].height+4,
    'mode separation is reserved once after all BUS continuation rows')
end
assert(#plan.stops[2].transferGroups==1,'same-mode transfers share a row at every station')
-- Group by the selected display type, including a tram manually rendered as metro.
local tram=line(30,'TRAM','10');aliases['30'].displayMode='METRO'
route.stops[1].transfers={metro6,tram,metro1}
plan=P.plan(snapshot,aliases,true,1280)
assert(#plan.stops[1].transferGroups==1 and #plan.stops[1].transferGroups[1].lines==3)
local labels={}
for _,item in ipairs(plan.stops[1].transferGroups[1].lines)do labels[#labels+1]=item.text end
assert(table.concat(labels,',')=='1,6,10','numeric identifiers retain natural ordering')
-- Stress narrow/wide layouts, mixed modes, many stations, and oversized groups.
for _,mode in ipairs({'METRO','RER','TRAM','BUS','BOAT','AIR','TRUCK'})do
  for _,number in ipairs({1,2,3,6,40})do
    local transfers={}
    for i=1,number do transfers[i]=line(100+i,mode,tostring(i))end
    local stops={}
    for i=1,23 do stops[i]={name='杭州火车站'..i,transfers=transfers}end
    snapshot.route.stops=stops;snapshot.next=17;snapshot.passed=16
    for _,maxWidth in ipairs({240,272,640,1280,1600})do
      plan=P.plan(snapshot,aliases,true,maxWidth)
      local g=plan.geometry
      assert(g.width<=maxWidth and plan.stops[1].index==1 and plan.stops[#plan.stops].index==23)
      local nextShown=false;for _,stop in ipairs(plan.stops)do nextShown=nextShown or stop.index==17 end
      assert(nextShown,'busy interchanges cannot hide the next station')
      for index,stop in ipairs(plan.stops)do
        local x=stop.x
        local seen={}
        for _,group in ipairs(stop.transferGroups)do
          assert(group.mode==mode)
          for _,row in ipairs(group.rows)do
            local mark=B.geometry(mode,true)
            local rowWidth=mark.icon+mark.gap+#row.lines*mark.width+(#row.lines-1)*mark.gap
            assert(row.width==rowWidth,'planner must reserve the renderer\'s actual fixed badge widths')
            assert(x-mark.icon/2>=0 and x-mark.icon/2+row.width<=g.width,
              'every grouped row fits the canvas')
            if index<#plan.stops then
              assert(row.width+14<=plan.stops[index+1].x-stop.x+.001,'adjacent stations cannot overlap their transfer rows')
            end
            for _,item in ipairs(row.lines)do
              assert(not seen[item.fullName],'wrapping cannot duplicate a transfer')
              seen[item.fullName]=true
            end
          end
        end
        local count=0;for _ in pairs(seen)do count=count+1 end
        assert(count==number,'wrapping must retain every transfer line')
      end
    end
  end
end
print('PASS: same-mode horizontal transfer groups; display overrides, ordering, variable spacing, counted omissions and overflow')
