import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../app_ui.dart';
import '../feature_pages.dart';
import 'controller.dart';
import 'custom_tts.dart';
import 'models.dart';

class CustomSpeechPage extends StatefulWidget {
  const CustomSpeechPage({
    super.key,
    required this.settings,
    required this.controller,
  });
  final CustomSpeechSettings settings;
  final ListeningController controller;
  @override
  State<CustomSpeechPage> createState() => _CustomSpeechPageState();
}

class _CustomSpeechPageState extends State<CustomSpeechPage> {
  late final _endpoint = TextEditingController(
    text: widget.settings.config?.endpoint ?? '',
  );
  late final _voice = TextEditingController(
    text: widget.settings.config?.voiceId ?? 'zh-CN-XiaoxiaoNeural',
  );
  late final _locale = TextEditingController(
    text: widget.settings.config?.locale ?? 'zh-CN',
  );
  late final _key = TextEditingController(
    text: widget.settings.config?.apiKey ?? '',
  );
  late final _model = TextEditingController(
    text: widget.settings.config?.model.isNotEmpty == true
        ? widget.settings.config!.model
        : '',
  );
  late CustomSpeechProtocol _protocol =
      widget.settings.config?.protocol ?? CustomSpeechProtocol.microsoftSsml;
  late CustomSpeechAuthentication _authentication =
      widget.settings.config?.authentication ?? CustomSpeechAuthentication.none;
  final _player = AudioPlayer();
  SpeechCancellation? _previewCancellation;
  bool _previewing = false, _saving = false, _disposed = false;
  int _previewEpoch = 0;
  String? _error;

