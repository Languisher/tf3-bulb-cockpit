local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local builtin={type={ImageViewScaling={Stretch='stretch'}}}
for _,kind in ipairs({'ImageView','Component','FloatingLayout','FloatingLayoutChild'})do
  builtin[kind]=function(param)return {kind=kind,param=param}end
end
local function text(value,font,width,height,ink,_,class,anchor,tooltip)
  return {kind='TextView',param={text=value,meta={class=class,tooltip=tooltip,
    styleSheet={size={width,height},color=ink,fontSize=font}}}}
end
local single,group,badge=B.create(builtin,function(value)return {styleSheet=value}end,text,
  function(mode,size)return {kind='ImageView',param={path=mode,meta={styleSheet={size={size,size}}}}}end)
assert(type(group)=='function','the renderer must expose a shared-icon horizontal transfer row')
local function walk(node,fn)
  if type(node)~='table'then return end
  if node.kind then fn(node.kind,node.param)end
  for _,value in pairs(node)do if type(value)=='table'then walk(value,fn)end end
end
-- The same numeric badge path is used by identity, directory and transfers.
for _,small in ipairs({true,false})do
  local diameter=small and 24 or 38
  for _,label in ipairs({'1','8','10','18','99','1bis','123456789'})do
    local function check(tree)
      local seen=false
      walk(tree,function(kind,p)
        if kind=='TextView' and (p.meta.class=='bulb-line-badge' or p.meta.class=='bulb-transfer-label')then
          seen=true
          local st=p.meta.styleSheet
          assert(B.textWidth(p.text,st.fontSize)<=st.size[1]+.001 and st.size[2]<=diameter,
            'fitted metro labels stay inside their unchanged badge bounds')
          if label:match('^%d%d?$')then
            assert(p.text==label and st.fontSize>=(small and (#label==1 and 20 or 18) or (#label==1 and 32 or 29)),
              'one/two digit metro numbers must use the enlarged type')
          end
        end
      end)
      assert(seen)
    end
    check(single('METRO',label,{1,.8,0,1},small))
    check(badge('METRO',label,{1,.8,0,1},small))
    if small then check(group('METRO',{{y=0,lines={{text=label,fullName='Metro',fill={1,.8,0,1}}}}}))end
  end
end
for _,mode in ipairs({'METRO','RER','TRAM','BUS','BOAT','AIR','TRUCK'})do
  local lines={{text=mode=='RER' and 'A' or '1',fullName='full line one',fill={1,.8,0,1}},
    {text=mode=='RER' and 'B' or '6',fullName='full line six',fill={.2,.7,.5,1}}}
  local tree,width,height=group(mode,{{lines=lines,y=0}})
  local g=B.geometry(mode,true)
  assert(width==g.icon+g.gap+g.width*2+g.gap and height==24)
  assert(tree.param.meta.styleSheet.backgroundColor[4]==0)
  local iconCount,colors,labels=0,{},{}
  walk(tree,function(kind,param)
    local meta=param.meta
    if kind=='Component' and meta.class=='bulb-mode-icon'then iconCount=iconCount+1 end
    if kind=='ImageView' and meta.class=='bulb-shape-'..g.shape then
      colors[#colors+1]=meta.styleSheet.color
      assert(meta.tooltip=='full line one' or meta.tooltip=='full line six')
    end
    if kind=='TextView' and meta.class=='bulb-transfer-label'then labels[param.text]=true end
  end)
  assert(iconCount==1,'one mode symbol serves all badges in its row')
  assert(colors[1]==lines[1].fill and colors[2]==lines[2].fill,'each badge keeps its own game color')
  if mode~='RER'then assert(labels['1'] and labels['6'])end
  local lastRight=0
  for _,child in ipairs(tree.param.layout.param.children)do
    local positioned=child.param
    local size=positioned.item.param.meta.styleSheet.size
    local x=positioned.h*width
    assert(x>=0 and x+size[1]<=width+.001,'row content cannot overflow its fixed component')
    if positioned.item.kind=='Component'then
      assert(math.abs(x)<.001 and math.abs(positioned.v*height+size[2]/2-height/2)<.001)
    end
    lastRight=math.max(lastRight,x+size[1])
  end
  assert(math.abs(lastRight-width)<.001,'the last badge ends exactly at the row boundary')
end
local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
for _,count in ipairs({1,3,4,7,8})do
  for _,available in ipairs({60,100,180})do
    local lines={}
    for i=1,count do lines[i]={mode='BUS',text=tostring(1000+i),fullName='公交 '..i,fill={i/10,.8,.2,1}}end
    local planned,_,_,reserved=P.transferGroups(lines,available)
    local bus=planned[1]
    local tree,width,height=group('BUS',bus.rows)
    assert(width==bus.width and height==bus.height and reserved==height+4,
      'planner and renderer must agree on the entire wrapped group footprint')
    local icons,seen,boxes=0,{},{}
    walk(tree,function(kind,p)
      if kind=='Component' and p.meta.class=='bulb-mode-icon'then icons=icons+1 end
      if kind=='TextView' and p.meta.class=='bulb-transfer-label'then
        assert(not seen[p.text],'wrapping cannot duplicate bus numbers')
        seen[p.text]=true
      end
    end)
    for _,child in ipairs(tree.param.layout.param.children)do
      local pos=child.param;local p=pos.item.param
      local w,h=table.unpack(p.meta.styleSheet.size)
      local x,y=pos.h*width,pos.v*height
      assert(x>=0 and y>=0 and x+w<=width+.001 and y+h<=height+.001,
        'every icon and badge must stay inside the shared group')
      if p.meta.class=='bulb-mode-icon'then
        assert(math.abs(y+h/2-12)<.001,'the shared icon stays beside the first row')
      elseif p.meta.class=='bulb-shape-bus-frame'then
        boxes[#boxes+1]={x=x,y=y,w=w,h=h}
      end
    end
    assert(icons==1 and #boxes==count)
    for i=1,count do assert(seen[tostring(1000+i)])end
    local perRow={}
    for i,a in ipairs(boxes)do
      local row=math.floor(a.y+.5);perRow[row]=(perRow[row] or 0)+1
      assert(perRow[row]<=3,'a bus row never contains more than three numbers')
      for j=i+1,#boxes do
        local b=boxes[j]
        assert(a.x+a.w<=b.x+.001 or b.x+b.w<=a.x+.001
          or a.y+a.h<=b.y+.001 or b.y+b.h<=a.y+.001,'wrapped bus badges cannot overlap')
      end
    end
    if #bus.rows>1 then
      assert(bus.rows[2].y>15.3 and bus.rows[2].y<28,'continuations have compact, legible row spacing')
      local nextRow=boxes[#bus.rows[1].lines+1]
      assert(math.abs(nextRow.x-boxes[1].x)<.001,'all continuation rows keep the first badge column')
    end
  end
end
print('PASS: same-mode transfers share one first-row icon; compact BUS continuation rows align, fit and preserve every badge')
