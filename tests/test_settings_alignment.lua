local file=assert(io.open('tests/test_native.lua'));local harness=file:read('*a');file:close()
assert(load(harness..[=[
do
  -- Native size is the content box; account for the same padding used by
  -- builtin.css.lua and the mod stylesheet, instead of treating size as outer bounds.
  local function has(p,class)return (', '..(p.meta and p.meta.class or '')..', '):find(', '..class..', ',1,true)end
  local function padding(kind,p)
    local pad=kind=='TextInputField' and {2,4,2,4} or {0,0,0,0}
    local element=kind=='Component' and 'R::Component' or kind
    for _,rule in ipairs(css)do
      for selector in rule.selector:gmatch('[^,]+')do
        local cls=selector:match('^%s*'..element..'!([%w-]+)%s*$')
        if cls and has(p,cls) and rule.style.padding then pad=rule.style.padding end
      end
    end
    return pad
  end
  local function size(node)
    local p=node.param;local s=p.meta.styleSheet.size;local pad=padding(node.kind,p)
    return s[1]+pad[2]+pad[4],s[2]+pad[1]+pad[3]
  end
  local function positions(component)
    local p=component.param;local pad=padding('Component',p)
    local x=pad[4];local offsets={}
    for _,child in ipairs(p.layout.param.children)do
      offsets[#offsets+1]=x;local width=size(child);x=x+width+8
    end
    local width=size(component)
    assert(x-8+pad[2]<=width+.001,'controls must fit their parent including native padding')
    return offsets
  end
  aliases={['30']={name='城市公交',prefix='',identifier='1001',suffix=''}}
  local roster={{id=10,name='短电车',mode='TRAM'},
    {id=20,name='TP 乘客-杭州-南充-RE-1',mode='TRAIN'},
    {id=30,name='城市公交',mode='BUS'},
    {id=40,name=string.rep('很长的地铁线路名称',12),mode='METRO'}}
  for _,language in ipairs({'zh','en'})do
  aliases.__options={language=language}
  for _,width in ipairs({320,400,640,800,1024,2560})do
    local g=S.geometry({x=width,y=900},language)
    contexts.LinnanBulbBrowserNative={}
    local home=render('LinnanBulbBrowserNative',{aliases=aliasState,lines=roster,geometry=g,
      viewport={x=width,y=900},color=function()return {1,.8,0,1}end})
    walk(home,function(kind,p)
      if kind=='Component' and has(p,'bulb-settings-controls')then positions({kind=kind,param=p})end
    end)
    contexts.LinnanBulbSettingsContentNative={}
    local tree=render('LinnanBulbSettingsContentNative',{aliases=aliasState,lines=roster,geometry=g,
      color=function()return {1,.8,0,1}end})
    local header,rows
    rows={}
    walk(tree,function(kind,p)
      if kind=='Component' and (has(p,'bulb-settings-controls') or has(p,'bulb-settings-footer'))then
        positions({kind=kind,param=p})
      end
      if kind=='Component' and has(p,'bulb-settings-heading')then header={kind=kind,param=p}end
    end)
    local function findRows(node)
      if type(node)~='table'then return end
      if node.recipe=='LinnanBulbAliasRowNative'then rows[#rows+1]=node.param;return end
      for _,value in pairs(node)do if type(value)=='table'then findRows(value)end end
    end
    findRows(tree)
    local offsets=not g.compact and positions(assert(header))
    for _,row in ipairs(rows)do
      contexts.LinnanBulbAliasRowNative={}
      local rendered=render('LinnanBulbAliasRowNative',row)
      local outer=rendered.param.children[1]
      local rw,rh=size(outer)
      assert(rw<=g.content-8 and rh==g.rowHeight,'rows reserve scrollbar space and keep their outer height')
      local cells=outer.param.layout.param.children
      local rowOffsets
      if g.compact then
        positions(cells[1]);positions(cells[2]);positions(cells[3])
        cells=cells[2].param.layout.param.children
        assert(#cells==4 and has(cells[1].param,'bulb-settings-badge'),'compact badge precedes the affix fields')
      else
        rowOffsets=positions(outer)
        assert(#cells==7 and has(cells[2].param,'bulb-settings-badge'),'a dedicated badge column precedes prefix')
        for i,x in ipairs(offsets)do assert(x==rowOffsets[i],'all headings align with their data column')end
      end
      local badgeCell=cells[g.compact and 1 or 2]
      local floating=badgeCell.param.layout.param.children[1].param
      local mark=floating.item.param.meta.styleSheet
      assert(floating.h==.5 and floating.v==.5 and mark.anchorPoint[1]==.5 and mark.anchorPoint[2]==.5,
        'badge shares the center of its fixed cell regardless of name or badge shape')
      local bw,bh=size(badgeCell)
      assert(mark.size[1]<=bw and mark.size[2]<=bh)
      walk(rendered,function(kind,p)
        if kind=='TextInputField' and (p.meta.id:find('.prefix.',1,true) or p.meta.id:find('.suffix.',1,true))then
          assert(p.placeholderText=='','empty affixes have no placeholder')
        end
      end)
    end
    assert(#rows==4)
  end
  end
end
print('PASS: bilingual native content/padding bounds, aligned badge and field columns, empty affixes at six viewport widths')
]=],'@test_settings_alignment.lua'))()
