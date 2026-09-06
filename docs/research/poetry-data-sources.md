# 中国古诗词 App：免费资料来源初查

核查日期：2026-09-05。只使用项目自身网站、仓库与官方文档。本次核实的是公开文档和许可声明，未批量下载、逐条校勘或验证 API 的运行可靠性。以下起步规模与数据组织方式是建议，尚未作产品决策。

## 结论

诗词原文有可直接获取的开源语料；真正需要投入编辑工作的部分是可靠的写作地点、重要生平事件与作品的对应关系，以及简短而准确的情感解读。不能因为数据免费可读，就认为可以打包到 App、再分发或商业使用。

| 来源 | 适合提供 | 获取方式 | 使用边界与缺口 |
| --- | --- | --- | --- |
| [chinese-poetry](https://github.com/chinese-poetry/chinese-poetry) | 唐诗、宋诗、宋词等原文与作者信息 | 下载仓库中的 JSON；固定 commit 后导入自己的数据库 | 仓库声明 MIT，保留版权和许可文本。不是已经校勘完成的诗人生平、地点和关系库；作者简介等衍生文字仍需检查来源 |
| [中文维基文库](https://zh.wikisource.org/) | 古籍原文、版本对照和生平史料 | MediaWiki API、单页 XML 导出、Wikimedia dumps | 按具体作品和页面的版权标记处理；古籍原文、编辑贡献、现代译文不能混为同一种权利状态 |
| [Wikidata](https://www.wikidata.org/wiki/Help:Data_access) | 人物标识、别名、日期、地点与外部数据库 ID 的补充 | 实体 JSON、API、SPARQL、数据转储 | 结构化数据为 CC0；逐条检查引用和覆盖度，不假定有完整交游图或写作地点 |
| [CBDB](https://cbdb.hsites.harvard.edu/) | 人物生卒、亲属、社会关系、任职等 | 官方提供 SQLite、Access 下载，人物 API 可按 ID/名字返回 JSON | 学术分支为 CC BY-NC-SA 4.0；存在中国大陆独家商业授权。不能默认作为未来商业 App 的免费生产数据 |
| [CHGIS V6](https://chgis.fas.harvard.edu/data/chgis/v6/) | 历史地名与行政区划，辅助古今地点对应 | 官方 Dataverse 下载；项目另有地名查询/API入口 | V6 明确限学术研究，禁止商业使用、转售和再分发。不能直接把下载数据随 App 发布；也不是诗词创作地点数据集 |

## 可实施的原文起点

chinese-poetry 的[全唐诗目录](https://github.com/chinese-poetry/chinese-poetry/tree/master/%E5%85%A8%E5%94%90%E8%AF%97)实际包含唐宋诗文 JSON 和作者 JSON，可复用现成数据格式，避免重新抓取大量网页。仓库的 [MIT LICENSE](https://github.com/chinese-poetry/chinese-poetry/blob/master/LICENSE)允许复制、修改和分发，要求保留许可与版权声明；项目许可声明不等于已经替所有第三方内容完成来源核查。初期优先采用古诗词原文，抽样检查错字、重复、异文、简繁转换和作者归属。

维基文库更适合作为具体作品与史料的核对入口。其[版权规则](https://wikisource.org/wiki/Wikisource:Copyright_policy)区分公有领域与开放许可作品，现代翻译或录音具有独立权利状态。[中文版权信息](https://zh.wikisource.org/zh-hant/Wikisource%3A%E7%89%88%E6%9D%83)说明编辑贡献的许可。[MediaWiki 导出文档](https://www.mediawiki.org/wiki/Help:Export)提供单页和批量数据获取方法；[API Query](https://www.mediawiki.org/wiki/API:Query)支持页面查询和 XML 导出。导入时保存页面固定版本链接、作品版本与许可，不只保存纯文本。

本次没有核实到同时具备完整覆盖、清晰再分发许可与可靠质量的免费现代译注全集。首版可自行撰写少量短解读并人工校阅，把长赏析作为可选展开；未核实许可的免费诗词网站先用作线索，不能直接整站搬运。

## 人生路线和星河图谱的数据边界

CBDB 的[人物 API 文档](https://cbdb.hsites.harvard.edu/cbdb-api)列出按姓名或 ID 查询、JSON 返回方式，并展示亲属和社会关系及来源。适合验证关系类型与生平数据模型，但不保证每位诗人的每段行旅都有记录。

其[当前下载页](https://cbdb.hsites.harvard.edu/download-cbdb-standalone-database)明确学术分支许可为 CC BY-NC-SA 4.0，并链接 SQLite；[商业授权说明](https://cbdb.hsites.harvard.edu/exclusive-commercial-license)说明中国大陆的独家商业授权安排。若商业方向尚未确定，建议研究阶段与发布数据分开管理，优先独立查证公开史料或评估可取得的授权。

Wikidata 的[许可政策](https://www.wikidata.org/wiki/Wikidata:Licensing)明确结构化数据采用 CC0，可作为标识与基础事实补充。它不等于已验证的诗人关系全集。关系图中“亲属”“有赠答诗”“同时代”“后世影响”应分别建模；同时代不意味着相识，有赠诗也不能无条件推断会面。

## 地图最需要避免的误读

CHGIS 的[项目介绍](https://chgis.fas.harvard.edu/)说明它提供历史地名、行政单位与 GIS 基础；[V6 许可页](https://chgis.fas.harvard.edu/data/chgis/v6/)明确禁止再分发，因此可作为受许可约束的研究候选，不能直接选作免费发布底库。

建议将“创作于”“描写了”“提及”“诗人到访”分别记录。诗中出现的地名不能直接当作写作地点；作者籍贯也不能替代创作地。地点关联保存史料引用、时间范围、现代近似位置、确定性和争议备注。无法确定创作地的作品仍可用“诗中之地”入口呈现，但界面必须说明关联类型。

## 小规模起步建议

先选 3–5 位有交集的诗人、30–50 首诗词、10–20 个可考地点，建立一组能够连起来的编辑样本。每位诗人整理 5–8 个重要节点，只给有依据的节点配作品；对有证据的关系画线，并可点击查看关系含义。

最低来源字段建议为：来源 URL/书目、具体卷页或页面版本、源数据 ID、获取日期、许可、编辑记录。作品另存异文；地点和关系另存关联类型、时间范围和证据状态。氛围图像、音乐、解读标签属于表达层，不能让 AI 生成内容反过来充当历史事实的证据。

这个样本足以讨论地图、人生路线、关系图和情境阅读是否连贯；确认体验后，再评估规模化导入与编辑成本。
