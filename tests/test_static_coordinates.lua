local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  local browserName,staticName='LinnanBulbBrowserNative','LinnanBulbStaticRouteNative'
  local roster={{id=10,name='TP 乘客-杭州-南充-RE-1',mode='RER',color='#ffe077'},
    {id=20,name='RER B',mode='RER',color='#ffe077'}}
  aliases={}
  for _,line in ipairs(roster)do aliases[tostring(line.id)]={name=line.name,identifier=line.id==10 and 'A' or 'B'}end
  for i=1,6 do
    local id=20+i
    roster[#roster+1]={id=id,name='Tram '..i,mode='TRAM',color='#ffe077'}
    aliases[tostring(id)]={name='Tram '..i,prefix='T',identifier=tostring(i),suffix=''}
  end
  collect.readLine=function()
    return {static=true,next=0,passed=0,lines=roster,route={lineId=10,name=roster[1].name,mode='RER',
      color='#ffe077',stops={
        {id=1,name='杭州站',transfers={roster[2],roster[3],roster[4]}},
        {id=2,name='旅顺北站',transfers={roster[5],roster[7]}},
        {id=3,name='日照站',transfers={roster[8]}},
        {id=4,name='南充站',transfers={roster[6]}}}}}
  end
  for _,viewport in ipairs({{x=640,y=720},{x=1925,y=1083}})do
    contexts[browserName]={};contexts[staticName]={}
    local param={aliases=aliasState,lines=roster,geometry=S.geometry(viewport),viewport=viewport,
      color=function()return {1,.88,.47,1}end,onClose=function()end}
    local home=render(browserName,param)
    walk(home,function(_,p)if p.meta and p.meta.id=='linnan.bulb.browser.line.10'then p.onClick()end end)
    local selected
    local function recipe(node)
      if type(node)~='table'then return end
      if node.recipe==staticName then selected=node.param end
      for _,child in pairs(node)do if type(child)=='table'then recipe(child)end end
    end
    recipe(render(browserName,param));assert(selected)
    render(staticName,selected);mounts[staticName]();join()
    local tree=render(staticName,selected)
    local canvas,header
    walk(tree,function(kind,p)
      if kind~='Component'then return end
      local meta=p.meta or {}
      if meta.id=='linnan.bulb.static-canvas'then canvas=p end
      if meta.class=='bulb-mode-mark'then header=p end
      if meta.id=='linnan.bulb.static-canvas' or meta.class=='bulb-mode-mark' or meta.class=='bulb-mode-icon'
        or meta.class=='bulb-transfer-group' or meta.class=='bulb-line-tile'then
        local frame=meta.styleSheet.size
        local layout=assert(p.layout.param.meta,'fixed artwork must explicitly size its internal layout')
        assert(layout.class=='bulb-fixed-layout')
        assert(layout.styleSheet==nil,'layout classes must not introduce WithComponentParams around native Layouts')
        local inner={0,0}
        for _,child in ipairs(p.layout.param.children)do
          local size=child.param.item.param.meta.styleSheet.size
          inner[1]=math.max(inner[1],size[1]);inner[2]=math.max(inner[2],size[2])
        end
        assert(inner[1]==frame[1] and inner[2]==frame[2],'inner coordinates must use the measured artwork dimensions')
      end
    end)
    assert(canvas and header)
    local fixed,scroll
    for _,rule in ipairs(css)do
      if rule.selector=='FloatingLayout!bulb-fixed-layout'then fixed=rule.style end
      if rule.selector=='ScrollArea#linnan.bulb.browser.map ScrollArea::Content::Layout'then scroll=rule.style end
    end
    assert(fixed and fixed.gravity[1]==0 and fixed.gravity[2]==0,'fixed coordinates must not stretch')
    assert(scroll and scroll.gravity[1]==0 and scroll.gravity[2]==0,'static scroll content must retain its intrinsic width')
    -- Resolve the real render tree with a viewport wider than the diagram.
    -- r46 let ScrollArea stretch this width while the rail kept a fixed size.
    local markers,rails,icons,buttons={},{},{},{}
    local function visit(node,x,y,available)
      local p=node.param
      if node.kind=='FloatingLayout'then
        local extent={0,0}
        for _,child in ipairs(p.children)do
          local size=child.param.item.param.meta.styleSheet.size
          extent[1]=math.max(extent[1],size[1]);extent[2]=math.max(extent[2],size[2])
        end
        for _,child in ipairs(p.children)do
          local pos=child.param;local item=pos.item
          local meta=item.param.meta;local size=meta.styleSheet.size;local anchor=meta.styleSheet.anchorPoint or {0,0}
          visit(item,x+pos.h*extent[1]-anchor[1]*size[1],y+pos.v*extent[2]-anchor[2]*size[2],size)
        end
      elseif node.kind=='Component'then
        local meta=p.meta or {};local size=meta.styleSheet.size
        if meta.class=='bulb-station-marker'then markers[#markers+1]={x=x+size[1]/2,y=y+size[2]/2}end
        if meta.class=='bulb-track'then rails[#rails+1]={x=x,right=x+size[1],y=y+size[2]/2}end
        if meta.class=='bulb-mode-icon'then icons[#icons+1]={x=x,right=x+size[1],y=y+size[2]/2}end
        if p.layout then visit(p.layout,x,y,size)end
      elseif node.kind=='Button'then
        local size=p.meta.styleSheet.size;local content=p.content.param.meta.styleSheet
        buttons[#buttons+1]={x=x,right=x+size[1],y=y+size[2]/2}
        visit(p.content,x+size[1]/2-content.anchorPoint[1]*content.size[1],
          y+size[2]/2-content.anchorPoint[2]*content.size[2],content.size)
      end
    end
    visit(canvas.layout,0,0,{param.geometry.content,canvas.meta.styleSheet.size[2]})
    assert(#markers==4 and #rails==1 and #buttons==7)
    assert(math.abs(rails[1].x-markers[1].x)<.001 and math.abs(rails[1].right-markers[4].x)<.001,
      'full track must connect the first and final station centers at every viewport width')
    for _,marker in ipairs(markers)do assert(math.abs(marker.y-rails[1].y)<.001)end
    -- T3 and T5 at the second stop must be separate, level, clickable badges.
    assert(buttons[4].right<buttons[5].x and math.abs(buttons[4].y-buttons[5].y)<.001)
    for _,icon in ipairs(icons)do
      local linked=false
      for _,marker in ipairs(markers)do if math.abs((icon.x+icon.right)/2-marker.x)<.001 then linked=true end end
      assert(linked,'each transport icon must center on its station connector')
    end
    unmounts[staticName]();unmounts[browserName]()
  end
end
print('PASS: fixed static canvas/header/icon extents, continuous rail and aligned clickable transfer groups in narrow/wide scroll areas')
]=],'@test_static_coordinates.lua'))()
