import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:figma_native_splash/src/icon_cli.dart';
import 'package:figma_native_splash/src/json5_edit.dart';
import 'support.dart';
import 'icon_support.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('figma-icon-test-'));
  tearDown(() {
    exitCode = 0;
    root.deleteSync(recursive: true);
  });
  test('仅图标不要求 phone，默认值独立且兼容共享 YAML', () {
    final minimal = IconConfig.parse(
      'figma:\n  icon: https://figma.com/design/Example?node-id=1-2',
    );
    expect(minimal.platforms, ['android', 'ios', 'ohos']);
    expect(minimal.prefix, 'figma_icon');
    expect(minimal.background, isNull);
    expect(minimal.adaptive, isTrue);
    expect(minimal.monochrome, isFalse);
    expect(minimal.shared.frames, isEmpty);
    expect(minimal.androidManifest, 'android/app/src/main/AndroidManifest.xml');
    expect(minimal.ohosAppScope, 'ohos/AppScope');
    expect(
      () => IconConfig.parse('figma: {}'),
      throwsA(isA<SplashException>()),
    );
    final shared = '''figma:
  phone: https://figma.com/design/Example?node-id=1-2
  icon: https://figma.com/design/Example?node-id=1-3
icon:
  platforms: [ios]
''';
    expect(SplashConfig.parse(shared).frames.keys, ['phone']);
    expect(IconConfig.parse(shared).platforms, ['ios']);
  });
  test('错误类型、空值、无效依赖组合和越界路径均拒绝', () {
    for (final content in [
      'platforms: []',
      'platforms: [web]',
      'platforms: null',
      'background_color: null',
      'background_color: "#FFF"',
      'resource_prefix: figma_splash',
      'resource_prefix: App.Icon',
      'android: {adaptive: false, monochrome: true}',
      'android: {adaptive: "true"}',
      'android: {monochrome: null}',
      'unknown: true',
    ]) {
      expect(
        () => IconConfig.parse(
          'figma:\n  icon: https://figma.com/design/Example?node-id=1-2\nicon:\n  $content',
        ),
        throwsA(isA<SplashException>()),
        reason: content,
      );
    }
    expect(
      () => IconConfig.parse(
        '${iconYaml()}project:\n  ohos_app_scope: ../outside',
      ),
      throwsA(isA<SplashException>()),
    );
    expect(
      () => IconConfig.parse('${iconYaml()}project:\n  android_manifest: null'),
      throwsA(isA<SplashException>()),
    );
  });
  test('三端图标接入、尺寸、透明通道、重复生成与 splash 隔离', () {
    iconProjectFixture(root);
    final c = IconConfig.parse(iconYaml(monochrome: true)),
        s = iconFixture(IconConfig.parse(iconYaml(monochrome: true)));
    final oldPlist = File(
      p.join(root.path, 'ios/Runner/Info.plist'),
    ).readAsStringSync();
    final plan = generateIcons(root, c, s);
    expect(plan.changes, contains('ios/Runner.xcodeproj/project.pbxproj'));
    expect(
      plan.writes.keys.any((key) => key.contains('figma_splash_')),
      isFalse,
    );
    plan.apply();
    expect(generateIcons(root, c, s).changes, isEmpty);
    final android = File(
      p.join(root.path, c.androidManifest),
    ).readAsStringSync();
    expect(android, contains('android:icon="@mipmap/figma_icon"'));
    expect(android, contains('android:roundIcon="@mipmap/figma_icon"'));
    expect(android, contains('android:icon="@drawable/keep"'));
    final ios = File(
      p.join(root.path, 'ios/Runner.xcodeproj/project.pbxproj'),
    ).readAsStringSync();
    expect(ios, contains('ASSETCATALOG_COMPILER_APPICON_NAME = "figma_icon"'));
    expect(
      ios,
      contains(
        '"ASSETCATALOG_COMPILER_APPICON_NAME[sdk=iphoneos*]" = "figma_icon"',
      ),
    );
    expect(ios, contains('DEVELOPMENT_TEAM = KEEP;'));
    expect(
      File(p.join(root.path, 'ios/Runner/Info.plist')).readAsStringSync(),
      oldPlist,
    );
    final image = img.decodePng(
      File(
        p.join(
          root.path,
          'ios/Runner/Assets.xcassets/figma_icon.appiconset/icon-1024.png',
        ),
      ).readAsBytesSync(),
    )!;
    expect(image.width, 1024);
    expect(image.numChannels, 3);
    expect(
      image.getPixel(512, 512).r,
      255,
    ); // only colored foreground; no helper overlay
    final entries =
        (jsonDecode(
                  File(
                    p.join(
                      root.path,
                      'ios/Runner/Assets.xcassets/figma_icon.appiconset/Contents.json',
                    ),
                  ).readAsStringSync(),
                )
                as Map)['images']
            as List;
    expect(
      entries.any(
        (e) =>
            e['idiom'] == 'ipad' &&
            e['size'] == '83.5x83.5' &&
            e['scale'] == '2x',
      ),
      isTrue,
    );
    final app = File(
      p.join(root.path, 'ohos/AppScope/app.json5'),
    ).readAsStringSync();
    expect(app, contains('// app comment'));
    expect(app, contains('\$media:figma_icon_app'));
    final module = File(
      p.join(root.path, 'ohos/entry/src/main/module.json5'),
    ).readAsStringSync();
    expect(module, contains('ohos.permission.INTERNET'));
    expect(module, contains('"startWindowIcon":"\$media:icon"'));
    expect(module, contains('"icon":"\$media:figma_icon"'));
  });
  test('图标开关往返清理已生成的 adaptive/monochrome，保护手改文件', () {
    iconProjectFixture(root);
    final on = IconConfig.parse(
      iconYaml(platforms: '[android]', monochrome: true),
    );
    generateIcons(root, on, iconFixture(on)).apply();
    final off = IconConfig.parse(
      iconYaml(platforms: '[android]', adaptive: false),
    );
    final plan = generateIcons(root, off, iconFixture(off));
    expect(
      plan.deletes,
      contains('android/app/src/main/res/mipmap-anydpi-v33/figma_icon.xml'),
    );
    plan.apply();
    expect(generateIcons(root, off, iconFixture(off)).changes, isEmpty);
    write(
      root,
      'android/app/src/main/res/mipmap-mdpi/figma_icon.png',
      'manual',
    );
    expect(
      () => generateIcons(root, off, iconFixture(off)),
      throwsA(isA<SplashException>()),
    );
  });
  test('透明底色必须明确，合成后不含 alpha；单色图保留透明轮廓', () {
    final image = img.Image(width: 1024, height: 1024, numChannels: 4);
    image.setPixelRgba(512, 512, 255, 0, 0, 255);
    expect(() => opaqueIcon(image, null), throwsA(isA<SplashException>()));
    final opaque = opaqueIcon(image, '#00FF00');
    expect(opaque.numChannels, 3);
    expect(opaque.getPixel(0, 0).g, 255);
    final mono = monochromeIcon(image);
    expect(mono.getPixel(0, 0).a, 0);
    expect(mono.getPixel(512, 512).r, 255);
    expect(() => monochromeIcon(opaque), throwsA(isA<SplashException>()));
  });
  test('快照校验、开关需重新同步，纯背景色变更不需同步', () {
    final c = IconConfig.parse(iconYaml()),
        s = iconFixture(IconConfig.parse(iconYaml()));
    saveIconSnapshot(root, s);
    expect(IconSnapshot.load(root, c).assets.keys, contains('icon.png'));
    final colored = IconConfig.parse(
      iconYaml().replaceFirst(
        '  android:',
        '  background_color: "#FFFFFF"\n  android:',
      ),
    );
    expect(colored.sourceHash, c.sourceHash);
    expect(
      IconConfig.parse(iconYaml(monochrome: true)).sourceHash,
      isNot(c.sourceHash),
    );
    File(
      p.join(root.path, iconSnapshotDirectory, 'icon.png'),
    ).writeAsBytesSync([0]);
    expect(() => IconSnapshot.load(root, c), throwsA(isA<SplashException>()));
  });
  test('任一平台失败不落盘，未选择的平台无需工程文件', () {
    iconProjectFixture(root);
    Directory(p.join(root.path, 'ohos')).deleteSync(recursive: true);
    final c = IconConfig.parse(iconYaml()),
        s = iconFixture(IconConfig.parse(iconYaml()));
    expect(() => generateIcons(root, c, s), throwsA(isA<SplashException>()));
    expect(
      File(
        p.join(
          root.path,
          'android/app/src/main/res/mipmap-mdpi/figma_icon.png',
        ),
      ).existsSync(),
      isFalse,
    );
    expect(
      () => generateIcons(root, c, s, platforms: ['android']).apply(),
      returnsNormally,
    );
  });
  test('JSON5 单引号、裸键和嵌套字段按正确层级修改', () {
    final text =
        "{ /* keep */ module: { abilities: [{name:'EntryAbility', metadata:[{name:'icon',value:'keep'}], icon:'old'}] } }";
    final ability = Json5Object.root(
      text,
    ).object('module').objects('abilities').single;
    final updated = ability.setString('icon', r'$media:generated');
    expect(updated, contains("metadata:[{name:'icon',value:'keep'}]"));
    expect(updated, contains('/* keep */'));
    expect(
      Json5Object.root(
        updated,
      ).object('module').objects('abilities').single.string('icon'),
      r'$media:generated',
    );
    expect(
      () => Json5Object.root('{icon:"a",icon:"b"}'),
      throwsA(isA<SplashException>()),
    );
  });
  test('Figma 同步固定版本、保留画板对齐，下载不发送 token', () async {
    final c = IconConfig.parse(iconYaml()),
        fixture = iconFixture(IconConfig.parse(iconYaml()));
    var downloads = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.figma.com') {
        expect(request.headers['X-Figma-Token'], 'secret');
        if (request.url.path.endsWith('/nodes')) {
          return http.Response(
            jsonEncode({
              'version': 'v1',
              'nodes': {
                '1:2': {
                  'document': {
                    'type': 'FRAME',
                    'absoluteBoundingBox': {
                      'x': 100,
                      'y': 200,
                      'width': 1024,
                      'height': 1024,
                    },
                    'children': [
                      for (final role in c.roles)
                        {
                          'id': role == 'background' ? '2:1' : '2:2',
                          'name': 'icon/$role',
                          'absoluteBoundingBox': {
                            'x': 100,
                            'y': 200,
                            'width': 1024,
                            'height': 1024,
                          },
                        },
                    ],
                  },
                },
              },
            }),
            200,
          );
        }
        expect(request.url.queryParameters['version'], 'v1');
        expect(request.url.queryParameters['scale'], '1.0');
        return http.Response(
          jsonEncode({
            'images': {
              '1:2': 'https://images.example/icon.png',
              '2:1': 'https://images.example/background.png',
              '2:2': 'https://images.example/foreground.png',
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
      return http.Response.bytes(
        fixture.assets[request.url.pathSegments.last]!,
        200,
      );
    });
    final snapshot = await fetchIcon(FigmaClient(client, 'secret'), c);
    client.close();
    expect(downloads, 3);
    expect(snapshot.metadata['sourceHash'], c.sourceHash);
    expect(snapshot.image('foreground').width, 1024);
  });
  test('Figma 错位、隐藏图层、非正方形画板和缺少凭据均拒绝', () async {
    final c = IconConfig.parse(iconYaml());
    for (final scenario in ['offset', 'hidden', 'rectangle']) {
      final client = MockClient((request) async {
        expect(request.url.path.endsWith('/nodes'), isTrue);
        return http.Response(
          jsonEncode({
            'version': 'v1',
            'nodes': {
              '1:2': {
                'document': {
                  'type': 'FRAME',
                  'absoluteBoundingBox': {
                    'x': 0,
                    'y': 0,
                    'width': scenario == 'rectangle' ? 512 : 1024,
                    'height': 1024,
                  },
                  'children': [
                    {
                      'id': '2:1',
                      'name': 'icon/background',
                      'visible': scenario != 'hidden',
                      'absoluteBoundingBox': {
                        'x': scenario == 'offset' ? 10 : 0,
                        'y': 0,
                        'width': 1024,
                        'height': 1024,
                      },
                    },
                    {
                      'id': '2:2',
                      'name': 'icon/foreground',
                      'absoluteBoundingBox': {
                        'x': 0,
                        'y': 0,
                        'width': 1024,
                        'height': 1024,
                      },
                    },
                  ],
                },
              },
            },
          }),
          200,
        );
      });
      await expectLater(
        fetchIcon(FigmaClient(client, 'secret'), c),
        throwsA(isA<SplashException>()),
      );
      client.close();
    }
    final client = MockClient(
      (_) async => throw StateError('must not request'),
    );
    await expectLater(
      fetchIcon(FigmaClient(client, ''), c),
      throwsA(isA<SplashException>()),
    );
    client.close();
  });

  test('icon check 与 dry-run 不写工程，create 后通过', () async {
    iconProjectFixture(root);
    final yaml = iconYaml(platforms: '[ios]');
    final c = IconConfig.parse(yaml);
    write(root, 'figma_splash.yaml', yaml);
    saveIconSnapshot(root, iconFixture(c));
    await runIconCli(['check', '--project', root.path]);
    expect(exitCode, 2);
    exitCode = 0;
    await runIconCli(['create', '--dry-run', '--project', root.path]);
    expect(exitCode, 0);
    expect(
      Directory(
        p.join(root.path, 'ios/Runner/Assets.xcassets/figma_icon.appiconset'),
      ).existsSync(),
      isFalse,
    );
    await runIconCli(['create', '--project', root.path]);
    expect(exitCode, 0);
    await runIconCli(['check', '--project', root.path]);
    expect(exitCode, 0);
  });
}
