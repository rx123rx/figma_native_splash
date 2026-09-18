import 'dart:convert';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'icon_support.dart';
import 'support.dart';

const sections = '''icon:
  figma: https://figma.com/design/Example?node-id=1-2
splash:
  figma:
    phone: https://figma.com/design/Example?node-id=1-2
''';

void main() {
  test('两种功能共用配置 Token，空值可供离线命令解析', () {
    for (final prefix in ['', 'figma_access_token: ""\n']) {
      expect(SplashConfig.parse('$prefix$sections').frames, isNotEmpty);
      expect(IconConfig.parse('$prefix$sections').frame.link.nodeId, '1:2');
    }
    final text = 'figma_access_token: "  yaml-secret  "\n$sections';
    expect(SplashConfig.parse(text).accessToken, 'yaml-secret');
    expect(IconConfig.parse(text).accessToken, 'yaml-secret');
  });

  test('非空环境变量优先，空白环境变量回退配置，两者缺失报错', () {
    expect(
      resolveFigmaAccessToken(
        'yaml-secret',
        environment: {'FIGMA_ACCESS_TOKEN': '  env-secret  '},
      ),
      'env-secret',
    );
    for (final env in <Map<String, String>>[
      {},
      {'FIGMA_ACCESS_TOKEN': '  '},
    ]) {
      expect(
        resolveFigmaAccessToken(' yaml-secret ', environment: env),
        'yaml-secret',
      );
      for (final token in [null, '', '  ']) {
        expect(
          () => resolveFigmaAccessToken(token, environment: env),
          throwsA(isA<SplashException>()),
        );
      }
    }
  });

  test('拒绝 Token 类型错误，YAML 错误不回显原文凭据', () {
    for (final value in ['null', '123', 'true', '[]', '{}']) {
      for (final parse in [SplashConfig.parse, IconConfig.parse]) {
        expect(
          () => parse('figma_access_token: $value\n$sections'),
          throwsA(isA<SplashException>()),
        );
      }
    }
    for (final parse in [SplashConfig.parse, IconConfig.parse]) {
      expect(
        () => parse(
          'figma_access_token: "secret-never-print" trailing\n$sections',
        ),
        throwsA(
          isA<SplashException>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('secret-never-print')),
          ),
        ),
      );
    }
  });

  test('Token 不改变来源哈希，也不会写入两种快照', () {
    final text = 'figma_access_token: "yaml-secret"\n$sections';
    final splash = SplashConfig.parse(text), icon = IconConfig.parse(text);
    expect(splash.sourceHash, SplashConfig.parse(sections).sourceHash);
    expect(icon.sourceHash, IconConfig.parse(sections).sourceHash);
    for (final files in [fixture(splash).files(), iconFixture(icon).files()]) {
      for (final entry in files.entries.where((e) => e.key.endsWith('.json'))) {
        expect(utf8.decode(entry.value), isNot(contains('yaml-secret')));
        expect(utf8.decode(entry.value), isNot(contains('figma_access_token')));
      }
    }
  });

  test('配置 Token 用于两种 Figma 同步请求，认证错误不打印凭据', () async {
    final text = 'figma_access_token: "yaml-secret"\n$sections';
    final splash = SplashConfig.parse(text), icon = IconConfig.parse(text);
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.headers['X-Figma-Token'], 'yaml-secret');
      return http.Response('yaml-secret', 403);
    });
    addTearDown(client.close);
    final failure = throwsA(
      isA<SplashException>().having(
        (e) => e.toString(),
        'message',
        isNot(contains('yaml-secret')),
      ),
    );
    await expectLater(
      FigmaClient(
        client,
        resolveFigmaAccessToken(splash.accessToken, environment: {}),
      ).fetch(splash),
      failure,
    );
    await expectLater(
      fetchIcon(
        FigmaClient(
          client,
          resolveFigmaAccessToken(icon.accessToken, environment: {}),
        ),
        icon,
      ),
      failure,
    );
    expect(requests, 2);
  });
}
