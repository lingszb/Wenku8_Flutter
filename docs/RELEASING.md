# 当前 fork 的 Android 发布

本 fork 的开发、PR 门禁、Debug 测试包、独立证书、Tag 发布和回滚限制统一见 [CI/CD 项目管理说明](CI_CD.md)。

安装包从 [当前 fork 的 GitHub Releases](https://github.com/lingszb/Wenku8_Flutter/releases) 获取；Release 文件尚未发布时，请使用经过验证的 Actions Artifact，不将 Source code ZIP 当作 APK。

网站部署和上游专属签名 Action 已禁用。新 Android Release 工作流先验证与构建，再使用 fork 自己的证书签名；只有版本 Tag 事件公开发布，手动运行只生成验证产物。

许可证、NOTICE、assets/licenses/ 与第三方组件声明继续保留。本地源码构建和未实现功能边界见 [Android 源码构建说明](SOURCE_BUILD.md)。
