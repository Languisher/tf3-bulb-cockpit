local base='mod/content/gui/bulb_cockpit/'
local S,P=dofile(base..'settings.lua'),dofile(base..'native_model.lua')
local lines={
  {id=1,name='地铁 10',mode='METRO',color='#ff0000'},
  {id=2,name='地铁 2',mode='METRO',color='#00ff00'},
  {id=3,name='火车',mode='TRAIN',color='#0000ff'},
  {id=4,name='电车',mode='TRAM',color='#ffff00'},
  {id=5,name='市内公交',mode='BUS',color='#ff00ff'},
  {id=6,name='机场公交',mode='BUS',color='#ff00ff'},
  {id=7,name='地铁支线',mode='METRO',color='#00ff00'},
}
local aliases={['1']={name='地铁 10',prefix='',identifier='10',suffix=''},
  ['2']={name='地铁 2',prefix='',identifier='2',suffix=''},
  ['7']={name='地铁支线',prefix='',identifier='2',suffix=''},
  ['5']={name='市内公交',prefix='',identifier='1001',suffix=''},
  ['6']={name='机场公交',prefix='',identifier='5101',suffix=''}}
local groups=S.directory(lines,aliases,'',P)
assert(#groups==4 and groups[1].mode=='RER' and groups[2].mode=='METRO' and groups[3].mode=='TRAM' and groups[4].mode=='BUS')
assert(#groups[2].items==2 and #groups[4].items==0,'empty bus query never lists every bus')
assert(groups[2].items[1].badge=='2' and groups[2].items[2].badge=='10','natural badge ordering')
assert(#groups[2].items[1].members==2,'same-type complete badges share a directory tile; validate endpoints only on click')
assert(groups[2].items[1].color=='#00ff00')
assert(#S.directory(lines,aliases,'   ',P)[4].items==0)
assert(#S.directory(lines,aliases,'510',P)[4].items==1)
assert(S.directory(lines,aliases,'机场',P)[4].items[1].id==6)
assert(#S.directory(lines,aliases,'.*',P)[4].items==0,'queries are literal, not Lua patterns')
aliases['7'].suffix='支'
assert(#S.directory(lines,aliases,'',P)[2].items==3,'suffix distinguishes full badges')
print('PASS: actual four-mode directory, game colors, complete-badge grouping and bus search default empty')
