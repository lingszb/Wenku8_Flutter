# Android 自定义语音接口

本实现按公开协议自行实现，不包含上游未公开的原生连接组件。支持 Microsoft SSML REST 与 OpenAI Speech 兼容协议；用户已确认 OpenAI 指 `/v1/audio/speech`，不是 Chat Completions。

## 配置与使用

入口：我的 → 设置 → 阅读与外观 → 自定义语音接口，或听书面板 → 配置自定义语音接口。

- 选择 Microsoft SSML 或 OpenAI Speech，填写服务提供的**完整 HTTPS POST 地址**、音色 ID 与音色语言。
- Microsoft 支持无认证、Azure 订阅密钥（`Ocp-Apim-Subscription-Key`）、Bearer 令牌；发送转义后的 SSML，要求 `audio-24khz-48kbitrate-mono-mp3`。
- OpenAI Speech 支持无认证或 Bearer，必须手动填写服务当前可用的 `model` 和 `voice`；发送 `model`、`voice`、`input`、`response_format: mp3`，不发送聊天消息，也不自动尝试其他协议或服务。
- **试听接口**只发送页面固定试听句，暂停当前听书后播放合成结果；停止试听或离开页面会取消合成并停止播放。失败不会覆盖已保存的配置。
- **保存并使用**保存后选择该音色；如果当前听书正在播放，会按既有听书行为重新规划当前语段。保存本身不自动发送试听句。
- **移除接口**删除本机保存的配置与密钥，暂停听书并将已选择的自定义音源恢复为自然在线；不删除书籍、阅读位置或书签。

语音由 AI 生成。服务可能按提供方规则计费；只有用户主动试听或选择该音源听书时才会发送文本。第三方兼容服务必须实际支持所选协议、MP3 输出以及相应模型/音色，不能仅凭“OpenAI-compatible”名称推断所有参数都兼容。

## 请求与存储边界

- 仅 HTTPS，保留系统 TLS 证书校验；禁止 URL 内用户名/密码及片段，不自动跟随重定向，避免认证信息被转发。
- 连接超时 10 秒、单次完整合成最多 45 秒。取消会关闭本次 HTTP 客户端。请求文本最多 16 KiB UTF-8；OpenAI Speech 另限制 4096 个 Unicode 字符。响应最多 8 MiB，并检查响应类型与 MP3 文件头；JSON、网页、截断或超大响应不写入语音缓存。
- 错误只显示经过控制的 HTTP 状态说明，不回显服务响应、请求正文、URL 或密钥。
- 配置通过独立 MethodChannel 交由 `CustomSpeechVaultPlugin`，使用 Android Keystore 中的 AES 密钥和随机 IV 的 AES-GCM 加密。`custom_speech_secure.xml` 只保存密文；现有 Android cloud-backup/device-transfer 规则均排除此文件。
- 配置不会写入 Flutter SharedPreferences，也不会加入书籍/阅读记录备份或云同步。当前安全存储实现面向 Android；iOS/HarmonyOS 不声明已实现。
- 每次保存产生新的随机缓存 namespace，provider/model/endpoint/音色/认证变化不会误用旧声音，namespace 不包含密钥或密钥哈希。播放速率沿用播放器变速，不改变合成音频，不另行生成同一段音频。

## 官方协议与兼容性依据

- [上游公开阅读说明](https://github.com/mikufoxxx/Wenku8_Flutter/blob/master/docs/READER.md)：公开说明仅描述 Microsoft SSML 配置；公开 Git 树缺少实际 custom_tts 实现，issue #43 Windows 附件也是占位。
- [Microsoft Text to Speech REST](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-text-to-speech)：SSML、认证与输出格式。
- [OpenAI Create speech API](https://developers.openai.com/api/reference/resources/audio/subresources/speech/methods/create)：`input`、`model`、`voice` 与 `response_format`。
- [OpenAI Text to speech guide](https://developers.openai.com/api/docs/guides/text-to-speech)：二进制音频和 AI 语音披露。2026-11-06 查阅时，官方注明旧 Speech 模型将于 2027-01-06 停用；Realtime API 是不同协议，本次不自动迁移或将 Realtime 模型填进 `/audio/speech`。使用官方服务时须核对其最新可用模型；第三方服务以自身实际实现为准。

## 验证边界

协议回归通过注入本地假的 HTTP 客户端验证请求体、SSML 转义、认证、重定向、响应大小/类型、取消与超时，以及安全存储失败的保留行为。未使用真实密钥，未调用收费云服务，不把这些回归称为真实云端语音质量或厂商兼容验收。

Android 实机还需验证配置保存、重启读取、清除后安全存储状态，及真实服务试听/停止与后台听书；该层应和 Dart 测试、APK 构建结果分别记录。
