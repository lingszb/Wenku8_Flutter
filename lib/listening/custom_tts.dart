import 'package:flutter/foundation.dart';
import 'models.dart';

/// The custom provider is absent from the public snapshot. Do not persist keys
/// or claim to configure a provider until a real implementation is available.
@immutable
class CustomSpeechConfig {
  const CustomSpeechConfig({
    required this.namespace,
    required this.voiceId,
    required this.locale,
    required this.voice,
    this.endpoint = '',
    this.apiKey = '',
  });
  final String namespace, voiceId, locale, endpoint, apiKey;
  final SpeechVoice voice;
}

class CustomSpeechSettings extends ChangeNotifier {
  CustomSpeechConfig? get config => null;
  Future<void> load() async {}
  Future<void> save(CustomSpeechConfig? config) async {
    if (config != null) {
      throw const SpeechFailure('当前源码版本暂不支持自定义语音接口');
    }
  }
}

class CustomSpeechClient {
  const CustomSpeechClient();
  Future<Uint8List> synthesize(
    String text,
    CustomSpeechConfig config,
    SpeechCancellation cancellation,
  ) async {
    cancellation.check();
    throw const SpeechFailure('当前源码版本暂不支持自定义语音接口');
  }
}
