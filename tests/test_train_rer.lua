local base='mod/content/gui/bulb_cockpit/'
local P=dofile(base..'native_model.lua')
local S=dofile(base..'settings.lua')
local G=dofile(base..'merge.lua')
local lines={{id=1,name='Rail one',mode='TRAIN'}, {id=2,name='Rail two',mode='TRAIN'},
  {id=3,name='New rail',mode='TRAIN'}, {id=4,name='Manual RER',mode='TRAIN'}}
local groups=S.directory(lines,{},'',P)
assert(#groups==5 and groups[1].mode=='TRAIN' and groups[1].title=='Train')
assert(groups[2].mode=='RER' and #groups[2].items==0 and groups[3].mode=='METRO')
assert(#groups[1].items==4,'no unconfigured game railway enters RER')
local aliases={['4']={name=lines[4].name,displayMode='RER',shortName=''},__defaults={
  ['1']={name=lines[1].name,mode='RER',index=8,shortName='H'},
  ['2']={name=lines[2].name,mode='RER',index=9,shortName='I'},
  ['4']={name=lines[4].name,mode='RER',index=2,shortName='B'}}}
local defaults=P.defaults(lines,aliases)
assert(defaults['1'].mode=='TRAIN' and defaults['1'].shortName=='H')
assert(defaults['2'].mode=='TRAIN' and defaults['2'].shortName=='I')
assert(defaults['3'].mode=='TRAIN' and defaults['3'].shortName=='J','new trains append to old automatic rail letters')
assert(defaults['4'].mode=='RER' and defaults['4'].shortName=='B','explicit RER selection keeps its separate reserved letter')
groups=S.directory(lines,aliases,'',P)
assert(#groups[1].items==3 and #groups[2].items==1,'manual RER appears only in the new RER section')
local shared={__defaults=aliases.__defaults,
  ['1']={name=lines[1].name,shortName='H'},['2']={name=lines[2].name,shortName='H'},
  ['4']={name=lines[4].name,shortName='H',displayMode='RER'}}
local candidates=G.candidates(lines[1],shared,P)
assert(#candidates==2 and candidates[1]==1 and candidates[2]==2,'old auto rail metadata merges only with Train, never RER')
local env=setmetatable({},{__index=_G})
assert(loadfile('mod/content/game_mechanics/bulb_aliases/bulb_aliases.script.lua','t',env))()
local script=env.data()
local initial={lines={['4']=aliases['4']},defaults=aliases.__defaults,options={language='ja',flashNextStop=true},revision=30}
local value,writes=initial,0
local state={get=function()return value end,set=function(_,v)value=v;writes=writes+1 end}
script.handleEvent({},state,'','linnan.bulb.aliases','linnan.bulb.setDefaults',{defaults=defaults})
assert(writes==1 and value.defaults['1'].mode=='TRAIN' and value.defaults['1'].shortName=='H')
assert(value.defaults['4'].mode=='RER' and value.defaults['4'].shortName=='B')
assert(initial.defaults['1'].mode=='RER','upgrade must not mutate the old state in place')
assert(value.lines==initial.lines and value.options==initial.options,'preserve aliases, language and blinking')
script.handleEvent({},state,'','linnan.bulb.aliases','linnan.bulb.setDefaults',{defaults=defaults})
assert(writes==1,'unchanged rail defaults never dirty another save revision')
-- A newly saved RER must never be mistaken for legacy automatic rail when
-- changing its type later: allocate a free Train letter, not its RER index.
local changed={__defaults=value.defaults,['4']={name=lines[4].name,displayMode='TRAIN',shortName=''}}
local switched=P.defaults(lines,changed)
assert(switched['4'].mode=='TRAIN' and switched['4'].shortName=='K',
  'switching new RER B to Train must not collide with existing Train letters')
local B=dofile(base..'mode_marks.lua')
local builtin={type={ImageViewScaling={Stretch=1}}}
for _,name in ipairs({'ImageView','Component','FloatingLayout','FloatingLayoutChild'})do
  builtin[name]=function(param)return {kind=name,param=param}end
end
local mark=B.create(builtin,function(style)return {styleSheet=style}end,
  function(text)return {kind='TextView',param={text=text}}end,function()error('use a dedicated rail icon')end)
local function scan(v,found)
  if type(v)~='table'then return end
  if v.kind=='ImageView'then found[v.param.path:match('([^/]+)$')]=true end
  if v.kind=='TextView'then found[v.param.text]=true end
  for _,child in pairs(v)do if type(child)=='table'then scan(child,found)end end
end
for _,small in ipairs({false,true})do
  local train,rer={},{}
  scan(mark('TRAIN','A',{1,.8,0,1},small),train)
  scan(mark('RER','A',{1,.8,0,1},small),rer)
  assert(train['transilien-mode.tga'] and not train['rer-mode-ring.tga'] and not train.RER)
  assert(rer['rer-mode-ring.tga'] and rer.RER and not rer['transilien-mode.tga'])
  assert(train['rer-a.tga'] and rer['rer-a.tga'],'letter badge styles retain their game colors and preset masks')
end
print('PASS: separate Train/RER defaults, directory order, legacy letters, merge isolation, one-time persistence and distinct rail icons')
