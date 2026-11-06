import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

enum CustomSpeechProtocol { microsoftSsml, openAiSpeech }

enum CustomSpeechAuthentication { none, azureKey, bearer }

@immutable
class CustomSpeechConfig {
  const CustomSpeechConfig({
    required this.namespace,
    required this.voiceId,
    required this.locale,
    required this.endpoint,
    this.protocol = CustomSpeechProtocol.microsoftSsml,
    this.authentication = CustomSpeechAuthentication.none,
    this.apiKey = '',
    this.model = '',
  });

  factory CustomSpeechConfig.create({
    required String voiceId,
    required String locale,
    required String endpoint,
    CustomSpeechProtocol protocol = CustomSpeechProtocol.microsoftSsml,
    CustomSpeechAuthentication authentication = CustomSpeechAuthentication.none,
    String apiKey = '',
    String model = '',
  }) {
    final random = Random.secure();
    return CustomSpeechConfig(
      namespace:
          'custom:${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
      voiceId: voiceId.trim(),
      locale: locale.trim(),
      endpoint: endpoint.trim(),
      protocol: protocol,
      authentication: authentication,
      apiKey: apiKey.trim(),
      model: model.trim(),
    )..validate();
  }

  final String namespace, voiceId, locale, endpoint, apiKey, model;
  final CustomSpeechProtocol protocol;
  final CustomSpeechAuthentication authentication;

  SpeechVoice get voice => SpeechVoice(
    id: voiceId,
    label: voiceId,
    locale: locale,
    source: ListeningSource.custom,
    engine: namespace,
  );

  void validate() {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        endpoint.length > 4096) {
      throw const SpeechFailure('请输入完整的 HTTPS 语音合成地址，不含用户名、密码或片段');
    }
    if (!RegExp(r'^custom:[a-f0-9]{32}$').hasMatch(namespace) ||
        voiceId.trim().isEmpty ||
        voiceId.length > 256 ||
        locale.length > 64 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(voiceId) ||
        !RegExp(r'^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$').hasMatch(locale)) {
      throw const SpeechFailure('请填写有效的音色 ID 和语言，例如 zh-CN');
    }
    if (apiKey.length > 8192 ||
        RegExp(r'[\r\n\x00]').hasMatch(apiKey) ||
        (authentication != CustomSpeechAuthentication.none &&
            apiKey.trim().isEmpty)) {
      throw const SpeechFailure('请选择认证方式并填写有效密钥或令牌');
    }
    if (protocol == CustomSpeechProtocol.openAiSpeech &&
        (model.trim().isEmpty ||
            model.length > 256 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(model) ||
            authentication == CustomSpeechAuthentication.azureKey)) {
      throw const SpeechFailure('请填写语音模型，并选择 Bearer 或无认证');
    }
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'namespace': namespace,
    'voiceId': voiceId,
    'locale': locale,
    'endpoint': endpoint,
    'protocol': protocol.name,
    'model': model,
    'authentication': authentication.name,
    'apiKey': authentication == CustomSpeechAuthentication.none ? '' : apiKey,
  };

  factory CustomSpeechConfig.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        ![
          'namespace',
          'voiceId',
          'locale',
          'endpoint',
          'protocol',
          'model',
          'authentication',
          'apiKey',
        ].every((key) => raw[key] is String)) {
      throw const SpeechFailure('已保存的语音配置格式有误，请重新配置');
    }
    final auth = CustomSpeechAuthentication.values.where(
      (v) => v.name == raw['authentication'],
    );
    final protocol = CustomSpeechProtocol.values.where(
      (v) => v.name == raw['protocol'],
    );
    if (auth.isEmpty || protocol.isEmpty) {
      throw const SpeechFailure('已保存的语音接口类型不受支持');
    }
    return CustomSpeechConfig(
      namespace: raw['namespace'],
      voiceId: raw['voiceId'],
      locale: raw['locale'],
      endpoint: raw['endpoint'],
      protocol: protocol.single,
      model: raw['model'],
      authentication: auth.single,
      apiKey: raw['apiKey'],
    )..validate();
  }
}

abstract interface class CustomSpeechStorage {
  Future<String?> read();
  Future<void> write(String? value);
}

class AndroidCustomSpeechStorage implements CustomSpeechStorage {
  static const channel = MethodChannel('org.mewx.wenku8/custom_speech_config');
  @override
  Future<String?> read() => channel.invokeMethod<String>('read');
  @override
  Future<void> write(String? value) =>
      channel.invokeMethod<void>('write', value);
}

class CustomSpeechSettings extends ChangeNotifier {
  CustomSpeechSettings({CustomSpeechStorage? storage})
    : storage = storage ?? AndroidCustomSpeechStorage();
  final CustomSpeechStorage storage;
  CustomSpeechConfig? _config;
  CustomSpeechConfig? get config => _config;
  String? error;
  Future<void> _writes = Future.value();

