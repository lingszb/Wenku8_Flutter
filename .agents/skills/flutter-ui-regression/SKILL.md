---
name: flutter-ui-regression
description: 修改 Flutter 控件、字体、书架、响应式布局、触控区域、主题和动效，或排查 RenderFlex、裁切与文字溢出时使用；只读设计讨论无需执行验证流程。
---

# Flutter 布局与交互回归

遵守[共享规则](../../PROJECT_GUIDE.md)和[视觉规范](../../../docs/DESIGN.md)。图标、触觉和触摸统计分别按需读取 [ICON_SYSTEM](../../../docs/ICON_SYSTEM.md)、[HAPTICS](../../../docs/HAPTICS.md)、[TOUCH_FINGERPRINT](../../../docs/TOUCH_FINGERPRINT.md)。

## 定位与修复

- 复用 `lib/app_ui.dart`、`lib/archive_design.dart`、`lib/archive_icons.dart`、`lib/app_typography.dart` 的控件、颜色、图标与字体；保持 Archive / Glass 风格。
- 书架布局追踪 `lib/archive_wave.dart`、`lib/archive_shelf_geometry.dart` 与 `lib/local_library_page.dart`；动效和降级开关追踪 `lib/motion_ui.dart`、`lib/performance_preferences.dart`。
- 从父约束而非整屏宽度排查：Row / Column、滚动容器、边距、SafeArea、键盘、文字缩放和横屏。嵌套 Flex 前确认有界约束。
- 中日文长标题、作者与状态行需按真实字形度量布局；不靠固定 `fontSize * lineHeight`、全局禁用缩放或裁掉内容掩盖问题。
- 保留触控区域、焦点 / 语义、Hero 身份、LoadingHandoff、阅读入口和既有触觉；遵守减少动态效果、性能与无障碍偏好。不为小修复更换全局控件或调色板。

## 按影响选择验证

1. 优先复用相关 Widget 测试，以受控 viewport、文字缩放、浅深色、长标题 / 缺失作者、空 / 满书架复现本次约束，不强制遍历无关界面。
2. 运行相关静态分析与定向测试；只有变更涉及平台、打包或构建风险时追加本地 APK 构建。PR 的既有 CI 门禁仍须通过。
3. 书架分类控件改动可运行 `flutter test test/shelf_category_picker_test.dart --no-pub`；图片预览 / 导出变化结合 `asset-fallback-export`，分类语义变化结合 `local-library-integrity`。
4. 字体回退、系统输入、实际动效和手势仍需设备验收，但必须遵守用户授权。没有设备许可时不点击或自动化操作模拟器，明确保留视觉 / 交互未验证项。

交付时说明约束成因、保留的设计行为、已测 viewport 与状态、静态 / Widget 结果和设备验收缺口。分析或编译通过不能作为无溢出、动效正确的证明。
