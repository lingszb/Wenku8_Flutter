# 四季纪念背景：资产审计与接入约定

> 历史实施记录，仅代表文中基线与当时验收结果，不作为当前能力或操作授权。现行范围见 [源码构建说明](../SOURCE_BUILD.md)，文档分类见 [文档索引](../README.md)。

审计基线：`57f6c52`，2026-11-06。前半部分记录修复前的调用与资产缺口；后半部分记录用户问答确认后的四季成品和接入方式。设备相册/分享验收与自动 PNG 测试分开记录。

## 1. 已确认的资产边界

`assets/report/` 和 `assets/reading_previews/` 均不在当前提交树中，`pubspec.yaml` 也没有声明它们。不能因为 Dart 中存在路径而认为图片已打包。

### 缺失的报告/纪念/摘录原图：13 张

| 旧主题 ID | 源码中请求的路径（相对 `assets/report/`） |
| --- | --- |
| `archive` | `char_cover.webp` |
| `shelf` | `scene_mist_harbor.webp`、`scene_mist_harbor_portrait.webp` |
| `editorial` | `char_season_spring.webp`、`char_season_summer.webp`、`char_season_autumn.webp`、`char_season_winter.webp` |
| `constellation` | `char_night_desk.webp` |
| `signal` | `char_papercut.webp` |
| `score` | `char_pv_open.webp` |
| `ink` | `scene_mountain_dawn.webp`、`scene_mountain_dawn_portrait.webp` |
| `festival` | `char_pv_train.webp` |

其中 `editorial` 按事件日期或调用方固定的绘图日期选季：3–5 月为春、6–8 月为夏、9–11 月为秋、其余为冬。

### 缺失的通用主题缩略图：8 张

`ReadingVisualTheme.artAsset` 请求 `assets/reading_previews/<id>-117.webp`，ID 为 `archive`、`shelf`、`editorial`、`constellation`、`signal`、`score`、`ink`、`festival`。

当前找到的两个 `ReadingVisualThemePicker` 调用方（纪念设置、摘录卡）均传入 `readingKeepsakeThemePresentation`，因此实际走 `report` 图片路径。上述 8 张属于选择器默认路径的独立缺口，不能据此声称这两个页面正在加载它们。现有 `scripts/sync_reading_theme_previews.py` 可从已在仓库的 `assets/reading_art/*-117.png` 生成 420×280 缩略图；是否补齐该独立路径需按本次最终范围决定。

### 现有图片不等于缺失原图

`assets/reading_art/` 存在 110/117 PNG、WebP 与 `creation-117.json`。其 README 记录了既有项目生成图和 1536×1024 母版，但它们不是 `report` 注册表请求的文件，当前 `pubspec.yaml` 也没有将它们作为这里的运行时图片打包。不得从上游 APK 提取未知许可的图来补路径，也不将“当前提交树缺失”推断为“确定私有或侵权”。

## 2. 调用链与实际失效方式

| 模块 | 职责与当前行为 |
| --- | --- |
| `lib/reading_export_theme.dart` | `readingExportArt` 选择路径；`readingExportTheme` 定义 8 种导出版式的颜色、文字色和对齐方式。 |
| `lib/reading_keepsake_theme.dart` | 纪念与摘录的轻量适配，转发记录日期/绘图日期、竖图参数；创建选择器展示信息。 |
| `lib/reading_moment_content.dart` | 纪念弹窗与导出共用的内容树；`Image.asset` 当前没有背景图 `errorBuilder`，缺图会产生资源异常。真实书籍封面是独立 `Image.memory` 路径，不应被四季背景替换。 |
| `lib/reading_moment_export.dart` | 离屏绘制前 `precacheImage(AssetImage(...))`；当前捕获预热错误后重新抛出，缺图会直接阻断 PNG 导出。 |
| `lib/reading_moments_ui.dart` | 展示真实/示例纪念、保存与分享；读取书籍封面，调用纪念 PNG 生成与平台桥接。 |
| `lib/reading_moments_settings_page.dart` | “纪念图片”主题选择与“预览效果”；使用报告原图路径，而非通用缩略图路径。 |
| `lib/quote_card.dart` | 摘录卡版式与画布导出；`loadQuoteThemeArt` 直接 `rootBundle.load`，缺图时显示“主题图片读取失败”并阻断导出。它与纪念共用同一原图注册表。 |
| `lib/reading_visual_theme_picker.dart` | 两种缩略展示均有纯色 `errorBuilder`，可隐藏缩略图失败，但不能修复完整纪念或摘录导出。 |
| `lib/reading_report_options.dart` | 使用共享主题标签/配置，并不自行加载图片。 |
| `lib/reading_report_page.dart` | 当前是基础统计页，明确提示报告图片导出暂未开放；本次资产修复不自动等于恢复完整报告编辑与导出。 |

## 3. 版面与裁切约束

纪念页面不是将文字烘焙进一张固定海报。标题、日期、阅读时长、书名与封面均由真实数据实时排版；背景图不要包含文字、Logo、二维码、日期或伪造统计。

