local ssu = require '::/gui/main/stylesheetutil.lua'
local transf = require '::/scripts/mat4.tl'
function data()
  local result = {}
  local add = ssu.makeAdder(result)
  local colors=api.gui.genericRep.get(api.gui.genericRep.find('::/gui/main/default_colors.gres')).data
  -- GameUIProxyRoot mounts FreeCamOptions at the upper-right corner.
  -- vw/vh are GUI viewport units, independent of render resolution/UI scale.
  add('R::LinnanBulbFreeCamNative', {
    size={'100vw','100vh'},anchorPoint={1,0},padding={0,0,0,0},margin={0,0,0,0},
  })
  add('#linnan.bulb.host > FloatingLayout, #linnan.bulb.hud > FloatingLayout', {
    gravity={-1,-1},padding={0,0,0,0},margin={0,0,0,0},
  })
  add('FloatingLayout!bulb-fixed-layout', {
    gravity={0,0},padding={0,0,0,0},margin={0,0,0,0},
  })
  add('R::Component!bulb-track-layer', {padding={0,0,0,0},margin={0,0,0,0},gravity={0,0}})
  add('R::Component!bulb-layout-extent', {visibility='hidden',padding={0,0,0,0},margin={0,0,0,0}})
  -- The game's ScrollArea::Content::Layout stretches horizontally by
  -- default. This canvas owns fixed coordinates and scrolls at its natural
  -- width, so a wide viewport must not spread stations beyond their rail.
  add('ScrollArea#linnan.bulb.browser.map ScrollArea::Content::Layout', {gravity={0,0}})
  add('#linnan.bulb.static-canvas', {gravity={0,0},padding={0,0,0,0},margin={0,0,0,0}})
  -- A dedicated recipe owns branch strokes; ordinary straight rails remain
  -- generic components. Both native element types need the shared mask.
  -- One shared alpha strip softens transformed rail edges. Only the center
  -- patch stretches; no runtime rasterization or per-route texture is used.
  add('R::LinnanBulbTrackStrokeNative!bulb-branch-stroke, R::Component!bulb-track, R::Component!bulb-track-stripe',{
    backgroundImage1={fileName='linnan_bulb_cockpit::/gui/bulb_cockpit/symbols/track-strip.tga',
      horizontal={0,0,4,4},vertical={0,0,64,64}},
  })
  -- Keep large rule banks off R::Component, which is ubiquitous throughout
  -- the game even when no BULB diagram exists. Dedicated native types retain
  -- full transform precision without involving unrelated components.
  for degree=-90,90 do
    add('R::LinnanBulbTrackStrokeNative!bulb-track-angle'..(degree+90),{
      transformOrigin={0,.5},transform=transf.rotZ(math.rad(degree)),
      padding={0,0,0,0},margin={0,0,0,0},
    })
  end
  for percent=1,400 do
    if percent~=100 then add('R::LinnanBulbScaledCanvasNative!bulb-canvas-scale'..percent,{
      transformOrigin={0,0},transform=transf.scaleRotZTransl(percent/100,0,{x=0,y=0,z=0}),
      padding={0,0,0,0},margin={0,0,0,0},
    })end
  end
  local stationNameStyle={
    fontWeight='Bold',
    transformOrigin={0,1},transform=transf.rotZ(-math.pi/6),
    padding={0,2,0,2},margin={0,0,0,0},
  }
  add('TextView!bulb-station-name',stationNameStyle)
  add('TextView!bulb-station-terminus-name',stationNameStyle)
  -- Only station names receive a backing. Route identity, transfers and
  -- omission labels stay transparent; termini retain flat square boxes.
  add('TextView!bulb-station-name', {
    backgroundImage1={fileName='::/gui/builtin/popup/surface.tga',
      horizontal={0,6,8,14},vertical={0,6,8,14}},
  })
  add('TextView!bulb-route-title', {fontWeight='Bold'})
  add('TextView!bulb-omission-label', {textAlignment={0.5,0.5}})
  add('TextView!bulb-line-badge, TextView!bulb-transfer-label, TextView!bulb-mode-letter', {textAlignment={0.5,0.5},fontWeight='Bold'})
  add('R::Component!bulb-station-marker > FloatingLayout, R::LinnanBulbFlashingStationNative > FloatingLayout', {
    gravity={-1,-1},padding={0,0,0,0},margin={0,0,0,0},
  })
  -- The entry point owns no toolbar space; the pinned native window floats.
  add('R::LinnanBulbMainButtonNative', {
    size={0,0},padding={0,0,0,0},margin={0,0,0,0},
  })
  add('Window!bulb-entry-window', {
    size={44,44},minSize={44,44},maxSize={44,44},anchorPoint={1,0},
    padding={0,0,0,0},margin={12,12,0,0},gravity={0,0},
    -- A zero shadowWidth leaves the native Window nine-patch installed.
    -- Clear its paint explicitly; only the child toggle supplies a surface.
    backgroundImage1={fileName=''},borderImage={fileName=''},shadowNinePatch={fileName=''},
    backgroundColor1={0,0,0,0},borderColor={0,0,0,0},shadowColor={0,0,0,0},shadowWidth={0,0,0,0},
  })
  add('Window!bulb-entry-window Window::Content, Window!bulb-entry-window Window::Layout', {
    padding={0,0,0,0},margin={0,0,0,0},outerSpacing={0,0},innerSpacing={0,0},gravity={0,0},
  })
  add('Window!bulb-entry-window Window::TitleLayout', {
    size={44,8},padding={0,0,0,0},margin={0,0,0,0},innerSpacing={0,0},gravity={0,0},
  })
  add('Window!bulb-entry-window Window::Title, Window!bulb-entry-window Window::Icon, Window!bulb-entry-window Window::TitleLayout Button', {visibility='none'})
  add('R::Component!bulb-entry-content', {size={44,44},padding={0,0,0,0},margin={0,0,0,0},gravity={0,0}})
  add('R::Component!bulb-entry-content > FloatingLayout', {gravity={-1,-1},padding={0,0,0,0},margin={0,0,0,0}})
  add('R::Component!bulb-entry-grip', {size={44,8},padding={0,0,0,0},margin={0,0,0,0}})
  add('R::Component!bulb-entry-grip > FloatingLayout', {gravity={-1,-1},padding={0,0,0,0},margin={0,0,0,0}})
  add('R::Component!bulb-entry-grip-line', {size={12,2},anchorPoint={.5,.5},backgroundColor=colors.NeutralLightest})
  add('#linnan.bulb.entry-gauge', {visibility='hidden',padding={0,0,0,0},margin={0,0,0,0}})
  add('R::LinnanBulbSettingsNative, R::LinnanBulbSettingsNative > BoxLayout', {
    padding={0,0,0,0},margin={0,0,0,0},outerSpacing={0,0},innerSpacing={0,0},gravity={0,0},
  })
  add('ToggleButton!bulb-settings-toggle', {
    size={32,32},padding={4,4,4,4},margin={1,1,2,1},gravity={0.5,0.5},
  })
  add('ImageView!bulb-settings-toggle-icon', {size={24,24},color=colors.NeutralLightest})
  -- Native Window supplies its themed surface, contour, title and close
  -- control. Only this window stays visible during the cockpit action.
  add('!action-follow Window!bulb-settings-window, !action-camera Window!bulb-settings-window', {visibility='visible'})
  -- Match game.css.lua's pause tool state, independently of simulation speed.
  add('#mainView!tool-pause #linnan.bulb.settings, #mainView!tool-pause Window!bulb-settings-window', {visibility='none'})
  add('#mainView!tool-pause Window!bulb-entry-window', {visibility='none'})
  add('!action-follow #linnan.bulb.settings, !action-camera #linnan.bulb.settings', {visibility='none'})
  add('Window!bulb-settings-window Window::Layout', {padding={0,0,0,0},margin={0,0,0,0},innerSpacing={0,0},gravity={0,0}})
  add('Window!bulb-settings-window Window::Content', {padding={4,12,12,12},gravity={0,0}})
  add('R::LinnanBulbBrowserNative > BoxLayout', {padding={0,0,0,0},margin={0,0,0,0},outerSpacing={0,0},innerSpacing={0,0},gravity={0,0}})
  add('Window!bulb-settings-window TextView', {color=colors.NeutralLightest})
  add('R::Component!bulb-settings-body > BoxLayout', {outerSpacing={0,0},innerSpacing={8,8},gravity={-1,0}})
  -- Static page: one left column shared by navigation, identity and the
  -- diagram's first station (24 GUI units inside its measured canvas).
  add('R::Component!bulb-static-page > BoxLayout', {outerSpacing={0,0},innerSpacing={12,12},gravity={0,0}})
  -- Avoid a universal leaf selector in the game's global stylesheet. These
  -- are the only static-page children that need fixed left-aligned bounds.
  add('R::Component!bulb-static-toolbar, R::Component!bulb-static-identity, ScrollArea!bulb-static-map', {gravity={0,0}})
  add('R::Component!bulb-static-toolbar > BoxLayout, R::Component!bulb-static-identity > BoxLayout', {
    outerSpacing={0,0},innerSpacing={24,24},padding={0,0,0,24},margin={0,0,0,0},gravity={0,0.5},
  })
  add('TextView!bulb-static-title', {textAlignment={0,0.5},padding={0,0,0,0},margin={0,0,0,0}})
  add('TextView!bulb-static-message, ComboBox!bulb-static-member', {margin={0,0,0,24},gravity={0,0}})
  add('Button!bulb-static-locate', {padding={4,4,4,4},margin={0,0,0,0},gravity={0.5,0.5}})
  add('R::Component!bulb-settings-list > BoxLayout', {outerSpacing={0,0},innerSpacing={2,2},gravity={0,0}})
  add('ScrollArea!bulb-settings-scroll ScrollArea::Content::Layout', {gravity={0,0}})
  add('R::LinnanBulbAliasRowNative > BoxLayout', {outerSpacing={0,0},innerSpacing={0,0}})
  add('R::Component!bulb-settings-row', {padding={4,4,4,4},margin={0,0,0,0}})
  add('R::Component!bulb-settings-heading', {padding={0,4,0,4},margin={0,0,0,0}})
  add('R::Component!bulb-settings-badge', {padding={0,0,0,0},margin={0,0,0,0},gravity={0,0.5}})
  add('R::Component!bulb-settings-badge > FloatingLayout', {
    padding={0,0,0,0},margin={0,0,0,0},gravity={-1,-1},
  })
  add('R::Component!bulb-settings-striped', {backgroundColor=colors.BaseMedium})
  add('R::Component!bulb-settings-row > BoxLayout, R::Component!bulb-settings-name > BoxLayout, R::Component!bulb-settings-controls > BoxLayout, R::Component!bulb-settings-heading > BoxLayout, R::Component!bulb-settings-footer > BoxLayout', {
    outerSpacing={0,0},innerSpacing={8,8},gravity={0,0.5},
  })
  add('R::Component!bulb-carrier-filter ToggleButton',{padding={0,0,0,0},margin={0,0,0,0}})
  add('R::Component!bulb-carrier-filter ImageView!category',{size={28,18},padding={6,6,6,6}})
  add('ComboBox!bulb-settings-mode ComboBox::Entry, ComboBox!bulb-settings-mode ComboBox::DisplayEntry', {padding={4,8,4,8}})
  add('ComboBox!bulb-settings-mode, ComboBox!bulb-settings-mode ComboBox::Button', {padding={0,0,0,0},margin={0,0,0,0}})
  add('Button!bulb-settings-save', {padding={4,8,4,8},margin={0,0,0,0}})
  add('Slider!bulb-settings-scale-slider',{padding={0,0,0,0},margin={0,0,0,0}})
  add('ToggleButton!bulb-settings-flash', {padding={4,8,4,8},margin={0,0,0,0},gravity={0.5,0.5}})
  add('R::Component!bulb-directory-sections > BoxLayout', {outerSpacing={0,0},innerSpacing={10,10},gravity={-1,0}})
  add('R::Component!bulb-directory-section', {padding={8,8,8,8},margin={0,0,0,0},backgroundColor=colors.BaseMedium})
  add('R::Component!bulb-directory-section > BoxLayout', {outerSpacing={0,0},innerSpacing={6,6},gravity={-1,0}})
  add('R::Component!bulb-directory-row > BoxLayout', {outerSpacing={0,0},innerSpacing={8,8},gravity={0,0.5}})
  add('Button!bulb-directory-tile', {padding={0,0,0,0},margin={0,0,0,0},gravity={0.5,0.5}})
  add('Button!bulb-transfer-link', {padding={0,0,0,0},margin={0,0,0,0},gravity={0,0}})
  -- r10's screenshot confirms the independent cockpit diagram is mounted.
  -- Replace only the original two route labels; retain speed/horn/exit UI.
  add('CockpitCamera::Line1, CockpitCamera::Line2', {visibility='none'})
  return result
end
