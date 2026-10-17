local base='mod/content/gui/bulb_cockpit/'
local V,P,B=dofile(base..'presets.lua'),dofile(base..'native_model.lua'),dofile(base..'mode_marks.lua')
local function config(mode,preset)return {__options={linePresets={[mode]=preset}}}end
local paris=V.resolve('METRO','M01','#123456',config('METRO','paris'))
assert(paris.color=='#ffcd02' and paris.symbolInk=='#233f91','Paris M01 must use line 1 yellow and blue mode mark')
local munich=V.resolve('METRO','1','#123456',config('METRO','munich'))
assert(munich.label=='U1' and munich.color=='#52822f' and munich.aspect==2,'MVG U1 green, not U3 orange')
assert(V.resolve('METRO','3','#123456',config('METRO','munich')).color=='#ee732a')
assert(V.resolve('RER','1','#123456',config('RER','munich')).label=='S1')
assert(V.resolve('METRO','Special 1 Express','#123456',config('METRO','munich'),'1').label==nil,'custom affixes remain visible')
local unknown=V.resolve('METRO','99','#123456',config('METRO','shanghai'))
assert(not unknown.matched and unknown.color=='#123456' and unknown.shape=='rectangle','unknown number keeps game color but still adopts city shape')
assert(unknown.symbolInk=='#e3002b')
local g=B.geometry('METRO',true,munich)
assert(g.width==48 and g.height==24 and g.font>=18,'wide Munich badge preserves number height')
local builtin={type={ImageViewScaling={Stretch=1}}}
for _,name in ipairs({'Component','TextView','ImageView','FloatingLayout','FloatingLayoutChild','Button'})do
 builtin[name]=function(p)return {kind=name,param=p}end
end
local mark,group,badge=B.create(builtin,function(v)return {styleSheet=v}end,
 function(value,font,w,h,ink,_,class)return {kind='TextView',param={text=value,font=font,ink=ink,class=class}}end,
 function()error('unexpected game icon')end,{symbolInk={1,1,1,1}})
local function visit(node,fn)
 if type(node)~='table'then return end
 if node.kind then fn(node.kind,node.param)end
 for _,v in pairs(node)do if type(v)=='table'then visit(v,fn)end end
end
local glyph
visit(badge('METRO','1',{1,0,0,1},true,nil,nil,munich),function(kind,p)
 if kind=='TextView'then glyph=p end
end)
assert(glyph.text=='U1' and glyph.font>=18,'renderer uses full native U1 label, without crushing its font')
local unknownMark=mark('METRO','99',{0,0,0,1},true,nil,unknown)
local red=false
visit(unknownMark,function(kind,p)
 if kind=='ImageView' and p.path:match('metro%-ring')then red=p.meta.styleSheet.color[1]>.8 end
end)
assert(red,'city mode symbol changes even when number has no palette')
local aliases=config('METRO','munich')
local transfers={}
for i=1,4 do transfers[i]={id=i+10,name='Metro '..i,mode='METRO',color='#123456'}end
local stops={{id=1,name='Alpha',transfers=transfers},{id=2,name='Beta',transfers={}}}
local snapshot={static=true,next=0,route={lineId=1,name='Main',mode='METRO',color='#123456',stops=stops},lines=transfers}
local plan=V.plan(P,snapshot,aliases,false,1000,nil,B.textWidth)
local groups=plan.stops[1].transferGroups
assert(groups[1].width==18+3*53 and #groups[1].rows==2,'layout wraps using actual 48px badges, not stale 24px slots')
local rows={}
for _,row in ipairs(groups[1].rows)do
 rows[#rows+1]={y=row.y,lines={}}
 for _,line in ipairs(row.lines)do rows[#rows].lines[#rows[#rows].lines+1]={text=line.text,fill={1,0,0,1},fullName=line.fullName,presentation=line.presentation}end
end
local _,width,height=group('METRO',rows)
assert(width==groups[1].width and height==groups[1].height,'rendered transfer bounds equal model bounds')
print('PASS: official Paris/Munich colors, padded identifiers, preset shapes on fallback, full U/S labels and shared wide badge bounds')
local S=dofile(base..'settings.lua')
local line={id=1,name='Metro service',mode='METRO',color='#123456'}
local found=S.list({line},aliases,'U1','number','name',P,nil,function(line,options,defaults)
 return V.resolve(P.mode(line,options),P.alias(line,options,defaults),line.color,options,P.identifier(line,options,defaults))
end)
assert(#found==1,'number search matches the city badge actually shown')
