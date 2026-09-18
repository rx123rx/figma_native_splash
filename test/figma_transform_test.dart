import 'dart:convert';
import 'dart:math' as math;

import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  Future<DesignSnapshot> fetch({
    double rotation = math.pi,
    double backgroundX = 0,
    bool wrongAspect = false,
  }) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/nodes')) {
        Map<String, num> bounds(num x, num y, num w, num h) => {
          'x': 1000 + x,
          'y': 2000 + y,
          'width': w,
          'height': h,
        };
        return http.Response(
          jsonEncode({
            'version': 'v1',
            'nodes': {
              '1:2': {
                'document': {
                  'type': 'FRAME',
                  'absoluteBoundingBox': bounds(0, 0, 375, 812),
                  'children': [
                    {
                      'id': '2:1', 'name': 'splash/background',
                      'rotation': rotation,
                      // Horizontal reflection can also carry a nonzero rotation.
                      'relativeTransform': [
                        [-1, 0, 375],
                        [0, 1, 0],
                      ],
                      'absoluteBoundingBox': bounds(backgroundX, 0, 375, 812),
                    },
                    {
                      'id': '2:2',
                      'name': 'splash/foreground',
                      'rotation': math.pi / 2,
                      'size': {'x': 200, 'y': 225},
                      'absoluteBoundingBox': bounds(75, 200, 225, 200),
                    },
                    {
                      'id': '2:3',
                      'name': 'splash/branding',
                      'absoluteBoundingBox': bounds(100, 700, 150, 50),
                    },
                  ],
                },
              },
            },
          }),
          200,
        );
      }
      if (request.url.host == 'api.figma.com') {
        expect(request.url.queryParameters['use_absolute_bounds'], 'true');
        return http.Response(
          jsonEncode({
            'images': {
              for (final id in request.url.queryParameters['ids']!.split(','))
                id: 'https://images.example.com/$id',
            },
          }),
          200,
        );
      }
      final dimensions = switch (request.url.pathSegments.last) {
        '2:2' => wrongAspect ? [200, 225] : [225, 200],
        '2:3' => [150, 50],
        _ => [375, 812],
      };
      return http.Response.bytes(png(dimensions[0], dimensions[1]), 200);
    });
    try {
      return await FigmaClient(
        client,
        'test-token',
      ).fetch(config(tablet: false));
    } finally {
      client.close();
    }
  }

  test('镜像背景和旋转前景按绝对边界布局，原样保留已导出的图片', () async {
    final snapshot = await fetch();
    final layers = snapshot.frames['phone']!.layers;
    expect(layers['background']!.rect.toJson(), {
      'x': 0.0,
      'y': 0.0,
      'width': 375.0,
      'height': 812.0,
    });
    expect(layers['foreground']!.rect.toJson(), {
      'x': 75.0,
      'y': 200.0,
      'width': 225.0,
      'height': 200.0,
    });
    expect(
      snapshot.assets['phone/foreground.png'],
      orderedEquals(png(225, 200)),
    );
  });

  test('变换后的背景没有覆盖画板时仍拒绝同步', () async {
    await expectLater(
      fetch(backgroundX: 20),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('覆盖完整画板'),
        ),
      ),
    );
  });

  test('导出图片比例不匹配变换后的边界时仍拒绝同步', () async {
    await expectLater(
      fetch(wrongAspect: true),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('导出图片比例与图层不一致'),
        ),
      ),
    );
  });
}
