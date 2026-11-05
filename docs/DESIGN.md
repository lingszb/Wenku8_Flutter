# 设计规范提取：本地阅读器视觉与交互系统

> 状态：**源码提取版 v0.1**。面向 Wenku8_Flutter Fork 的 Android 本地阅读器改造。
>
> 原则：本文是从当前仓库中的 Flutter 实现、现有说明和设计素材归纳出的**维护参考**，不是对未来所有页面的一刀切重设计。**“已实现”**表示可以追溯到源码或原有文档；**“二开约束 / 建议”**是本 Fork 新增的工作约定。存在冲突时，应先检查运行代码、用户设置与实际截图，再修订本文。文中数值属于具体组件，不应误用为全局 Token。

## 1. 设计目标与边界

### 已实现的视觉语言

- **纸页与档案**：暖纸色画布、墨色文本、细分割线、文件编号、折角与书脊造型；详情与设置页采用编辑式信息组织。
- **轻玻璃，而非满屏毛玻璃**：顶部、底部导航及交互控件使用透光层与有限模糊，正文仍由稳定、清晰的阅读纸面承载。
- **动作有书籍语义**：折页图标、书籍封面飞行、导航切换、菜单展开与页面揭示等动效以状态变化为目的，而非持续装饰。
- **内容优先**：阅读字体、行距、语言与排版由用户或单本书设置决定，不被 App 的装饰风格覆盖。

### 二开约束

1. **本地优先**：首个 APK 以 TXT / EPUB 导入、书架、目录、阅读、进度及书签为核心；不再为 Wenku8 账号、在线发现、在线目录或评论恢复入口。
2. **保留视觉资产**：去除在线依赖时保留书架、档案标题、玻璃组件、原创图标及翻页反馈；不要用临时 Material 控件整页替换成熟设计。
3. **渐进优化**：优先复用现有样式与组件。新增 Token 前查找相关源码；修改共用组件时验证所有调用页。
4. **可阅读、可访问、可降级**：浅色与深色、不同字体大小、高对比度、减少动态效果、低性能模式均应可用。
5. **AI 功能暂非首版范围**：未来 AI 问答/摘要/检索界面延续同一套视觉语汇，但不得以视觉效果妨碍正文阅读。

## 2. 色彩与主题

### 已实现：原始纸张 / 档案配色

取自 [archive_design.dart](../lib/archive_design.dart) 中的 ArchiveDesign；下表为**原始配色**，不是所有自定义主题都强制使用的颜色。

| 语义 | 原始 Token | 色值 |
| --- | --- | --- |
| 浅色画布 | background | #F4F3EF |
| 浅色内容表面 | surface | #FDFCFA |
| 奶白层 | milk | #FEFDF8 |
| 深色画布 | darkBackground | #191919 |
| 深色表面 | darkSurface | #242424 |
| 深色抬升层 | darkRaised | #2D2D2D |
| 深色高抬升层 | darkRaisedHigh | #3A3A3A |
| 深色描边 | darkOutline | #3C3C3C |
| 深色主要文字 | darkInk | #F2F2F2 |
| 深色次要文字 | darkMuted | #B7B7B7 |
| 深色奶白层 | darkMilk | #F6F6F6 |

[app_ui.dart](../lib/app_ui.dart) 另定义 ink = #181818、accent = #202020、hairline = #D8DBD5，画布 canvas 引用 ArchiveDesign.background。原始主题由 novelTheme 配置 Material 3 ColorScheme，支持明暗模式；**不要把这些固定十六进制值直接写入业务页面**。

[app_palette.dart](../lib/app_palette.dart) 定义 AppPaletteSource.original / system / custom，以及 AppTonalColors。系统或自定义调色板可能改变表面和强调色，优先使用 Theme.of(context).colorScheme、AppTonalColors 和组件现有封装。

### 二开约束

- 默认保留原始的暖纸色和低饱和墨色；新增配色必须同时验收浅色、深色和用户自定义配色。
- 正文色与背景应保证充分对比度。不要仅靠透明度区分禁用、错误与选中。
- 细线、档案编码、版面留白用于建立层次，不叠加大面积彩色卡片或高饱和光晕。

## 3. 字体、字号与阅读排版

### 已实现

