import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'support.dart';

void main() {
  test('解析设计链接与分支，拒绝无节点或伪造域名', () {
    expect(
      FigmaLink.parse(
        'https://www.figma.com/design/Main/branch/Branch/name?node-id=12-34',
      ).fileKey,
      'Branch',
    );
    expect(
      FigmaLink.parse('https://figma.com/design/Main?node-id=12%3A34').nodeId,
      '12:34',
    );
    for (final link in [
      'https://figma.com.evil/design/Main?node-id=1-2',
      'https://figma.com/design/Main',
      'file:///tmp/test',
    ]) {
      expect(() => FigmaLink.parse(link), throwsA(isA<SplashException>()));
    }
  });
  test('配置拒绝本地素材入口、路径越界和未知字段', () {
    expect(
      () => config(extra: 'source: local'),
      throwsA(isA<SplashException>()),
    );
    expect(
      () => config(extra: 'project:\n  ios_runner: ../outside'),
      throwsA(isA<SplashException>()),
    );
    expect(
      () => config(extra: 'platforms: [web]'),
      throwsA(isA<SplashException>()),
    );
  });
  test('同步固定同文件版本，素材下载不携带凭据', () async {
    var nodes = 0, downloads = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.figma.com') {
        expect(request.headers['X-Figma-Token'], 'test-secret');
        if (request.url.path.endsWith('/nodes')) {
          nodes++;
          if (nodes == 2) {
            expect(request.url.queryParameters['version'], 'v123');
          }
          final id = request.url.queryParameters['ids']!;
          Map<String, dynamic> rect(num x, num y, num w, num h) => {
            'x': x,
            'y': y,
            'width': w,
            'height': h,
          };
          final root = {
            'id': id,
            'type': 'FRAME',
            'absoluteBoundingBox': rect(0, 0, 375, 812),
            'children': [
              {
                'id': '2:1',
                'name': 'splash/background',
                'absoluteBoundingBox': rect(0, 0, 375, 812),
              },
              {
                'id': '2:2',
                'name': 'splash/foreground',
                'absoluteBoundingBox': rect(75, 200, 225, 200),
              },
              {
                'id': '2:3',
                'name': 'splash/branding',
                'absoluteBoundingBox': rect(100, 700, 150, 50),
              },
            ],
          };
          return http.Response(
            jsonEncode({
              'version': 'v123',
              'nodes': {
                id: {'document': root},
              },
            }),
            200,
          );
        }
        expect(request.url.queryParameters['version'], 'v123');
        return http.Response(
          jsonEncode({
            'images': {
              for (final id in request.url.queryParameters['ids']!.split(','))
                id: 'https://images.example.com/${id.replaceAll(':', '_')}.png',
            },
          }),
          200,
        );
      }
      expect(
        request.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('x-figma-token')),
      );
      downloads++;
      final file = request.url.pathSegments.last;
      final dimensions = switch (file) {
        '2_1.png' => [375, 812],
        '2_2.png' => [225, 200],
        '2_3.png' => [150, 50],
        _ => [375, 812],
      };
      return http.Response.bytes(png(dimensions[0], dimensions[1]), 200);
    });
    final snapshot = await FigmaClient(client, 'test-secret').fetch(config());
    expect(snapshot.frames.keys, containsAll(['phone', 'tablet']));
    expect(downloads, 8);
    expect(snapshot.metadata['sourceHash'], config().sourceHash);
  });
  test('限流错误清晰且不回显凭据或响应正文', () async {
    final client = MockClient(
      (_) async =>
          http.Response('secret-response', 429, headers: {'retry-after': '60'}),
    );
    await expectLater(
      FigmaClient(client, 'private-token').fetch(config()),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('限流'),
            isNot(contains('secret-response')),
            isNot(contains('private-token')),
          ),
        ),
      ),
    );
  });
  test('无凭据时不发起请求', () async {
    final client = MockClient((_) async => throw StateError('不应请求'));
    await expectLater(
      FigmaClient(client, '').fetch(config()),
      throwsA(isA<SplashException>()),
    );
  });
}
