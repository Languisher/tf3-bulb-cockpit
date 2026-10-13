local f=assert(io.open('tests/test_native.lua'));local harness=f:read('*a');f:close()
assert(load(harness..[=[
do
  local oldSize=api.gui.byId.getSize
  local sizes=0
  api.gui.byId.getSize=function(...)sizes=sizes+1;return oldSize(...)end
  local root=render('LinnanBulbFreeCamNative',mounted.param);findHud(root);assert(hudParam)
  tick();render('LinnanBulbCockpitHudNative',hudParam);tick()
  sizes=0
  local beforeReads=reads
  for i=1,120 do tick()end
  assert(sizes==0,'station monitoring must perform zero GUI size queries after startup; got '..sizes)
  assert(reads==beforeReads+120,'the followed vehicle is the only periodic read')
  free.FreeCamTool.pop();sizes=0
  for i=1,120 do tick()end
  assert(sizes==0,'normal map view has no recurring size checks')
  free.FreeCamTool.push({}, {cockpitCameraForEntity=200});join();join()
  assert(sizes==0,'re-entry must reuse startup dimensions')
  api.gui.byId.getSize=oldSize
  print('PASS: zero ride, ordinary-map and re-entry geometry queries after startup')
end
]=],'@refresh_budget'))()
