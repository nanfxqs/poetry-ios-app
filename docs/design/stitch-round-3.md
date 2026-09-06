# 第三轮：五页统一

沿用用户确认的第二轮方案，统一探索、诗人、诗集；今日与人物关系保持视觉，只更新五页之间的本地导航。旧版 HTML 与图片已于 2026-09-06 清理。当前状态见 [current-design.md](current-design.md)。

- 预览：`.stitch/review.html`。
- 本轮 HTML、静态导出、高清截图：`.stitch/round-3/`。
- 所有视口 393 × 852，PNG 1179 × 2556。
- 探索：地点类型切换、地名点选、诗人入口、有限样本搜索；地图为 SVG 地点示意，无真实地理坐标。
- 诗人：作品／生平／关系三个页内入口。作品关系保留出处。生平资料未核实，因此为空态；未声称生平路线功能完成。
- 诗集：搜索、收藏菜单、取消收藏和数量更新，仅页面内状态；备份面板明确未连接。

验证：五页字体和图片加载、横向尺寸、底部导航遮挡、PNG 像素检查通过；浏览器实测写作地空态、诗人跳转与关系切换、诗集搜索及取消收藏数量更新。未进行原生 iOS 编译或真机测试。

本轮采用本地 HTML 精修及 Stitch code-to-design 导入，不声称由 Stitch 自动生成。静态导出已内联 CSS/SVG/图片并去掉脚本，Stitch 画布用于设计审阅；可试用交互保留在本地页面中。

Stitch 五页回存并经 get_project 的 screenInstances 核实。标题以 R3 /today、/explore、/poet、/relations、/collection 开头；新设计规范为 assets/990ad9c76a89478ea706323418ab5bae。页面 ID 详见 `.stitch/metadata.json`。
