local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  -- The native Button::Layout centers its content. A top-left content anchor
  -- makes the visible badge start at that center and overflow the hit target.
  local function centered(button)
    local size=assert(button.meta.styleSheet.size)
    local content=assert(button.content.param.meta.styleSheet)
    local badgeSize,anchor=assert(content.size),assert(content.anchorPoint)
    for axis=1,2 do
      local first=size[axis]/2-badgeSize[axis]*anchor[axis]
      local last=first+badgeSize[axis]
      assert(first>=-0.001 and last<=size[axis]+0.001,'badge must stay inside its native hover/click bounds')
      assert(math.abs((first+last)/2-size[axis]/2)<0.001,'badge must share the native button center')
    end
    return size,badgeSize
  end
  local roster={}
  aliases={}
  for _,mode in ipairs({'METRO','RER','TRAM','BUS'})do
    for i=1,21 do
      local id=#roster+1
      roster[id]={id=id,name=mode..' route '..i,mode=mode,color='#e0b332'}
      aliases[tostring(id)]={name=roster[id].name,prefix=mode=='TRAM' and 'T' or '',
        identifier=mode=='RER' and string.char(64+i) or tostring(i),suffix=''}
    end
  end
  for _,viewportWidth in ipairs({320,640,1280,2560})do
    local name='LinnanBulbBrowserNative'
    contexts[name]={}
    local g=S.geometry({x=viewportWidth,y=720})
    local param={aliases=aliasState,lines=roster,geometry=g,viewport={x=viewportWidth,y=720},
      color=function()return {.9,.7,.2,1}end,onClose=function()end}
    local home=render(name,param)
    local search
    walk(home,function(_,p)if p.meta and p.meta.id=='linnan.bulb.browser.bus-search'then search=p end end)
    assert(search);search.onTyping('route')
    home=render(name,param)
    local buttons,rows=0,0
    walk(home,function(kind,p)
      if kind=='Button' and p.meta.class=='bulb-directory-tile'then
        local size,badgeSize=centered(p)
        assert(size[1]<=44 and size[2]<=32,'directory hit targets must use the compact grid')
        assert(badgeSize[1]<=34 and badgeSize[2]<=24,'directory badges must use the small symbol geometry')
        buttons=buttons+1
      end
      if kind=='Component' and p.meta.class=='bulb-directory-row'then
        local children=p.layout.param.children
        local width=0
        for _,child in ipairs(children)do width=width+child.param.meta.styleSheet.size[1]end
        width=width+math.max(0,#children-1)*8
        assert(width<=g.content-32,'grid must wrap before overflowing the section')
        rows=rows+1
      end
    end)
    assert(buttons==84 and rows>=4,'all four supported modes must use the same aligned grid')
    unmounts[name]()
  end
  local single,group=B.create(builtin,function(v)return {styleSheet=v}end,
    function()return builtin.TextView{}end,function()return builtin.ImageView{}end)
  for _,mode in ipairs({'METRO','RER','TRAM','BUS'})do
    local clicked=0
    local tree=group(mode,{{y=0,lines={{text=mode=='RER' and 'A' or 'T1',fill={.9,.7,.2,1},
      fullName='Transfer',onClick=function()clicked=clicked+1 end}}}})
    local count=0
    walk(tree,function(kind,p)
      if kind=='Button'then
        centered(p)
        assert(p.meta.styleSheet.anchorPoint[1]==0 and p.meta.styleSheet.anchorPoint[2]==0,
          'absolute transfer button placement must keep its top-left anchor')
        p.onClick();count=count+1
      end
    end)
    assert(count==1 and clicked==1)
    local hud=single(mode,'A',{.9,.7,.2,1},false)
    assert(hud.param.meta.styleSheet.anchorPoint[1]==0 and hud.param.meta.styleSheet.anchorPoint[2]==0,
      'HUD marks must retain their absolute placement')
  end
end
print('PASS: compact directory grid and centered badge hit bounds at four viewport widths; transfer clicks and HUD anchors')
]=],'@test_badge_buttons.lua'))()
