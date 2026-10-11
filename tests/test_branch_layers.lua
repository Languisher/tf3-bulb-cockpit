local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local function line(id,path,mode)
    local stops={}
    for i,station in ipairs(path)do
      stops[i]={id=station,name='车站 '..station,sourceIndex=i-1,transfers={}}
    end
    return {id=id,name='线路 '..id,mode=mode,color='#ffe077',stops=stops}
  end
  local cases=0
  for _,mode in ipairs({'RER','TRAM'})do
    local a,b=line(10,{1,2,3,4,5},mode),line(20,{6,7,5},mode)
    local services={a,b};local graph=assert(G.build(services))
    for _,main in ipairs(services)do for _,reverse in ipairs({false,true})do
      local stops={}
      for i=1,#main.stops do stops[i]=main.stops[reverse and #main.stops-i+1 or i]end
      snapshot={route={lineId=main.id,name=main.name,mode=mode,color=main.color,stops=stops},
        network=graph,lines=services,next=2,passed=1,vehicle=200}
      local plan=P.plan(snapshot,{},true,1200)
      local junction
      for _,stop in ipairs(plan.stops)do if stop.id==5 then junction=stop end end
      assert(junction)
      for _,segment in ipairs(plan.segments)do if segment.y1~=segment.y2 then
        local endpoint=junction.x>segment.x2 and segment.x2 or segment.x1
        assert(math.abs(junction.x-endpoint)>=36,
          'both fork directions retain a visible shared horizontal lead beside the junction')
      end end
      tick()
      local tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}})
      local canvas
      walk(tree,function(_,p)if p.meta and p.meta.id=='linnan.bulb.canvas'then canvas=p end end)
      assert(canvas)
      local layer,layerIndex,firstMarker,markers,looseRails=nil,nil,nil,0,0
      for i,child in ipairs(canvas.layout.param.children)do
        local item=child.param.item;local meta=item.param and item.param.meta or {}
        if meta.class=='bulb-track-layer'then
          layer=item;layerIndex=i
          assert(item.param.mouseTransparent==true,'track container cannot intercept static transfer clicks')
          assert(child.param.localKey=='linnan.bulb.track-layer','stable parent owns every newly attached stroke')
        end
        if meta.class and meta.class:find('bulb-branch-stroke',1,true)then looseRails=looseRails+1 end
        if meta.class=='bulb-station-marker'then firstMarker=firstMarker or i;markers=markers+1 end
      end
      assert(layer and looseRails==0,'rails and caps belong to one background container, never station siblings')
      assert(layerIndex<firstMarker and markers==#plan.stops,'station markers paint above the complete track layer')
      local strokes=0
      walk(layer,function(_,p)
        local meta=p.meta or {}
        assert(meta.class~='bulb-station-marker','background never owns station lights')
        if meta.class and meta.class:find('bulb-branch-stroke',1,true)then strokes=strokes+1 end
      end)
      assert(strokes==#plan.rails*(plan.track.stripe>0 and 2 or 1))
      cases=cases+1
    end end
  end
  print('PASS: '..cases..' fork/join directions with shared horizontal leads and isolated background rails across route changes')
end
]=],'@test_branch_layers.lua'))()