- [archive_design.dart](../lib/archive_design.dart)：ArchiveMasthead 标题为 23、字重 w800、行高 1.18；ArchiveDesign.codeStyle 使用 monospace、9 号字、字距 1.05，作为档案编号等**装饰性附属信息**。不是通用正文尺寸。
- [app_typography.dart](../lib/app_typography.dart)：可选系统字体、思源宋体/黑体、霞鹜文楷、朱雀仿宋等字体族。具体可用性取决于字体资源与用户设置。
- [reader_book_style.dart](../lib/reader_book_style.dart)：每本书可独立保存字体大小、行高、字体、纸张、边距、首行缩进、字距、阅读语言等，行高持久化校验区间为 1.3～2.2。
- [docs/READER.md](READER.md) 记录 EPUB 原有段距、注音、混合排版及书内跳转等正文规则。

### 二开约束

- 区分 **App 界面排版** 与 **正文阅读排版**：不要把档案风格的标题字号、字距或等宽字体传递给小说正文。
- 正文设置与原书语义优先；修改 EPUB/TXT 渲染不能随意抹去段落留白、注音、插图布局、章节锚点。
- 不用固定高度强制截断大字号文本；标题和按钮在系统文字放大时应可阅读或合理换行。
- 新页面优先选 AppText 和现有文字样式，不引入一套互不兼容的字体层级。

## 4. 布局、留白与导航

### 已实现的局部几何

| 场景 | 源码参数 | 当前数值 |
| --- | --- | --- |
| 档案面板圆角 | ArchiveDesign.panelRadius | 4 |
| 封面圆角 | ArchiveDesign.coverRadius | 3 |
| 顶部悬浮导航栏 | FrostedHeader.toolbarHeight | 56 |
| Dock 图标 | DockLayout.iconSize | 20 |
| Dock 标签字号 | DockLayout.labelFontSize | 11 |
| Dock 内水平留白 | DockLayout.horizontalInset | 6 |
| Dock 高度 | DockLayout.height | Android 54 / iOS 50 |
| Dock 横向操作最大宽度 | DockLayout.actionMaxWidth | 620 |

来源：[archive_design.dart](../lib/archive_design.dart)、[app_ui.dart](../lib/app_ui.dart)、[dock_layout.dart](../lib/dock_layout.dart)。这些是**组件自身数值**，不能理解成所有页面都必须使用 4px 圆角或 56px 高度。

[app_ui.dart](../lib/app_ui.dart) 的 ArchiveHeaderBar 将标题居于导航平面的几何中心，并为两侧控件预留对称空间；FrostedHeader 的渐变模糊与可操作控件分层，避免滚动内容误抢手势。

### 当前 Fork 的导航边界

[home_navigation.dart](../lib/home_navigation.dart) 保留既有页面身份，只显示索引 2「本地」与索引 3「我的」。[local_library_page.dart](../lib/local_library_page.dart) 及 [local_library_preferences.dart](../lib/local_library_preferences.dart) 保留立体书架、列表、网格和分组能力；默认 LocalLibraryView.shelf。

**二开约束**：删掉在线页面的入口，不等于重排历史页面索引或删除立体书架。需要重新编号时，应先核对存储偏好、路由及旧进度迁移。底部导航、顶部标题和内容滚动需遵守安全区与横竖屏变化。

## 5. 组件复用地图

| 场景 | 优先检查 / 复用 | 维护要点 |
| --- | --- | --- |
| 主题和基础控件 | [app_ui.dart](../lib/app_ui.dart) 的 novelTheme、GlassIconButton、GlassPillButton、GlassHeaderLayout、FrostedHeader | 统一主题、无障碍和触感 |
| 档案式标题、页段 | [archive_design.dart](../lib/archive_design.dart) 的 ArchiveMasthead、ArchiveSection、ArchiveCode | 保持墨线、编号、留白 |
| 底部导航 | [glass_dock.dart](../lib/glass_dock.dart)、[dock_layout.dart](../lib/dock_layout.dart) | 保持选中状态、安全区、滚动让位 |
| 液态玻璃控件 | [glass_controls.dart](../lib/glass_controls.dart)、[glass_optics.dart](../lib/glass_optics.dart) | 保持材质、手势和降级路径 |
| 图标 | [archive_icons.dart](../lib/archive_icons.dart) 与 [ICON_SYSTEM.md](ICON_SYSTEM.md) | 首选已有语义图标 |
| 动效 / 路由 | [motion_ui.dart](../lib/motion_ui.dart)、[archive_motion.dart](../lib/archive_motion.dart) | 不新增无意义常驻动画 |
| 本地书架 | [local_library_page.dart](../lib/local_library_page.dart)、[archive_carousel.dart](../lib/archive_carousel.dart) | 保留立体书架及视图切换 |
| 阅读器设置 | [reader_book_style.dart](../lib/reader_book_style.dart)、[READER.md](READER.md) | 不覆盖用户/书籍自定义设置 |
| 统计与主题卡片 | [reading_visual_theme.dart](../lib/reading_visual_theme.dart)、[READING_WIDGETS.md](READING_WIDGETS.md) | 使用原有主题身份和资产 |

