local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
assert(type(P.trackStyle)=='function','track presentation must depend on the selected display type')
local metro,rer,tram=P.trackStyle('METRO'),P.trackStyle('RER'),P.trackStyle('TRAM')
assert(metro.stripe==0 and metro.ordinarySize>metro.rail,'metro is a solid thin line with larger station dots')
assert(rer.stripe==0 and rer.rail>rer.ordinarySize and rer.ordinaryFill=='white',
  'RER is a thick solid band containing small white dots')
assert(tram.stripe>0 and tram.stripe<tram.rail and tram.ordinarySize>tram.rail,
  'tram has a thin contrasting center stripe and larger dots')
for _,mode in ipairs({'METRO','RER','TRAM','BUS'})do
  local snapshot={next=3,passed=2,route={lineId=90,name='test',mode=mode,stops={
    {name='origin',transfers={}},
    {name='ordinary',transfers={}},
    {name='interchange',transfers={{id=2,name='other line',mode='TRAM',color='#26b775'}}},
    {name='future',transfers={}},
    {name='terminus',transfers={}}}}}
  local plan=P.plan(snapshot,{},false,1280)
  assert(plan.stops[1].markerKind=='terminus' and plan.stops[5].markerKind=='terminus')
  assert(plan.stops[2].markerKind=='ordinary' and plan.stops[3].markerKind=='interchange')
  assert(not plan.stops[1].lit and not plan.stops[2].lit and not plan.stops[3].lit and not plan.stops[4].lit)
  assert(P.plan(snapshot,{},true,1280).stops[3].lit,'next-station blinking is independent of the structural marker')
  assert(plan.track.rail==P.trackStyle(mode).rail)
  assert(plan.geometry.left<40,'bottom diagram must not reserve the removed line-logo column')
  local furthest=0
  for index,stop in ipairs(plan.stops)do
    local x=stop.x
    furthest=math.max(furthest,x+stop.nameWidth*math.cos(math.pi/6),x+stop.markerSize/2)
    for _,group in ipairs(stop.transferGroups)do for _,row in ipairs(group.rows)do
      furthest=math.max(furthest,x-9+row.width)
    end end
  end
  assert(plan.geometry.width-furthest<=13,'trim empty right padding before centering the complete station diagram')
  local override={['90']={name='test',displayMode='RER'}}
  assert(P.plan(snapshot,override,true,1280).track.rail==rer.rail,'manual type changes the track presentation too')
end
print('PASS: metro/RER/tram line ratios, interchange/terminus markers and independent yellow station progress')
