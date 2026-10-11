local B=dofile('mod/content/gui/bulb_cockpit/mode_marks.lua')
local builtin={type={ImageViewScaling={Stretch='stretch'}}}
for _,name in ipairs({'ImageView','Component','FloatingLayout','FloatingLayoutChild'}) do
  builtin[name]=function(param)return {kind=name,param=param}end
end
local function text(value,font,width,height,ink,_,class)
  return {kind='TextView',param={text=value,meta={class=class,
    styleSheet={size={width,height},fontSize=font,color=ink}}}}
end
local mark=B.create(builtin,function(value)return {styleSheet=value}end,text,
  function()error('RER must use its own mode symbol')end)
local function walk(node,fn)
  if type(node)~='table' then return end
  if node.kind then fn(node.kind,node.param)end
  for _,value in pairs(node)do if type(value)=='table'then walk(value,fn)end end
end
for _,small in ipairs({false,true})do
  for letter in ('ABCDE'):gmatch('.')do
    for _,fill in ipairs({{.63,.23,.80,1},{.96,.84,.25,1}})do
      local tree,width,height=mark('RER',letter,fill,small,'actual full line name')
      local frame,glyph,labelCount=nil,nil,0
      walk(tree,function(kind,param)
        local class=param.meta and param.meta.class
        if kind=='ImageView' and param.path:match('/rer%-frame%.tga$')then frame=param end
        if kind=='ImageView' and param.path:match('/rer%-'..letter:lower()..'%.tga$')then glyph=param end
        if kind=='TextView' and (class=='bulb-line-badge' or class=='bulb-transfer-label')then
          labelCount=labelCount+1
        end
      end)
      assert(frame and glyph,'RER '..letter..' must use the BULB Paris preset outline at both sizes')
      assert(labelCount==0,'preset letters must not depend on the substitute game font')
      assert(frame.meta.styleSheet.color==fill,'preset frame must retain the live game line color')
      local expected=fill[1]>.9 and {0,0,0,1} or {1,1,1,1}
      for i=1,4 do assert(glyph.meta.styleSheet.color[i]==expected[i])end
      local size=small and 24 or 38
      assert(height==size and width==(small and 47 or 70),'preset must keep existing fixed badge bounds')
      assert(glyph.meta.styleSheet.size[1]==size and glyph.meta.styleSheet.size[2]==size)
      assert(tree.param.meta.tooltip=='actual full line name')
      for _,image in ipairs({frame,glyph})do
        local relative=image.path:match('::/(.+)')
        local file=assert(io.open('mod/content/'..relative,'rb'),'preset image must be packaged')
        file:close()
      end
    end
  end
end
local lower=mark('RER',' b ',{.1,.4,.8,1},true)
local normalized=false
walk(lower,function(kind,param)
  if kind=='ImageView' and param.path:match('/rer%-b%.tga$')then normalized=true end
end)
assert(normalized,'single-letter RER identifiers normalize to Paris capitals')
for _,value in ipairs({'F','AA','RE1',string.rep('杭州WW',20)})do
  local tree=mark('RER',value,{.1,.4,.8,1},false)
  local found=false
  walk(tree,function(kind,param)
    if kind=='TextView' and param.meta.class=='bulb-line-badge'then
      found=true
      assert(param.meta.styleSheet.size[1]<=38,'custom labels remain bounded')
    end
  end)
  assert(found,'non-preset RER identifiers retain the custom label fallback')
end
for _,mode in ipairs({'METRO','TRAM','BUS'})do
  local tree=mark(mode,'A',{.1,.4,.8,1},false)
  walk(tree,function(kind,param)
    if kind=='ImageView'then assert(not param.path:match('/rer%-'),'other modes must keep their own style')end
  end)
end
print('RER Paris preset rendering tests passed')