复用时应查找真实调用方式，不因组件名称带有 Wenku 或 Offline 就认为它属于在线业务。某些旧名称只是兼容已有阅读记录或 MethodChannel。

## 6. 玻璃材质与渲染性能

### 已实现

- GlassAppearance 在 [app_ui.dart](../lib/app_ui.dart) 中默认 blur = 8、opacity = 0.87，作为外观配置上下文；**单个控件不一定使用 8 的实时模糊**。
- 同一文件内 AppControls._material 为开关、滑块、分段选择定义共享样式，常规控件本身 blur = 0、dispersion = 0，依托已处理的背景与光学折射，避免重复模糊。
- [performance_preferences.dart](../lib/performance_preferences.dart) 区分玻璃折射、背景模糊、边缘模糊、页面过渡、动态图标和立体书架的独立性能开关。关闭重特效时仍须保留可读、可操作的轻量界面。
- [third_party/liquid_glass_easy/PATCHES.md](../third_party/liquid_glass_easy/PATCHES.md) 记录渲染实现的性能优化和像素一致性验证。

### 二开约束

- 不在正文每个段落或书架每张卡片上附加独立实时模糊层。
- 新按钮优先复用现有玻璃封装，不在业务层直接拼接 Blur / BackdropFilter / Shader。
- 高对比度、减少动态效果与低性能模式必须能绕过昂贵的装饰效果，但不能绕过核心阅读能力。
- 不以模拟器截图推断真实 ARM64 设备的耗电、帧耗时或长时间发热；性能结论需要设备实测。

## 7. 动效、图标与交互反馈

### 已实现：时间与状态

| 动作 | 来源 | 时长 |
| --- | --- | --- |
| 点击接触反馈 | NovelMotion.contact | 120 ms |
| 通用页面入场 | NovelMotion.enter | 420 ms |
| 通用页面退出 | NovelMotion.exit | 320 ms |
| 封面飞行 / 返回 | NovelMotion.coverFlight / coverReturn | 1000 / 840 ms |
| 阅读翻页部件 | ReaderTurnScope.duration | 620 ms |
| 原创图标入场 | ICON_SYSTEM.md | 520 ms |
| 原创图标确认点击 | ICON_SYSTEM.md | 640 ms |
| 原创图标状态变形 | ICON_SYSTEM.md | 380 ms |

来源：[motion_ui.dart](../lib/motion_ui.dart)、[reader_turn_motion.dart](../lib/reader_turn_motion.dart) 和 [ICON_SYSTEM.md](ICON_SYSTEM.md)。

图标使用 24×24 基准画布、默认 1.72 画布单位笔画，以折页、墨块、切角组成统一家族。入场与点击动作不应移动文字或改变布局占位。需要新语义时先检查 ArchiveSymbol；不应混入风格不一致的彩色图标。

### 触摸与振动

[HAPTICS.md](HAPTICS.md) 定义语义触感、强度、取消手势和后台静默规则；有效触感至少间隔 65 ms，避免叠加。触摸热图数据与 UI 的分离原则见 [TOUCH_FINGERPRINT.md](TOUCH_FINGERPRINT.md)。

### 二开约束

- 所有动效都应说明触发条件、取消条件和完成状态；页面切后台、被遮挡或离屏时不继续无意义动效。
- 系统/用户要求减少动态效果时，不强制转场和动态图标动作。
- 交互被取消时不触发成功触感；程序性恢复焦点、自动加载和预读不振动。
- 不把转场、书架动画或玻璃高光做成高频持续循环。

## 8. 本地阅读关键流程的设计验收

以下是本 Fork **新增的检查标准**，并非宣称当前全部通过：

| 场景 | UX 验收要点 |
| --- | --- |
| 空书架 | 明确导入操作；不出现已下线的 Wenku8 账号、发现或云书架入口 |
| 导入 TXT / EPUB | 系统文件选择、导入中、成功、重复、失败和损坏文件都有可理解反馈 |
| 书架展示 | 立体书架 / 列表 / 网格切换不丢失分类、排序与原有书籍 |
| 书籍详情 | 封面、书名、作者、目录和本地操作可用；无在线评论/下载空壳 |
| 正文阅读 | 翻页、滚动、横竖排、文字选择、插图和边距调整不互相破坏 |
| 进度与书签 | 退出、重启、章节跳转及重新打开后仍能准确回到阅读位置 |
| 断网 | 已导入书籍仍可打开；联网附属功能失败不阻塞本地阅读 |
| 低性能 / 无障碍 | 关闭玻璃/动效后所有核心操作仍可达，文字缩放和暗色模式不溢出 |

