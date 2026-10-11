local base='mod/content/gui/bulb_cockpit/'
local M=dofile(base..'model.lua')
local G=dofile(base..'merge.lua')
local P=dofile(base..'native_model.lua')
local function service(id,ids)
  local stops={};for i,station in ipairs(ids)do stops[i]={id=station,name='站 '..station,transfers={}}end
  return {id=id,name='线路 '..id,color='#006db8',mode='TRAIN',stops=M.servicePath(stops)}
end
local function network(...)
  return G.build({...})
end
assert(network(service(1,{1,2,3,2}),service(2,{1,4,5,4})), 'shared real terminus forms a fork')
assert(network(service(1,{1,2}),service(2,{2,3}),service(3,{3,4})), 'indirect endpoint connectivity is sufficient')
assert(not network(service(1,{1,2}),service(2,{3,4})), 'no common endpoint')
assert(not network(service(1,{1,2}),service(2,{2,3}),service(3,{4,5}),service(4,{5,6})), 'reject the entire disconnected group')
assert(not network(service(1,{1,2,3,2}),service(2,{4,2,5,2})), 'shared intermediate station is not a shared endpoint')
assert(not network(service(1,{1,2,3}),service(2,{1,4})), 'circular service has no real termini')
local fork=assert(network(service(1,{1,2,3,2}),service(2,{1,2,4,2})))
assert(#fork.nodes==4 and #fork.edges==3, 'shared trunk and station are deduplicated')
local parallel=assert(network(service(1,{1,2,3,2}),service(2,{1,4,3,4})))
assert(#parallel.nodes==4 and #parallel.edges==4, 'parallel paths must not collapse to a straight line')
assert(network(service(1,{1,2}),service(2,{2,3}),service(3,{3,1})), 'connected service cycles are allowed')
local aliases={['1']={name='线路 1',prefix='T',identifier='1',suffix='b',displayMode='TRAM'},
  ['2']={name='线路 2',prefix='T',identifier='1',suffix='b',displayMode='TRAM'},
  ['3']={name='线路 3',prefix='T',identifier='1',suffix='',displayMode='TRAM'},
  ['4']={name='线路 4',prefix='T',identifier='1',suffix='b',displayMode='METRO'}}
local main={id=1,name='线路 1',mode='TRAIN'}
local ids=G.candidates(main,aliases,P)
assert(#ids==2 and ids[1]==1 and ids[2]==2, 'full badge and actual display type must match')
aliases['1'].identifier=''
aliases.__defaults={['1']={name='线路 1',mode='TRAM',index=1,shortName='T1'}}
assert(#G.candidates(main,aliases,P)==2, 'resolved default identifier participates')
local s1,s2=service(1,{1,2}),service(2,{1,3})
for _,stop in ipairs(s1.stops)do if stop.id==1 then stop.transfers={{id=2,name='线路 2'},{id=20,name='真正换乘'}}end end
for _,stop in ipairs(s2.stops)do if stop.id==1 then stop.transfers={{id=1,name='线路 1'},{id=20,name='真正换乘'}}end end
local merged=assert(network(s1,s2))
assert(#merged.byId[1].transfers==1 and merged.byId[1].transfers[1].id==20, 'members are not transfers to themselves')
print('PASS: fork, shared trunk, parallel branch, transitive group, disconnected rejection, circular rejection and exact badge matching')