| 表面/版式 | 当前几何 |
| --- | --- |
| 四季手帐、胶片、远山、明信片主图 | `panorama` 为 1080:608（约 16:9），默认 `BoxFit.contain`；部分带边距或纸框。 |
| 阅读档案 / 剪纸小图 | 约 3:4 竖向图框，部分 `contain`。 |
| 夜读版式 | 约 9:16 竖向图框，`cover`，旧对齐偏右。 |
| 雾港版式 | 图片在宽度×0.72（紧凑）或×1.02（完整）的头图区，`cover`，有渐变遮罩；文字在顶部与底部叠加。 |
| 导出主题缩略卡 | 101×114 的图框，`cover`，按主题对齐；其他默认选择器预览也使用 `cover`。 |
| 摘录画布 | 逻辑宽 480，主图图框包括 432×243.2、224×392、150×200 等；正文另行分页，不可裁掉正文。 |
| 纪念 PNG | 内容以逻辑宽 386 排版、自适应高度；导出宽度最多约 1080、总像素不超过 1200 万、高度最多 8192，PNG 上限 12 MiB。 |

只替换四季手帐时，横向约 16:9 的四张母图最贴合现有主图。若用户确认让四季背景服务全部版式，应先统一新背景的对齐/裁切约定：旧的右对齐会把横图中央主体裁掉，不能直接套用原人物图的 `previewAlignment`。

四季图宜有纸感、克制的光照与较低饱和度，保持一个系列。需要跨横竖裁切时，将关键识别物集中在中央可见区，边缘允许裁切；上方约 12%、下方约 25% 保持低细节，以便雾港等叠字布局增加渐变遮罩。生成后仍必须按真实图框检查夜樱、星空、满月、初雪是否保留，不能单凭母版观感确认。

## 4. 已确认的问答与兼容范围

用户从 A 纸感版画、B 柔和手绘、C 电影写实三种同场景样图中选择 **A：低饱和纸感版画，留白、细颗粒、克制光影**，并确认 **纯风景、无人物、无文字**；替换范围为 **所有纪念和摘录主题统一使用四季风景**。

所有主题按照同一记录日期选择季节：3–5 月春、6–8 月夏、9–11 月秋、12–2 月冬。保留 8 个 `ReadingVisualTheme` ID、旧别名、布局和颜色；展示名称/说明调整为实际四季风景，不再声称人物、台灯或列车。旧纪念、书籍、偏好和备份不迁移、不重编号、不改日期。

真实纪念使用 `earnedAt`；有日期摘录使用 `recordedAt`，无日期摘录在打开时固定 `artAt`，预览与导出沿用同一值，不伪造记录日期。原生小组件数据与真实书籍封面独立保留。

## 5. 已实施的加载与布局

- `readingExportArt` 统一解析到四张 PNG；默认主题缩略图也使用同一入口，不再请求缺失的 `reading_previews`。
- `loadReadingArtwork` 读取并验证图片，缺失/损坏时生成同一确定性纸面山线 PNG。`ReadingArtworkImage`、纪念预热/离屏绘制和摘录解码共用这一决策，不依赖网络或额外资产。
- 移除已失效的旧人物/横竖图路径字段。人物 3:4、夜读 9:16 小图框及主图统一适配 3:2 风景，调整摘录头部几何并保留正文分页，避免裁掉季节识别物。
- 深色叠字版式增加顶部渐变遮罩，浅色与深色版式仍使用原有前景色与布局。背景中不烘焙任何书名、日期或统计。
- 可选书籍封面解码失败时，导出遵循 UI 原有的隐藏封面行为；真正的文字布局、内存、PNG 尺寸、相册权限或分享失败仍按原路径报告。

前文第 3 节中的人物/竖向几何是修复前的审计记录，当前新增风景图框以 3:2 为主。

## 6. 自动验证与设备验收

`test/reading_artwork_test.dart` 覆盖：12 个月 × 8 个旧主题/别名；真实四季 PNG 打包解码；缺失和损坏背景生成同一可解码回退；摘录缺图解码；全部旧纪念布局离屏导出；真实四季在浅/深纪念与摘录布局中导出；可选封面存在和损坏两种导出。

测试中的字体不等同于设备字体，测试渲染图不能当作中文排版设备截图。Android 验收需分别确认纪念预览、完整 PNG、系统相册保存和分享，且不将基础阅读报告页描述为已恢复完整报告编辑器。

## 7. 四张成品与来源

使用内置 `image_gen` 工具按用户选择生成；精确模型版本不由该工具接口暴露。春图以本次生成的 A 风格样图为风格参考；夏图经同一工具去除误带的春樱，保留夏叶与繁星；秋、冬按相同纸感风格生成。未提取或复制上游缺失报告图。

完整提示词和用户选择保存在 [seasonal-art-prompts.json](../seasonal-art-prompts.json)。运行时仅打包以下四张无字 PNG，比较样图不打包。

| 季节 | 文件 | 尺寸 | SHA256 |
| --- | --- | --- | --- |
| 春观夜樱 | `assets/report/season-spring.png` | 1536×1024 | `7efbcb36951061ac25ec2965772d4d0552a595d6ede6b3f1d9a35f733665274a` |
| 夏望繁星 | `assets/report/season-summer.png` | 1536×1024 | `4c09c41f5131ddcc649ff58c01d610ea4f116dedbb2eca4a7e71a5b12b91f054` |
| 秋赏满月 | `assets/report/season-autumn.png` | 1536×1024 | `2f37c84d269a09d920cc9e723f51f414866fd298df9a73ccb5c42244789d975b` |
| 冬会初雪 | `assets/report/season-winter.png` | 1536×1024 | `3dadf95f5b81031e4a21db38300c2ddc20d2b88ef96a3953f70e10966b18f94f` |

图片已登记 `pubspec.yaml` 和公开源码清单；不改变既有真实书籍封面、正文或阅读数据。
