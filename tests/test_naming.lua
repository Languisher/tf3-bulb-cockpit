local P=dofile('mod/content/gui/bulb_cockpit/native_model.lua')
local S=dofile('mod/content/gui/bulb_cockpit/settings.lua')
local lines={{id=10,name='电车甲',mode='TRAM'},{id=20,name='电车乙',mode='TRAM'},
  {id=30,name='铁路丙',mode='TRAIN'}}
local aliases={['10']={name='电车甲',prefix='T',identifier='3',suffix='b'},
  ['20']={name='电车乙',prefix='快 ',identifier='',suffix=' 支线'},
  ['30']={name='铁路丙',prefix='RER ',identifier='AB',suffix=''}}
local defaults=P.defaults(lines,aliases)
assert(P.alias(lines[1],aliases,defaults)=='T3b')
assert(P.alias(lines[2],aliases,defaults)=='快 2 支线','empty center uses automatic number, without a duplicate T')
assert(P.alias(lines[3],aliases,defaults)=='RER AB')
assert(P.identifier(lines[1],aliases,defaults)=='3' and P.identifier(lines[2],aliases,defaults)=='2')
for _,legacy in ipairs({'T3b','LO-12快','AB','1001','夜班'})do
  local saved={['10']={name='电车甲',shortName=legacy}}
  local parts=P.parts(lines[1],saved,defaults)
  assert(parts.prefix..parts.identifier..parts.suffix==legacy,'legacy split is lossless')
  assert(P.alias(lines[1],saved,defaults)==legacy,'loading old state must not rename badges')
end
local stale={['10']={name='另一个存档',prefix='X',identifier='99',suffix=''}}
assert(P.alias(lines[1],stale,defaults)=='T1','ignore stale structured configuration')
local roster={}
local ids={'10','2','1','AA','Z','B','A','A10','A2'}
local config={}
for i,code in ipairs(ids)do
  local line={id=i,name='真实名称 '..i,mode='BUS'};roster[i]=line
  config[tostring(i)]={name=line.name,prefix='2026-',identifier=code,suffix='-99'}
end
local result=S.list(roster,config,'','number','number_asc',P)
local ordered={}
for _,line in ipairs(result)do ordered[#ordered+1]=P.identifier(line,config)end
assert(table.concat(ordered,',')=='1,2,10,A,B,Z,AA,A2,A10','natural numeric/alphabetic identifier order')
result=S.list(roster,config,'','number','number_desc',P)
assert(P.identifier(result[1],config)=='A10' and P.identifier(result[#result],config)=='1')
assert(#S.list(roster,config,'2026','number','number_asc',P)==#roster,'badge search includes prefix')
assert(#S.list(roster,config,'99','number','number_asc',P)==#roster,'badge search includes suffix')
assert(#S.list(lines,aliases,'t3b','number','number_asc',P)==1,'search the complete rendered prefix + number + suffix')
assert(#S.list(lines,{},'T1','number','number_asc',P)==1,'search the resolved default badge as well')
assert(#S.list(roster,config,'2026','all','number_asc',P)==#roster)
assert(#S.list(roster,config,'真实名称','name','name',P)==#roster)
assert(#S.list(roster,config,'aa','number','number_asc',P)==1,'case-insensitive letter search')
local before=roster[1]
S.list(roster,config,'','number','number_desc',P)
assert(roster[1]==before,'sorting must not change roster or automatic numbering')
local auto,allDefaults=S.list(lines,{},'2','number','number_asc',P)
assert(#auto==1 and auto[1].id==20 and allDefaults['20'].shortName=='T2',
  'filter after computing defaults from the full roster')
print('PASS: prefix/identifier/suffix, legacy compatibility, automatic centers, scoped search and natural sort')
