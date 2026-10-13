-- Inspect painted native colors, not only the logical lamp/class flags.
local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local white,yellow={1,1,1,1},{1,.82,0,1}
  local function same(a,b)
    for i=1,4 do if math.abs(a[i]-b[i])>.000001 then return false end end
    return true
  end
  local function markers(tree)
    local result={}
    walk(tree,function(kind,p)
      if kind=='Component' and p.meta.class=='bulb-station-marker'then result[p.meta.tooltip]=p end
    end)
    return result
  end
  local function check(marker,expected,darkCore)
    local fills=0
    walk(marker,function(kind,p)
      if kind=='ImageView' and p.meta.class~='bulb-station-outline'then
        local ink=p.meta.styleSheet.color
        if darkCore and p.path:match('/circle.tga$')then
          assert(ink[1]<.15 and ink[2]<.15 and ink[3]<.15,'flashing terminal OFF keeps its contrasting core')
        else
          assert(same(ink,expected),'actual station fill differs from journey progress: '..marker.meta.tooltip)
        end
        fills=fills+1
      end
    end)
    assert(fills>0)
  end
  for _,mode in ipairs({'METRO','RER','TRAM','BUS'})do
    for _,hex in ipairs({'#ffe077','#006db8'})do
      local route={lineId=900,name='fill '..mode,mode=mode,color=hex,stops={}}
      for i=1,5 do route.stops[i]={id=i,name='fill '..i,sourceIndex=i-1,transfers={}}end
      route.stops[3].transfers={{id=99,name='bus',mode='BUS',color='#ff8800'}}
      for nextStop=0,5 do for _,flashing in ipairs({false,true})do
        aliases={__options={flashNextStop=flashing}}
        snapshot={vehicle=200,route=route,next=nextStop,passed=nextStop==0 and 5 or nextStop-1}
        tick()
        local function shown()
          return markers(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}}))
        end
        local on=shown()
        for i=1,5 do check(assert(on['fill '..i]),nextStop>0 and i>=nextStop and yellow or white)end
        if flashing and nextStop>0 then
          timers.LinnanBulbFlashingStationNative()
          local off=shown()
          for i=1,5 do
            check(assert(off['fill '..i]),i>nextStop and yellow or white,
              i==nextStop and (i==1 or i==5))
          end
        end
      end end
      -- The directory uses this same marker renderer with a static plan.
      -- Its ordinary dots / terminal cores retain BULB's mode palette.
      aliases={};snapshot={static=true,route=route,next=0,passed=0};tick()
      local drawn=markers(render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport={x=1280,y=720}}))
      local ink=hex=='#ffe077' and {1,224/255,119/255,1} or {0,109/255,184/255,1}
      local plan=P.plan(snapshot,{},false,1232)
      for _,stop in ipairs(plan.stops)do
        assert(not stop.showProgress)
        walk(assert(drawn[stop.fullName]),function(kind,p)
          if kind=='ImageView' and p.meta.class=='bulb-station-fill'then
            local expected=stop.markerKind=='interchange' or
              stop.markerKind=='ordinary' and plan.track.ordinaryFill=='white'
            assert(same(p.meta.styleSheet.color,expected and white or ink),'static station palette must remain unchanged')
          end
        end)
      end
    end
  end
  print('PASS: actual white passed/skipped/origin fills, yellow remaining stops, both flash phases, yellow/blue lines and static palettes')
end
]=],'@station_fill'))()
