// Minimal source-snapshot implementation adapted from upstream issue #43.
import 'package:flutter/material.dart';

import 'controller.dart';
import 'custom_tts.dart';

/// Desktop placeholder for the custom TTS endpoint editor.
///
/// Listening is disabled by [LocalPlatform.listening] on Windows, so this page
/// is never reachable from the normal UI. It stays present so the shared
/// settings widget compiles for every platform.
class CustomSpeechPage extends StatelessWidget {
  const CustomSpeechPage({
    super.key,
    required this.settings,
    required this.controller,
  });

  final CustomSpeechSettings settings;
  final ListeningController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('自定义语音接口')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          settings.config == null ? '当前源码版本暂不支持自定义语音接口。' : '已保存的语音配置仅可在移动端使用。',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
