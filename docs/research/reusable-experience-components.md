# 古诗词 App：可复用体验组件调研

调研日期：2026-09-05。用途：为 Wayfinder 提供选项，尚未决定依赖、实现或调用 Stitch。以下“建议”是本项目的设计判断；能力、平台和许可链接来自官方文档或项目源码。本轮没有进行 iPhone 性能或构建验证。

## 推荐组合

| 体验 | 优先复用 | 在本项目中的用法与边界 |
| --- | --- | --- |
| 诗词地图 | Apple MapKit for SwiftUI | 用自定义标注承载地方诗词，选中地方后出现诗词卡片；诗人行迹可用 MapPolyline。它提供底图和绘制能力，古地名、创作地点与证据需要我们的内容层提供。[Apple 文档](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui) |
| 诗人生平 | SwiftUI 标准视图组成事件列表 | 建议复用滚动、布局和卡片能力，用少量项目代码表达“时间—事件—作品”，不引入不匹配的日历或视频时间轴依赖。重大事件可先折叠为阶段，再逐项展开；此方案是设计建议，不是已找到现成的诗人生平组件。[LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack) |
| 诗人星图 | Grape 原生 SwiftUI 图组件，作为候选 | 已有力导向布局，不必重写物理模拟；先试一个诗人的一跳关系，按关系类型筛选，确认中文标签清晰后再扩展。[项目](https://github.com/li3zhen1/Grape) |
| 星图交互草案 | force-graph Web 库 | 能快速探索点击、高亮、节点展开等交互；它是 HTML5 Canvas/JavaScript，不是能直接放入 SwiftUI 的原生组件。[项目与示例](https://github.com/vasturiano/force-graph) |

## 候选核验

### Grape：可直接评估的原生候选

仓库提供 `Grape`（SwiftUI 图视图）和 `ForceSimulation` 两个模块，Package.swift 声明 Swift tools 5.9、最低 iOS 17。采用 MIT 许可，使用和修改需保留版权与许可声明。[模块与平台](https://raw.githubusercontent.com/li3zhen1/Grape/main/Package.swift)、[许可](https://raw.githubusercontent.com/li3zhen1/Grape/main/LICENSE)

发布页可查到 1.1.0 和多个历史版本，说明有版本化记录；这不等同于承诺未来维护。正式引入前应固定版本，并在 USB 连接的 iPhone 上验证中文标注、点选、缩放、减少动态效果以及实际节点量的耗电和流畅度。[发布记录](https://github.com/li3zhen1/Grape/releases)

建议默认展示 5–12 位相关诗人，点中才显关系说明；这是原型起点，不是性能上限。朝代适合作为分区或过滤条件；“同一朝代”和“真实交往”应有不同视觉语义，避免读者误认。

### force-graph：Web 原型候选

项目使用 HTML5 Canvas 绘图，提供节点/边配置、交互和示例；MIT 许可允许按许可条件复用。适合验证星图是否易读。要放进原生 App，需要 Web 容器及交互桥接等额外工作，不能把 Web 演示当作已经完成的 SwiftUI 实现。[源码与示例](https://github.com/vasturiano/force-graph)、[许可](https://raw.githubusercontent.com/vasturiano/force-graph/master/LICENSE)

本轮核实了仓库与源码可访问；未核实其最新提交日期，不以“仍活跃维护”作为选型结论。

### MapLibre Native：高度定制底图时再考虑

MapLibre Native 是面向 iOS 等平台的开源矢量地图渲染库，采用 BSD-2-Clause；项目存在独立的贡献、变更与平台文档。它是可复用的地图引擎，不自带本项目需要的历史地理资料。自定义底图路线还需单独选瓦片数据、样式、托管与相应授权，不能把引擎免费理解为所有地图服务免费。[项目](https://github.com/maplibre/maplibre-native)、[许可](https://raw.githubusercontent.com/maplibre/maplibre-native/main/LICENSE.md)

建议首版优先 MapKit，等证明常规底图无法承载需要的意境或历史层后再评估 MapLibre。SwiftUI 原生地图已支持自定义标注和路径覆盖，可以先验证产品价值。[Apple MapKit](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)

## 需要先决定的内容语义

以下是由功能需求推导的建模建议，不是第三方组件已经替我们完成的能力：

- 地图上的“诗词与地点关联”区分创作地、描写地、诗人活动地，并保留未知或有争议的情况。不能用诗人籍贯替代每首诗的创作地。
- 生平节点支持大致年份和时间范围；关联作品可为空，不为了每个节点都有诗而捏造对应关系。
- 星图的交往、亲属、师承、唱和等连接保存来源；同朝代是分类，文学影响是另一种关系。
- 第一轮原型用少量经过核实的人、地、诗数据，优先验证可读性；庞大空壳图谱无法验证用户想要的乐趣。

## Stitch 到 iOS 的边界

Google 官方介绍了界面生成、前端代码导出及 Figma 衔接；2026 年官方更新进一步介绍设计系统 `DESIGN.md`、交互预览、向开发工具导出，以及 Web 发布。这些一手资料没有保证生成可直接构建、签名和安装的 SwiftUI 工程。[初始官方介绍](https://developers.googleblog.com/en/stitch-a-new-way-to-design-uis/)、[设计系统与原型更新](https://blog.google/innovation-and-ai/models-and-research/google-labs/stitch-ai-ui-design/)、[导出更新](https://blog.google/innovation-and-ai/models-and-research/google-labs/stitch-updates/)

建议流程：先确定核心页面与内容语义 → 用户启用 Stitch 后生成视觉与交互参考 → 获取设计规则与可用素材 → 在实际 iOS 技术栈中落实原生地图、导航和状态 → 经 Mac 构建签名、Linux USB 安装验证。不要提前把 Stitch 的视觉交付等同于完整原生实现。