  Future<void> load() async {
    try {
      await _writes;
      final raw = await storage.read();
      _config = raw == null
          ? null
          : CustomSpeechConfig.fromJson(jsonDecode(raw));
      error = null;
    } catch (_) {
      error = '本机语音配置暂时无法读取，请重新进入设置后重试；未删除已保存配置';
    }
    notifyListeners();
  }

  Future<void> save(CustomSpeechConfig? config) {
    config?.validate();
    final next = _writes.then((_) async {
      try {
        await storage.write(
          config == null ? null : jsonEncode(config.toJson()),
        );
      } catch (_) {
        throw const SpeechFailure('语音配置未保存，请检查本机安全存储后重试');
      }
      _config = config;
      error = null;
      notifyListeners();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}

class CustomSpeechClient {
  const CustomSpeechClient({
    this.clientFactory,
    this.timeout = const Duration(seconds: 45),
  });
  final HttpClient Function()? clientFactory;
  final Duration timeout;
  static const maximumAudioBytes = 8 * 1024 * 1024;

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  Future<Uint8List> synthesize(
    String text,
    CustomSpeechConfig config,
    SpeechCancellation cancellation,
  ) async {
    cancellation.check();
    config.validate();
    text = speechText(text);
    if (!hasSpeechText(text) ||
        utf8.encode(text).length > 16384 ||
        (config.protocol == CustomSpeechProtocol.openAiSpeech &&
            text.runes.length > 4096)) {
      throw const SpeechFailure(
        '语音文本为空或过长，请选择较短语段',
        kind: SpeechFailureKind.content,
      );
    }
    final client = (clientFactory?.call() ?? HttpClient())
      ..connectionTimeout = const Duration(seconds: 10);
    final remove = cancellation.onCancel(() => client.close(force: true));
    try {
      return await cancellation
          .wait(_request(client, text, config, cancellation))
          .timeout(timeout);
    } on SpeechCancelled {
      rethrow;
    } on SpeechFailure {
      rethrow;
    } on TimeoutException {
      throw const SpeechFailure(
        '自定义语音接口响应超时，请稍后重试',
        kind: SpeechFailureKind.timeout,
      );
    } catch (_) {
      cancellation.check();
      throw const SpeechFailure('自定义语音连接失败，请检查地址、证书和网络');
    } finally {
      remove();
      client.close(force: true);
    }
  }

  Future<Uint8List> _request(
    HttpClient client,
    String text,
    CustomSpeechConfig config,
    SpeechCancellation cancellation,
  ) async {
    final request = await client.postUrl(Uri.parse(config.endpoint));
    cancellation.check();
    request.followRedirects = false;
    final microsoft = config.protocol == CustomSpeechProtocol.microsoftSsml;
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      microsoft
          ? 'application/ssml+xml; charset=utf-8'
          : 'application/json; charset=utf-8',
    );
    if (microsoft) {
      request.headers.set(
        'X-Microsoft-OutputFormat',
        'audio-24khz-48kbitrate-mono-mp3',
      );
    }
    if (config.authentication == CustomSpeechAuthentication.azureKey) {
      request.headers.set('Ocp-Apim-Subscription-Key', config.apiKey);
    } else if (config.authentication == CustomSpeechAuthentication.bearer) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey}',
      );
    }
    final body = utf8.encode(
      microsoft
          ? '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
                'xml:lang="${_xml(config.locale)}"><voice name="${_xml(config.voiceId)}">${_xml(text)}</voice></speak>'
          : jsonEncode({
              'model': config.model,
              'voice': config.voiceId,
              'input': text,
              'response_format': 'mp3',
            }),
    );
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close();
    cancellation.check();
    if (response.statusCode != HttpStatus.ok) {
      throw SpeechFailure(switch (response.statusCode) {
        401 || 403 => '语音接口认证失败，请检查密钥、令牌和权限',
        429 => '语音接口请求过于频繁，请稍后重试',
        >= 300 && < 400 => '语音地址发生重定向，请填写最终 HTTPS 合成地址',
        _ => '语音接口返回错误（HTTP ${response.statusCode}），请检查配置',
      });
    }
    final contentType = response.headers.contentType?.mimeType;
    if (contentType != 'audio/mpeg' &&
        contentType != 'audio/mp3' &&
        contentType != 'application/octet-stream') {
      throw const SpeechFailure('语音接口没有返回 MP3 音频，请检查输出格式');
    }
    if (response.contentLength > maximumAudioBytes) {
      throw const SpeechFailure('单段语音超过大小限制');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      cancellation.check();
      if (bytes.length + chunk.length > maximumAudioBytes) {
        throw const SpeechFailure('单段语音超过大小限制');
      }
      bytes.add(chunk);
    }
    final audio = bytes.takeBytes();
    final id3 =
        audio.length >= 3 &&
        audio[0] == 0x49 &&
        audio[1] == 0x44 &&
        audio[2] == 0x33;
    final frame =
        audio.length >= 2 && audio[0] == 0xff && (audio[1] & 0xe0) == 0xe0;
    if (audio.length <= 100 || (!id3 && !frame)) {
      throw const SpeechFailure('语音接口返回的音频无效或不完整');
    }
    return audio;
  }
}
