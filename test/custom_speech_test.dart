import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/listening/custom_tts.dart';
import 'package:wenku8_flutter/listening/models.dart';

class _Headers extends Fake implements HttpHeaders {
  _Headers([this.contentType]);
  @override
  ContentType? contentType;
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name.toLowerCase()] = value;
}

class _Response extends Fake implements HttpClientResponse {
  _Response({
    this.statusCode = 200,
    String mime = 'audio/mpeg',
    List<int>? bytes,
    this.contentLength = -1,
  }) : headers = _Headers(ContentType.parse(mime)),
       stream = Stream.value(
         bytes ?? [0x49, 0x44, 0x33, ...List.filled(128, 0)],
       );
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  final _Headers headers;
  final Stream<List<int>> stream;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.response);
  final HttpClientResponse response;
  @override
  final _Headers headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  int contentLength = -1;
  final body = <int>[];
  @override
  void add(List<int> data) => body.addAll(data);
  @override
  Future<HttpClientResponse> close() async => response;
}

class _Client extends Fake implements HttpClient {
  _Client(this.request);
  final _Request request;
  Completer<HttpClientRequest>? pending;
  Uri? uri;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    uri = url;
    return pending == null ? request : pending!.future;
  }

  @override
  void close({bool force = false}) {
    closed = force;
  }
}

class _Storage implements CustomSpeechStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async {
    if (fail) throw PlatformException(code: 'unavailable');
    value = next;
  }
}