当前仓库的 [SOURCE_BUILD.md](SOURCE_BUILD.md) 和 [LOCAL_READER_REMOVAL.md](LOCAL_READER_REMOVAL.md) 记录了 Android x86_64 Debug 模拟器的基础验收；**ARM64 真机和 Release 性能尚需独立验收**。

## 9. 未来 AI 阅读界面：建议方向（尚未实现）

这一节仅为二开的**前瞻约束**，不得当作当前功能清单：

- **入口**：优先在已有文字选择菜单或阅读器工具栏中增加轻量 AI 操作，避免常驻悬浮聊天按钮遮挡正文与翻页热区。
- **摘要与问答**：采用现有玻璃弹层（如 showJellySheet）、档案标题与卡片体系；正文区域保持稳定，不在打开 AI 面板时重排整章文本。
- **语义检索**：结果使用书名、章节和原文摘录，能跳回准确段落；视觉上区分引用证据与模型生成文字。
- **状态**：索引中、无法联网、未配置模型、无答案、超出阅读进度、失败重试都需要明确但低干扰的反馈。
- **隐私**：向云端模型发送书籍片段前明确告知；本地阅读不依赖 AI 是否可用。

## 10. 修改 UI 时的工作流

1. **定位组件**：确定目标页面，检查本文件第 5 节以及相关源码；确认是否存在已有组件和 Token。
2. **明确改动边界**：区分数据层/导航移除与视觉样式改造；原则上不要一次 PR 同时重构两者。
3. **实现并降级**：覆盖浅/深色、系统/自定义配色、文字缩放、减少动态和低性能模式。
4. **截图比对**：至少保留本地书架、书籍详情、正文阅读、阅读设置四类页面的修改前后截图；对比同一设备尺寸、主题、书籍和阅读位置。
5. **运行检查**：至少执行 Flutter 静态分析、Android 可运行构建和关键阅读路径手工验证；视觉细节由实机确认。
6. **提交说明**：PR 描述写明复用或新增的组件、视觉变化、支持的降级模式、验证证据和已知限制。

参考素材：[docs/images/reader.png](images/reader.png)、[docs/images/settings.png](images/settings.png)、[docs/images/discovery.png](images/discovery.png)；其中 discovery.png 属于上游在线发现页面，仅用于原有视觉风格参考，**不是本地版必须恢复的页面**。

**文档准确性提醒**：[ICON_SYSTEM.md](ICON_SYSTEM.md) 仍提及上游的图标 Studio 和部分 test 文件，但当前公开 Fork 未包含这些文件。不得把文档中的示例命令列为本 Fork 已运行、已通过的测试；需要时先补全测试设施。

## 11. 来源索引与更新规则

- **色彩与主题**：[archive_design.dart](../lib/archive_design.dart)、[app_ui.dart](../lib/app_ui.dart)、[app_palette.dart](../lib/app_palette.dart)
- **玻璃与性能**：[glass_optics.dart](../lib/glass_optics.dart)、[glass_controls.dart](../lib/glass_controls.dart)、[performance_preferences.dart](../lib/performance_preferences.dart)
- **图标与动画**：[ICON_SYSTEM.md](ICON_SYSTEM.md)、[archive_icons.dart](../lib/archive_icons.dart)、[motion_ui.dart](../lib/motion_ui.dart)、[archive_motion.dart](../lib/archive_motion.dart)
- **布局与书架**：[dock_layout.dart](../lib/dock_layout.dart)、[home_navigation.dart](../lib/home_navigation.dart)、[local_library_page.dart](../lib/local_library_page.dart)
- **阅读排版**：[READER.md](READER.md)、[reader_book_style.dart](../lib/reader_book_style.dart)、[app_typography.dart](../lib/app_typography.dart)
- **触感与手势**：[HAPTICS.md](HAPTICS.md)、[TOUCH_FINGERPRINT.md](TOUCH_FINGERPRINT.md)
- **设计资产**：[assets/branding/README.md](../assets/branding/README.md)、[reading_visual_theme.dart](../lib/reading_visual_theme.dart)

维护此文档时：

- 代码调整了实际 Token、组件名称、动效时长或行为，应同步更新相关表格与来源链接。
- 新引入的统一设计约束必须明确标注为**二开约束**，不能倒填为“上游已有规范”。
- 文档与可运行实现不一致时，在修正文档前先确认实际 UI 与兼容需求；不要为了使实现匹配过期文档而直接改坏阅读体验。
