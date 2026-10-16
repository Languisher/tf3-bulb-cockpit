local f=assert(io.open('tests/test_native.lua'));local harness=f:read('*a');f:close()
assert(load(harness..[=[
do
  local G=dofile('mod/content/gui/bulb_cockpit/merge.lua')
  local function service(id,ids,mode)
    local stops={}
    for i,n in ipairs(ids)do stops[i]={id=n,name='Station '..n,sourceIndex=i-1,transfers={}}end
    stops[1].transfers={{id=999,name='Bus',mode='BUS',color='#ffe077',shortName='1001'}}
    return {id=id,name='Line '..id,mode=mode,color='#abcdef',stops=stops}
  end
  local function near(a,b,msg)assert(math.abs(a-b)<.00001,msg..': '..a..' vs '..b)end
  for _,mode in ipairs({'TRAIN','RER','METRO','TRAM','BUS'})do
    for _,branch in ipairs({false,true})do
      local a,b=service(800,{1,2,3,4},mode),service(801,{5,2,3,4},mode)
      for _,reverse in ipairs({false,true})do
      snapshot={vehicle=200,next=reverse and 2 or 3,passed=reverse and 1 or 2,lines={a,b},
        route={lineId=a.id,name=a.name,mode=mode,color=a.color,stops=a.stops},network=branch and G.build({a,b}) or nil}
      if reverse then snapshot.route.stops={a.stops[4],a.stops[3],a.stops[2],a.stops[1]}end
      collect.read=function()return snapshot end
      for _,percent in ipairs({10,37,100,137,175,250,400})do
        aliases={__options={routeMapScale=percent,flashNextStop=true,language='en'}};tick()
        local viewport={x=2560,y=1800}
        local tree=render('LinnanBulbCockpitHudNative',{aliases=aliasState,viewport=viewport})
        local canvas
        walk(tree,function(_,p)
          local m=p.meta or {}
          assert(not (m.class or ''):find('bulb-canvas-scale',1,true),'diagram must render at final native dimensions, without a raster scale transform')
          if m.id=='linnan.bulb.canvas'then canvas=p end
        end)
        assert(canvas)
        local plan=P.plan(snapshot,aliases,false,math.max(240,math.min(1600,(viewport.x-48)/(percent/100))),nil,B.textWidth)
        local dimensions=canvas.meta.styleSheet.size
        local s=dimensions[1]/plan.geometry.width
        assert(s>0 and s<=percent/100+.00001)
        local marker,nameIndex,railY=0,0,nil
        local railLayer
        for _,child in ipairs(canvas.layout.param.children)do
          local pos=child.param;local item=pos.item;local p=item.param;local m=p.meta or {};local sz=m.styleSheet and m.styleSheet.size
          if m.class=='bulb-station-marker'then
            marker=marker+1;local stop=plan.stops[marker]
            near(pos.h*dimensions[1],stop.x*s,'marker x')
            near(sz[1],stop.markerSize*s,'marker diameter including flashing')
            railY=railY or pos.v*dimensions[2]-(stop.y or 0)*s
            near(pos.v*dimensions[2],railY+(stop.y or 0)*s,'marker lane')
          elseif m.class=='bulb-station-name' or m.class=='bulb-station-terminus-name'then
            nameIndex=nameIndex+1
            assert(m.styleSheet.fontSize==math.max(1,math.floor(14*s+.5)),'station glyphs must be rasterized at their final font size')
            near(sz[1],plan.stops[nameIndex].nameWidth*s,'label width')
          elseif m.class=='bulb-track-layer'then railLayer=p end
        end
        assert(marker==#plan.stops and nameIndex==marker and railY)
        if branch then
          assert(railLayer)
          local painted={}
          for _,child in ipairs(railLayer.layout.param.children)do
            local pos=child.param;local p=pos.item.param;local m=p.meta or {}
            if (m.class or ''):find('bulb-branch-stroke',1,true)then
              painted[pos.localKey]={p=p,x=pos.h*dimensions[1],y=pos.v*dimensions[2]}
            end
          end
          for _,segment in ipairs(plan.rails)do
            local actual=assert(painted[segment.key..':rail'])
            local x,y=segment.x1,segment.y1
            if x>segment.x2 then x,y=segment.x2,segment.y2 end
            near(actual.x,x*s,'branch start x');near(actual.y,railY+y*s,'branch start y')
            near(actual.p.meta.styleSheet.size[1],math.sqrt((segment.x2-segment.x1)^2+(segment.y2-segment.y1)^2)*s,'branch physical length')
            near(actual.p.meta.styleSheet.size[2],plan.track.rail*s,'branch thickness')
          end
        end
        walk(tree,function(kind,p)
          if kind=='TextView' and p.meta and p.meta.class=='bulb-transfer-label'then
            assert(p.meta.styleSheet.fontSize>=math.max(1,math.floor(9*s+.5)),'transfer glyphs scale natively too')
          end
        end)
      end
      end
    end
  end
  print('PASS: native glyph sizes and identical rail/marker/lane scales across modes, branches, directions and zoom levels')
end
]=],'@scaled_geometry'))()