CustomSpeechConfig _config({
  CustomSpeechProtocol protocol = CustomSpeechProtocol.microsoftSsml,
  CustomSpeechAuthentication authentication = CustomSpeechAuthentication.bearer,
  String endpoint = 'https://speech.example/synthesize',
  String voice = 'zh-CN-XiaoxiaoNeural',
  String key = 'example-token',
}) => CustomSpeechConfig.create(
  voiceId: voice,
  locale: 'zh-CN',
  endpoint: endpoint,
  protocol: protocol,
  authentication: authentication,
  apiKey: key,
  model: 'tts-1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Microsoft sends escaped SSML and expected output/auth headers',
    () async {
      final request = _Request(_Response());
      final client = _Client(request);
      final audio = await CustomSpeechClient(clientFactory: () => client)
          .synthesize(
            '你好 & <世界>',
            _config(
              authentication: CustomSpeechAuthentication.azureKey,
              voice: 'voice"&',
            ),
            SpeechCancellation(),
          );
      expect(utf8.decode(request.body), contains('你好 &amp; &lt;世界&gt;'));
      expect(utf8.decode(request.body), contains('name="voice&quot;&amp;"'));
      expect(
        request.headers.values['ocp-apim-subscription-key'],
        'example-token',
      );
      expect(
        request.headers.values['x-microsoft-outputformat'],
        'audio-24khz-48kbitrate-mono-mp3',
      );
      expect(request.followRedirects, isFalse);
      expect(audio, isA<Uint8List>());
      expect(client.closed, isTrue);
    },
  );

  test(
    'OpenAI Speech sends model voice input and mp3 without SSML headers',
    () async {
      final request = _Request(_Response(mime: 'application/octet-stream'));
      final client = _Client(request);
      await CustomSpeechClient(clientFactory: () => client).synthesize(
        '本地书籍正文',
        _config(
          protocol: CustomSpeechProtocol.openAiSpeech,
          voice: 'alloy',
          endpoint: 'https://speech.example/v1/audio/speech',
        ),
        SpeechCancellation(),
      );
      expect(jsonDecode(utf8.decode(request.body)), {
        'model': 'tts-1',
        'voice': 'alloy',
        'input': '本地书籍正文',
        'response_format': 'mp3',
      });
      expect(request.headers.values['authorization'], 'Bearer example-token');
      expect(
        request.headers.values.containsKey('x-microsoft-outputformat'),
        isFalse,
      );
      expect(client.uri!.path, '/v1/audio/speech');
    },
  );

  test(
    'HTTPS and credential/locale validation reject unsafe configuration',
    () {
      for (final endpoint in [
        'http://speech.example/tts',
        'https://user:password@speech.example/tts',
        'https://speech.example/tts#fragment',
      ]) {
        expect(
          () => _config(endpoint: endpoint),
          throwsA(isA<SpeechFailure>()),
        );
      }
      expect(() => _config(key: 'line\nbreak'), throwsA(isA<SpeechFailure>()));
      expect(() => _config(key: ''), throwsA(isA<SpeechFailure>()));
    },
  );

  test(
    'no-auth config sends no secret and persisted record drops unused key',
    () async {
      final config = _config(authentication: CustomSpeechAuthentication.none);
      final request = _Request(_Response());
      await CustomSpeechClient(
        clientFactory: () => _Client(request),
      ).synthesize('测试', config, SpeechCancellation());
      expect(request.headers.values.containsKey('authorization'), isFalse);
      expect(config.toJson()['apiKey'], isEmpty);
    },
  );

  test('redirect/auth errors are sanitized and never followed', () async {
    for (final status in [302, 401, 403, 429, 500]) {
      final request = _Request(_Response(statusCode: status));
      try {
        await CustomSpeechClient(
          clientFactory: () => _Client(request),
        ).synthesize('测试', _config(), SpeechCancellation());
        fail('HTTP error must fail synthesis');
      } on SpeechFailure catch (error) {
        expect(error.message, isNot(contains('example-token')));
        expect(error.message, isNot(contains('speech.example')));
      }
      expect(request.followRedirects, isFalse);
    }
  });

  test(
    'JSON, forged MIME, truncated and oversized audio are rejected',
    () async {
      final responses = [
        _Response(
          mime: 'application/json',
          bytes: utf8.encode('{"audio":"no"}'),
        ),
        _Response(bytes: utf8.encode('{"error":"not an audio file"}')),
        _Response(bytes: [0x49, 0x44, 0x33]),
        _Response(contentLength: CustomSpeechClient.maximumAudioBytes + 1),
        _Response(
          bytes: List.filled(CustomSpeechClient.maximumAudioBytes + 1, 0),
        ),
      ];
      for (final response in responses) {
        await expectLater(
          CustomSpeechClient(
            clientFactory: () => _Client(_Request(response)),
          ).synthesize('测试', _config(), SpeechCancellation()),
          throwsA(isA<SpeechFailure>()),
        );
      }
    },
  );

  test(
    'explicit cancellation ends a pending connection and closes client',
    () async {
      final client = _Client(_Request(_Response()))
        ..pending = Completer<HttpClientRequest>();
      final cancellation = SpeechCancellation();
      final future = CustomSpeechClient(
        clientFactory: () => client,
      ).synthesize('测试', _config(), cancellation);
      final expectation = expectLater(future, throwsA(isA<SpeechCancelled>()));
      cancellation.cancel();
      await expectation;
      expect(client.closed, isTrue);
    },
  );

  test('OpenAI text limit is checked before sending a request', () async {
    await expectLater(
      CustomSpeechClient(
        clientFactory: () => throw StateError('must not connect'),
      ).synthesize(
        '文' * 4097,
        _config(protocol: CustomSpeechProtocol.openAiSpeech),
        SpeechCancellation(),
      ),
      throwsA(
        isA<SpeechFailure>().having(
          (e) => e.kind,
          'kind',
          SpeechFailureKind.content,
        ),
      ),
    );
  });

  test('total timeout closes a stalled request with typed failure', () async {
    final client = _Client(_Request(_Response()))
      ..pending = Completer<HttpClientRequest>();
    await expectLater(
      CustomSpeechClient(
        clientFactory: () => client,
        timeout: const Duration(milliseconds: 30),
      ).synthesize('测试', _config(), SpeechCancellation()),
      throwsA(
        isA<SpeechFailure>().having(
          (e) => e.kind,
          'kind',
          SpeechFailureKind.timeout,
        ),
      ),
    );
    expect(client.closed, isTrue);
  });

  test(
    'save/load uses secure storage and a failed write retains previous config',
    () async {
      final storage = _Storage();
      final settings = CustomSpeechSettings(storage: storage);
      final first = _config();
      await settings.save(first);
      final restored = CustomSpeechSettings(storage: storage);
      await restored.load();
      expect(restored.config!.apiKey, first.apiKey);
      expect(restored.config!.namespace, first.namespace);
      storage.fail = true;
      await expectLater(
        settings.save(_config()),
        throwsA(isA<SpeechFailure>()),
      );
      expect(settings.config, same(first));
      storage.fail = false;
      await settings.save(null);
      expect(settings.config, isNull);
      expect(storage.value, isNull);
      settings.dispose();
      restored.dispose();
    },
  );

  test(
    'each changed configuration has a distinct cache namespace without secret',
    () {
      final first = _config();
      final second = _config();
      expect(first.namespace, isNot(second.namespace));
      expect(first.voice.toJson().toString(), isNot(contains(first.apiKey)));
    },
  );
}
