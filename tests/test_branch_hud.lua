local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local function service(id,ids,ink)
    local stops={}
    for i,station in ipairs(ids)do stops[i]={id=station,name='车站 '..station,sourceIndex=i-1,transfers={}}end
    return {id=id,name='线路 '..id,mode='TRAM',color=ink,stops=stops}
  end
  local a,b=service(10,{1,2,3},'#006db8'),service(11,{1,2,4},'#ff0066')
  local graph=assert(G.build({a,b}))
  snapshot={route={lineId=10,name=a.name,mode=a.mode,color=a.color,stops=a.stops},network=graph,
    lines={a,b},next=2,passed=1,vehicle=200}
  aliases={__options={flashNextStop=true}}
  local hud={aliases=aliasState,viewport={x=1280,y=720}}
  tick();local drawn=render('LinnanBulbCockpitHudNative',hud)
  local strokes,diagonals,markers,light,canvas=0,0,0,0
  walk(drawn,function(kind,p)
    local meta=p.meta or {}
    if meta.class and meta.class:find('bulb-branch-stroke',1,true)then
      strokes=strokes+1
      local index=tonumber(meta.class:match('bulb%-track%-angle(%d+)'))
      assert(index and index>=0 and index<=180)
      if index~=90 then diagonals=diagonals+1 end
      local rule
      for _,candidate in ipairs(css)do if candidate.selector=='R::Component!bulb-track-angle'..index then rule=candidate.style end end
      assert(rule and rule.transformOrigin[1]==0 and rule.transformOrigin[2]==.5)
      assert(math.abs(rule.transform.angle-math.rad(index-90))<.00001)
    end
    if meta.class=='bulb-station-marker'then markers=markers+1 end
    if meta.id=='linnan.bulb.canvas'then canvas=p end
  end)
  assert(strokes>=10 and diagonals>=2 and markers==4 and canvas, 'native fork, stripe and exactly one marker per station')
  assert(timers.LinnanBulbFlashingStationNative, 'single next-station animation works inside a branch diagram')
  local function positions(p,ox,oy,result)
    ox,oy=ox or 0,oy or 0;result=result or {}
    if type(p)~='table'then return result end
    if p.kind=='Component' and p.param.meta and p.param.meta.class=='bulb-station-marker'then result[#result+1]={x=ox,y=oy}end
    if p.kind=='FloatingLayoutChild'then
      return positions(p.param.item,ox+p.param.h*canvas.meta.styleSheet.size[1],oy+p.param.v*canvas.meta.styleSheet.size[2],result)
    end
    for _,value in pairs(p)do if type(value)=='table'then positions(value,ox,oy,result)end end
    return result
  end
  local points=positions(canvas.layout)
  local levels={};for _,point in ipairs(points)do levels[point.y]=true end
  local count=0;for _ in pairs(levels)do count=count+1 end
  assert(count==2, 'native station positions must use the branch lane offsets')
  local services={a}
  for id=11,20 do services[#services+1]=service(id,{1,id+100,id+200},'#ff0066')end
  snapshot.network=assert(G.build(services));snapshot.lines=services
  tick();drawn=render('LinnanBulbCockpitHudNative',hud)
  local scaled,frame
  walk(drawn,function(k,p)
    if p.meta and p.meta.id=='linnan.bulb.canvas-content'then scaled=p end
    if p.meta and p.meta.id=='linnan.bulb.canvas'then frame=p end
  end)
  assert(scaled and frame and frame.meta.styleSheet.size[2]<=520, 'many branches fit below the top-left identity')
  assert(scaled.meta.class:match('^bulb%-canvas%-scale%d+$'), 'scale the content inside a physically smaller frame')
  snapshot.mergeWarning='同号组端点不连通'
  snapshot.network=nil;tick()
  local warning=false
  walk(render('LinnanBulbCockpitHudNative',hud),function(k,p)
    if k=='TextView' and p.text:find('同号线路未合并',1,true)then warning=true end
  end)
  assert(warning, 'invalid groups display the current route with an explanation')
  -- Settings runs the scoped check when Apply is clicked, accepts the badge,
  -- and reports a disconnected group without preventing a later bridge edit.
  contexts.LinnanBulbAliasRowNative={}
  local checks=0
  collect.mergeStatus=function(line,candidate)
    checks=checks+1
    assert(line.id==10 and candidate['10'].identifier=='7')
    return 1,'同号线路的实际起终点不连通，未合并；请检查整组线路。'
  end
  local message={old=function(self)return self.value end,set=function(self,v)self.value=v end,hasExpired=function()return false end}
  local row=render('LinnanBulbAliasRowNative',{line=a,lines={a,b},aliases=aliasState,defaults=P.defaults({a,b},aliases),
    geometry=S.geometry({x=1280,y=720}),message=message,lineColor={0,.4,.8,1}})
  walk(row,function(k,p)if p.meta and p.meta.id=='linnan.bulb.identifier.10'then p.onTyping('7')end end)
  row=render('LinnanBulbAliasRowNative',{line=a,lines={a,b},aliases=aliasState,defaults=P.defaults({a,b},aliases),
    geometry=S.geometry({x=1280,y=720}),message=message,lineColor={0,.4,.8,1}})
  walk(row,function(k,p)if p.meta and p.meta.id=='linnan.bulb.save.10'then p.onClick()end end)
  join()
  assert(checks==1 and aliases['10'].identifier=='7' and message.value:find('未合并',1,true))
  free.FreeCamTool.pop();unmounts.LinnanBulbCockpitHudNative()
  assert(not hudVisible, 'branch diagram uses the same synchronous hide and session teardown')
  print('PASS: native fork strokes/stripes/CSS, lane positions, deduplicated markers, opt-in lamp, fallback warning and exit')
end
]=],'@branch_hud'))()
