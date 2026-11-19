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
const _illustrations = '正文插图可长按查看大图，单击仍用于阅读控件。';
const _warmup = '应用回到前台或关闭图库后恢复插图预热，减少翻页时的加载等待。';
const _navigation = '「导航与启动」支持拖动手柄调整底部 Tab 顺序。';
const _changes = [_illustrations, _warmup, _navigation];
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

- $_illustrations
- $_warmup
- $_navigation

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
