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
    // mock 中手机和平板复用了同样的角色节点 ID，同一节点只下载一次。
    expect(downloads, 5);
    expect(snapshot.metadata['sourceHash'], config().sourceHash);
  });
  test('画板外素材可同时用于手机与平板，位置由配置决定', () async {
    Map<String, dynamic> rect(num x, num y, num w, num h) => {
      'x': x,
      'y': y,
      'width': w,
      'height': h,
    };
    final external = SplashConfig.parse(
      splashYaml('''
figma:
  phone:
    url: https://www.figma.com/design/Example?node-id=1-2
    nodes:
      background: "2:1"
      foreground: "2:2"
      branding:
        id: "9:9"
        x: 125
        y: 704
  tablet:
    url: https://www.figma.com/design/Example?node-id=1-3
    nodes:
      background: "3:1"
      foreground: "3:2"
      branding:
        id: "9:9"
        x: 353
        y: 454
'''),
    );
    var nodeRequests = 0, imageRequests = 0, downloads = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/nodes')) {
        nodeRequests++;
        final id = request.url.queryParameters['ids']!;
        if (id == '9:9') {
          expect(request.url.queryParameters['version'], 'v123');
          return http.Response(
            jsonEncode({
              'version': 'v123',
              'nodes': {
                '9:9': {
                  'document': {
                    'id': '9:9',
                    'type': 'GROUP',
                    'name': 'brand',
                    'visible': true,
                    'absoluteBoundingBox': rect(9000, 9000, 128, 58),
                  },
                },
              },
            }),
            200,
          );
        }
        final phone = id == '1:2';
        return http.Response(
          jsonEncode({
            'version': 'v123',
            'nodes': {
              id: {
                'document': {
                  'id': id,
                  'type': 'FRAME',
                  'absoluteBoundingBox': phone
                      ? rect(0, 0, 375, 812)
                      : rect(0, 0, 834, 1194),
                  'children': [
                    {
                      'id': phone ? '2:1' : '3:1',
                      'name': 'background',
                      'absoluteBoundingBox': phone
                          ? rect(0, 0, 375, 812)
                          : rect(0, 0, 834, 1194),
                    },
                    {
                      'id': phone ? '2:2' : '3:2',
                      'name': 'foreground',
                      'absoluteBoundingBox': rect(75, 200, 225, 200),
                    },
                  ],
                },
              },
            },
          }),
          200,
        );
      }
      if (request.url.path.contains('/images/')) {
        imageRequests++;
        final ids = request.url.queryParameters['ids']!.split(',');
        expect(ids, contains('9:9'));
        return http.Response(
          jsonEncode({
            'images': {
              for (final id in ids)
                id: 'https://images.example.com/${id.replaceAll(':', '_')}.png',
            },
          }),
          200,
        );
      }
      downloads++;
      final file = request.url.pathSegments.last;
      final dimensions = switch (file) {
        '1_2.png' || '2_1.png' => [375, 812],
        '1_3.png' || '3_1.png' => [834, 1194],
        '2_2.png' || '3_2.png' => [225, 200],
        '9_9.png' => [128, 58],
        _ => [1, 1],
      };
      return http.Response.bytes(png(dimensions[0], dimensions[1]), 200);
    });
    final snapshot = await FigmaClient(client, 'test-secret').fetch(external);
    expect(nodeRequests, 3); // 两个画板 + 一次画板外节点（手机/平板共用）
    expect(imageRequests, 2);
    expect(downloads, 7); // 画板外素材只下载一次，再写入两个角色路径
    final phoneBrand = snapshot.frames['phone']!.layers['branding']!;
    final tabletBrand = snapshot.frames['tablet']!.layers['branding']!;
    expect(phoneBrand.nodeId, '9:9');
    expect(tabletBrand.nodeId, '9:9');
    expect(phoneBrand.rect.toJson(), {
      'x': 125.0,
      'y': 704.0,
      'width': 128.0,
      'height': 58.0,
    });
    expect(tabletBrand.rect.toJson(), {
      'x': 353.0,
      'y': 454.0,
      'width': 128.0,
      'height': 58.0,
    });
    expect(
      snapshot.assets['phone/branding.png'],
      snapshot.assets['tablet/branding.png'],
    );
  });
  test('画板外素材缺少 x/y 或节点不存在时明确报错', () async {
    Map<String, dynamic> rect(num x, num y, num w, num h) => {
      'x': x,
      'y': y,
      'width': w,
      'height': h,
    };
    MockClient frameMock({required bool emptyExternal}) =>
        MockClient((request) async {
          if (request.url.path.endsWith('/nodes')) {
            final id = request.url.queryParameters['ids']!;
            return http.Response(
              jsonEncode({
                'version': 'v1',
                'nodes': id == '1:2'
                    ? {
                        '1:2': {
                          'document': {
                            'id': '1:2',
                            'type': 'FRAME',
                            'absoluteBoundingBox': rect(0, 0, 375, 812),
                            'children': [
                              {
                                'id': '2:1',
                                'name': 'background',
                                'absoluteBoundingBox': rect(0, 0, 375, 812),
                              },
                              {
                                'id': '2:2',
                                'name': 'foreground',
                                'absoluteBoundingBox': rect(75, 200, 225, 200),
                              },
                            ],
                          },
                        },
                      }
                    : emptyExternal
                    ? <String, dynamic>{}
                    : {
                        '9:9': {
                          'document': {
                            'id': '9:9',
                            'type': 'GROUP',
                            'visible': true,
                            'absoluteBoundingBox': rect(9000, 9000, 128, 58),
                          },
                        },
                      },
              }),
              200,
            );
          }
          throw StateError('不应请求图片');
        });
    final missingPosition = SplashConfig.parse(
      splashYaml('''
figma:
  phone:
    url: https://www.figma.com/design/Example?node-id=1-2
    nodes:
      background: "2:1"
      foreground: "2:2"
      branding: "9:9"
'''),
    );
    await expectLater(
      FigmaClient(
        frameMock(emptyExternal: false),
        'token',
      ).fetch(missingPosition),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('x、y'),
        ),
      ),
    );
    final missingNode = SplashConfig.parse(
      splashYaml('''
figma:
  phone:
    url: https://www.figma.com/design/Example?node-id=1-2
    nodes:
      background: "2:1"
      foreground: "2:2"
      branding:
        id: "9:9"
        x: 125
        y: 704
'''),
    );
    await expectLater(
      FigmaClient(frameMock(emptyExternal: true), 'token').fetch(missingNode),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('不存在'),
        ),
      ),
    );
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
