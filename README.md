# TF3 BULB Cockpit · 0.1.60dev

为《Transport Fever 3》第一人称车辆视角提供 BULB 风格的动态线路图，以及可点击换乘标识的线路目录。

A native in-game route diagram and line browser inspired by [BULB](https://bulb.slama.io/editor). No browser, exported images or external rendering process is required while playing.

**开发预发布版。** 当前实现针对 macOS 游戏 Build 40420；Windows／Linux 尚未实测。Lua 回归检查不能证明实际游戏帧率、长时间内存占用或 C++ 界面释放正常，持续性能下降问题仍需要同存档启用／禁用模组的实机对照。

## 下载与安装

在 [Releases](https://github.com/Languisher/tf3-bulb-cockpit/releases) 下载 `tf3-bulb-cockpit-0.1.60dev.zip`。

1. 完整退出游戏。
2. 解压，将 `linnan_bulb_cockpit` 文件夹放入游戏用户目录的 `local/mods/`。
3. 加载存档时启用「BULB 风格 · 动态车内线路图」。
4. 进入有线路的车辆第一人称视角。线路标识在左上角，站点图在底部中央。

macOS Steam 用户目录通常为：

```text
~/Library/Application Support/Steam/userdata/<Steam 用户编号>/3493540/local/mods/
```

从源码安装也可以在仓库根目录运行：

```sh
python3 install.py
```

此脚本仅自动识别本机 macOS Steam 目录；找到多个游戏用户目录时会停止，需手动复制 `mod/` 为 `linnan_bulb_cockpit`。覆盖本模组前会备份到 `previous-install-backups/`，不操作存档。升级后需完整重启游戏。

## 功能

- 自动读取当前车辆线路、站序、起终点与相关换乘，沿用游戏设置的线路颜色。
- Metro、RER、电车、公交等采用不同线宽、站点和编号样式；铁路与电车可以手动选择显示类型。
- 已经过站点亮黄灯，下一站默认常亮；可选择闪烁，开启可能降低性能。
- 合并线路中，当前车辆不会经过的另一分支站点内部显示白色，不参与黄灯进度与闪烁。
- 每条线路可配置「前缀＋数字／字母编号＋后缀」，支持按最终标号搜索、自然排序及全部应用。仅影响模组标号，不修改游戏真实线路名称。
- 同显示类型、同完整标号的线路可按实际共同起终点合并，显示 fork／parallel branches；整组必须连通。
- 分叉／汇合采用相切圆弧和圆头端点，线条边缘柔化；共用静态遮罩，游戏运行时不生成图片。
- 线路目录按 RER、Metro、Tramway、公交排列；点击编号查看静态线路图，点击换乘编号跳转。公交初始为空，输入搜索后显示匹配结果；返回目录释放当前图的数据。
- 线路图设置入口在普通地图视角显示，第一人称和暂停菜单中隐藏。
- 静态线路图顶部的图钉可定位地图上的当前线路，关闭设置并释放静态图；第一人称中会先退出驾驶视角。合并图定位当前打开的实际成员。
- 地图上依次点击两个站点，可手动关联为换乘站组；此关联只影响换乘，不作为合并线路的共同端点。
- 可选的公交批量编号默认关闭：城市／Express 对照数字前缀加至少两位流水号，例如 `10 → 1001`、`51 → 5101`。

## 更新与读取范围

进入第一人称时初始化当前线路、已配置的同号成员和实际相关换乘。行驶中每半秒检查当前车辆状态，进度未变化时不重建图，到站或折返时更新行程；闪烁开启时只更新下一站的小型组件。

退出第一人称会隐藏并卸载 HUD、释放会话缓存。打开完整设置／目录时会按需读取线路清单。外部修改游戏站序、站名或颜色后，退出并重新进入第一人称刷新。

## 开发

需要 Python 3 和 Lua 5.4；如安装了 `luac`，测试脚本还会检查语法。

```sh
python3 tools/run_tests.py
python3 tools/package.py
```

第一条命令运行独立测试，明确跳过四项需要游戏原版 GUI 文件的集成检查。完整检查方式与手工验收场景见 [测试说明](docs/TESTING.md)。生成的安装包与 SHA-256 校验文件位于 `dist/`。

发布版本以 [VERSION](VERSION) 为准，当前为 `0.1.60dev`，对应 Git 标签 `v0.1.60dev` 和游戏数值 revision `60`。开发后缀按本项目命名习惯保留为 `dev`。

## 素材与归属

本项目受 BULB 的排版启发，与 BULB、RATP、Île-de-France Mobilités 及游戏开发商无隶属或背书关系。RER A–E 图形的来源与归属见 [素材说明](mod/content/gui/bulb_cockpit/symbols/NOTICE.md)。不包含 Parisine 商业字体、游戏原版脚本或游戏字体，文字使用游戏原生语言字体。

问题反馈请附版本号、游戏 Build、复现步骤，以及去除个人信息后的相关错误片段。