  Future<void> _reloadConfiguration() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.settings.load();
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (widget.settings.error != null) return;
      final config = widget.settings.config;
      _endpoint.text = config?.endpoint ?? '';
      _voice.text = config?.voiceId ?? 'zh-CN-XiaoxiaoNeural';
      _locale.text = config?.locale ?? 'zh-CN';
      _key.text = config?.apiKey ?? '';
      _model.text = config?.model ?? '';
      _protocol = config?.protocol ?? CustomSpeechProtocol.microsoftSsml;
      _authentication =
          config?.authentication ?? CustomSpeechAuthentication.none;
    });
  }

  CustomSpeechConfig _configuration() => CustomSpeechConfig.create(
    endpoint: _endpoint.text,
    voiceId: _voice.text,
    locale: _locale.text,
    protocol: _protocol,
    authentication: _authentication,
    apiKey: _key.text,
    model: _protocol == CustomSpeechProtocol.openAiSpeech ? _model.text : '',
  );

  Future<bool> _stopPreview() async {
    ++_previewEpoch;
    _previewCancellation?.cancel();
    _previewCancellation = null;
    var stopped = true;
    try {
      await _player.stop();
    } catch (_) {
      stopped = false;
      if (mounted && !_disposed) setState(() => _error = '试听停止未完成，请离开此页面后重试');
    }
    if (mounted && !_disposed) setState(() => _previewing = false);
    return stopped;
  }

  Future<void> _preview() async {
    final epoch = ++_previewEpoch;
    final cancellation = SpeechCancellation();
    _previewCancellation = cancellation;
    Directory? temporary;
    setState(() {
      _previewing = true;
      _error = null;
    });
    try {
      final config = _configuration();
      await widget.controller.pause();
      cancellation.check();
      final bytes = await const CustomSpeechClient().synthesize(
        '这是自定义语音接口试听。语音由人工智能生成。',
        config,
        cancellation,
      );
      cancellation.check();
      temporary = await (await getTemporaryDirectory()).createTemp(
        'custom-speech-preview-',
      );
      final file = File('${temporary.path}/preview.mp3');
      await file.writeAsBytes(bytes, flush: true);
      cancellation.check();
      await _player.setFilePath(file.path);
      cancellation.check();
      await _player.play();
    } on SpeechCancelled {
      // Leaving the page or explicit stop owns cancellation, not a failure banner.
    } catch (error) {
      if (mounted && !_disposed && epoch == _previewEpoch) {
        setState(
          () => _error = error is SpeechFailure
              ? error.message
              : '试听未完成，请检查接口配置或稍后重试',
        );
      }
    } finally {
      if (epoch == _previewEpoch) await _stopPreview();
      if (temporary != null && await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    bool saved = false;
    try {
      final config = _configuration();
      if (!await _stopPreview()) return;
      await widget.settings.save(config);
      saved = true;
      await widget.controller.setVoice(config.voice);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = saved
              ? '配置已保存，音色切换未完成；可在听书面板重新选择自定义音源'
              : error is SpeechFailure
              ? error.message
              : '配置未保存，请稍后重试',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    if (!await confirmNovelAction(
      context,
      title: '移除自定义语音接口？',
      message: '删除本机保存的接口与密钥，书籍、阅读进度和书签不受影响。',
      confirmLabel: '移除接口',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!await _stopPreview()) return;
      await widget.controller.pause();
      await widget.settings.save(null);
      if (widget.controller.snapshot.value.voice.source ==
          ListeningSource.custom) {
        await widget.controller.setVoice(defaultEdgeVoice);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is SpeechFailure ? error.message : '接口移除未完成，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_previewEpoch;
    _previewCancellation?.cancel();
    unawaited(_player.dispose().catchError((Object _) {}));
    for (final controller in [_endpoint, _voice, _locale, _key, _model]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: controller,
      enabled: !_saving && !_previewing,
      obscureText: secret,
      enableSuggestions: !secret,
      autocorrect: false,
      keyboardType: secret ? TextInputType.visiblePassword : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: ArchiveFeaturePage(
      title: '自定义语音接口',
      code: 'CUSTOM / SPEECH',
      canPop: !_saving,
      child: ListView(
        padding: featurePadding(context),
        children: [
          if (widget.settings.error != null)
            FeatureError(widget.settings.error),
          if (widget.settings.error != null)
            TextButton(
              onPressed: _saving || _previewing ? null : _reloadConfiguration,
              child: const AppText('重新读取已保存配置'),
            ),
          FeatureError(_error),
          ContentPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppControls.segments<CustomSpeechProtocol>(
                  context,
                  groupValue: _protocol,
                  children: const {
                    CustomSpeechProtocol.microsoftSsml: AppText(
                      'Microsoft SSML',
                      textAlign: TextAlign.center,
                    ),
                    CustomSpeechProtocol.openAiSpeech: AppText(
                      'OpenAI Speech',
                      textAlign: TextAlign.center,
                    ),
                  },
                  onValueChanged: (value) {
                    if (_saving || _previewing || value == null) return;
                    setState(() {
                      _protocol = value;
                      if (value == CustomSpeechProtocol.openAiSpeech) {
                        if (_voice.text == 'zh-CN-XiaoxiaoNeural') {
                          _voice.text = 'alloy';
                        }
                        if (_authentication ==
                            CustomSpeechAuthentication.azureKey) {
                          _authentication = CustomSpeechAuthentication.bearer;
                        }
                      } else if (_voice.text == 'alloy') {
                        _voice.text = 'zh-CN-XiaoxiaoNeural';
                      }
                    });
                  },
                ),
                const SizedBox(height: 18),
                _field(
                  '完整 HTTPS 合成地址',
                  _endpoint,
                  hint: _protocol == CustomSpeechProtocol.openAiSpeech
                      ? 'https://服务地址/v1/audio/speech'
                      : 'https://区域.tts.speech.microsoft.com/cognitiveservices/v1',
                ),
                if (_protocol == CustomSpeechProtocol.openAiSpeech)
                  _field('语音模型', _model, hint: '填写服务当前支持的模型 ID'),
                _field('音色 ID', _voice),
                _field('音色语言', _locale, hint: 'zh-CN'),
                const AppText(
                  '认证方式',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                AppControls.segments<CustomSpeechAuthentication>(
                  context,
                  groupValue: _authentication,
                  children: {
                    CustomSpeechAuthentication.none: const AppText(
                      '无认证',
                      textAlign: TextAlign.center,
                    ),
                    if (_protocol == CustomSpeechProtocol.microsoftSsml)
                      CustomSpeechAuthentication.azureKey: const AppText(
                        'Azure 密钥',
                        textAlign: TextAlign.center,
                      ),
                    CustomSpeechAuthentication.bearer: const AppText(
                      'Bearer',
                      textAlign: TextAlign.center,
                    ),
                  },
                  onValueChanged: (value) {
                    if (!_saving && !_previewing && value != null) {
                      setState(() => _authentication = value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                if (_authentication != CustomSpeechAuthentication.none)
                  _field('密钥或访问令牌', _key, secret: true),
                AppText(
                  _protocol == CustomSpeechProtocol.microsoftSsml
                      ? '按 Microsoft SSML 协议发送 POST，请求 MP3 音频。'
                      : '按 OpenAI /audio/speech 协议发送 model、voice 和 input，请求 MP3；不使用聊天接口。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppText(
            '仅在你点击试听或选择此音源听书时发送文本。语音由人工智能生成，服务可能计费；密钥通过 Android Keystore 加密保存在本机，不进入书籍备份与云同步。',
          ),
          const SizedBox(height: 18),
          GlassTextButton(
            key: const ValueKey('custom-speech-preview'),
            onPressed: _saving
                ? null
                : _previewing
                ? _stopPreview
                : _preview,
            child: AppText(_previewing ? '停止试听' : '试听接口'),
          ),
          const SizedBox(height: 12),
          GlassTextButton(
            key: const ValueKey('custom-speech-save'),
            onPressed: _saving ? null : _save,
            child: AppText(_saving ? '正在保存…' : '保存并使用'),
          ),
          if (widget.settings.config != null) ...[
            const SizedBox(height: 12),
            GlassTextButton(
              key: const ValueKey('custom-speech-remove'),
              onPressed: _saving ? null : _remove,
              child: const AppText('移除接口'),
            ),
          ],
        ],
      ),
    ),
  );
}
