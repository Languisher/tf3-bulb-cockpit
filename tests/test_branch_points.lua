local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local function service(id,path,mode)
    local stops={}
    for i,station in ipairs(path)do
      stops[i]={id=station,name='站 '..station,sourceIndex=i-1,transfers={}}
      if station==7 or station==9 then
        stops[i].transfers={{id=99,name='公交 99',mode='BUS',color='#ff8800'}}
      end
    end
    return {id=id,name='线路 '..id,mode=mode,color='#006db8',stops=stops}
  end
  local function markers(tree)
    local result={}
    walk(tree,function(kind,p)
      if kind=='Component' and p.meta and p.meta.class=='bulb-station-marker'then
        result[p.meta.tooltip]=p
      end
    end)
    return result
  end
  local function isWhite(ink)return ink and ink[1]==1 and ink[2]==1 and ink[3]==1 and ink[4]==1 end
  local cases=0
  -- Three alternatives, with ordinary, interchange and terminal stops.
  -- Keep this HUD context while switching the followed member and direction.
  for _,mode in ipairs({'METRO','RER','TRAM','BUS'})do
    local lines={service(10,{1,2,3,4,5},mode),service(20,{6,7,8,5},mode),service(30,{9,10,5},mode)}
    local graph=assert(G.build(lines))
    for _,main in ipairs(lines)do for _,reverse in ipairs({false,true})do
      local stops,active={},{}
      for i=1,#main.stops do
        stops[i]=main.stops[reverse and #main.stops-i+1 or i];active[stops[i].id]=i
      end
      snapshot={route={lineId=main.id,name=main.name,mode=mode,color=main.color,stops=stops},
        network=graph,lines=lines,next=2,passed=1,vehicle=200}
      for _,flashing in ipairs({false,true})do
        aliases={__options={flashNextStop=flashing}}
        local plan=P.plan(snapshot,aliases,not flashing,1600)
        tick()
        local tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1648,y=900}})
        local drawn=markers(tree)
        local lamps,targets=0,0
        for _,stop in ipairs(plan.stops)do
          local inactive=active[stop.id]==nil
          if inactive then
            assert(not stop.lit and not stop.isNext,'alternative stations never enter the light/blink state')
            local marker=assert(drawn[stop.fullName])
            local fills=0
            walk(marker,function(kind,p)
              if kind=='ImageView'then
                assert(p.meta.class~='bulb-station-light','alternative stations cannot glow')
                if p.meta.class~='bulb-station-outline'then
                  assert(isWhite(p.meta.styleSheet.color),'alternative station interiors and cores are solid white')
                  fills=fills+1
                end
              end
            end)
            assert(fills>0)
          elseif stop.index<snapshot.next then
            assert(not stop.lit,'passed stations on the followed branch stay off')
            walk(assert(drawn[stop.fullName]),function(kind,p)
              if kind=='ImageView' and p.meta.class=='bulb-station-light'then lamps=lamps+1 end
            end)
          end
          if stop.index and stop.index>snapshot.next then
            assert(stop.lit,'future served stations stay yellow in both phases')
          end
          if stop.isNext then
            targets=targets+1;assert(active[stop.id] and not stop.offRoute)
          end
        end
        assert(lamps==0,'passed active-branch stations have no yellow lamps')
        assert(targets==1 and (timers.LinnanBulbFlashingStationNative~=nil)==flashing,
          'only the current vehicle target owns the optional lamp timer')
        if flashing then
          timers.LinnanBulbFlashingStationNative()
          local off=markers(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1648,y=900}}))
          for _,stop in ipairs(plan.stops)do if not active[stop.id]then
            walk(assert(off[stop.fullName]),function(kind,p)
              if kind=='ImageView' and p.meta.class~='bulb-station-outline'then
                assert(isWhite(p.meta.styleSheet.color),'alternative stations remain white during the OFF phase')
              end
            end)
          end end
        end
        cases=cases+1
      end
      -- Directory diagrams show the complete network without a vehicle's
      -- service selection: preserve the normal BULB station colors there.
      snapshot.static=true;snapshot.next=0;snapshot.passed=0
      local plan=P.plan(snapshot,{},false,1600)
      for _,stop in ipairs(plan.stops)do
        assert(not stop.offRoute and not stop.lit and not stop.isNext)
      end
    end end
  end
  print('PASS: '..cases..' current-branch white alternatives, shared active stops, member/direction changes and optional target blinking')
end
]=],'@test_branch_points.lua'))()
