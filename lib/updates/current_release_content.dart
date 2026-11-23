import 'release_notices.dart';

class ReleaseSection {
  const ReleaseSection(this.title, this.items);
  final String title;
  final List<String> items;
}

const releaseFreeNotice = '**本项目完全免费，请勿购买所谓付费版、激活码或解锁服务。**';
const releaseProjectNotice =
    '纸间是一款本地优先的独立阅读应用，不连接任何在线书库。本地书籍由用户自行导入，安装包不附带小说文件。';
const releaseRightsNotice =
    '小说、封面和插图归各自权利人所有。请仅使用有权访问的内容，遵守来源网站规则，不得绕过访问限制、破解 DRM，或未经许可传播、出售内容。';
const releaseReadingNotice = '**书籍目录、正文、封面和插图从本地导入文件或已有历史缓存读取。**';
const releaseMaintenanceNotice = '项目以稳定维护为主，后续非必要不再发版。';
const _epubMetadata = 'EPUB 详情页新增副标题、插画师和出版信息，并从原书导入简介与标签。';
const _epubStyles = 'EPUB 排版支持更多列表标记、上下标、删除线和预格式空白。';
const _epubUpgrade = '升级旧 EPUB 排版时保留原书，并转换阅读坐标和书内链接目标。';
const _readerFooter = '阅读器可分别控制合订卷号、自动话号和页码的显示，详情页目录支持按卷浏览。';
const _libraryBatch = '改进本地书库的批量分类、封面整理与导入入口。';
const _changes = [
  _epubMetadata,
  _epubStyles,
  _epubUpgrade,
  _readerFooter,
  _libraryBatch,
];
const _androidInstall = '**Android ARM64**：已安装同签名正式版的用户可直接覆盖更新。';
const _backup = '升级、整理存储或同步前，请先备份重要书籍和阅读记录。';
const publicReleaseNotes =
    '''
### 免费使用，请勿付费

$releaseFreeNotice

$releaseProjectNotice

$releaseRightsNotice

$releaseReadingNotice

**$currentReleaseSourcePolicy**

### 本次更新

- $_epubMetadata
- $_epubStyles
- $_epubUpgrade
- $_readerFooter
- $_libraryBatch

### 后续维护

$releaseMaintenanceNotice

### 安装说明

- $_androidInstall

$_backup
''';
const currentReleaseNotes = publicReleaseNotes;
const currentReleaseSummary = [
  releaseFreeNotice,
  releaseReadingNotice,
  currentReleaseSourcePolicy,
  ..._changes,
  releaseMaintenanceNotice,
];
const currentReleaseSections = [
  ReleaseSection('重要说明 · 请务必阅读', [
    releaseFreeNotice,
    releaseProjectNotice,
    releaseRightsNotice,
    releaseReadingNotice,
    currentReleaseSourcePolicy,
  ]),
  ReleaseSection('本次更新与后续维护', [
    ..._changes,
    releaseMaintenanceNotice,
    _androidInstall,
    _backup,
  ]),
];
