import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:figma_native_splash/src/xcode_asset_catalog.dart';
import 'support.dart';

void main() {
  late Directory root;
  setUp(
    () => root = Directory.systemTemp.createTempSync('figma-catalog-test-'),
  );
  tearDown(() => root.deleteSync(recursive: true));

  test('Contents.json 采用 Xcode 的空格分隔格式并标记 author', () {
    final text = encodeAssetCatalogContents(
      imageSetContents([
        {'idiom': 'universal', 'filename': 'phone.png', 'scale': '3x'},
      ]),
    );
    expect(text, contains('"images" : ['));
    expect(text, contains('"idiom" : "universal"'));
    expect(text, contains('"author" : "xcode"'));
    expect(text, isNot(contains('"idiom": ')));
    expect(jsonDecode(text), isA<Map>());
  });

  test('空槽位不写入 Contents.json', () {
    final contents = imageSetContents([
      {'idiom': 'universal', 'scale': '1x'},
      {'idiom': 'universal', 'filename': '', 'scale': '2x'},
      {'idiom': 'universal', 'filename': 'phone.png', 'scale': '3x'},
    ]);
    final images = contents['images'] as List;
    expect(images, hasLength(1));
    expect((images.single as Map)['filename'], 'phone.png');
  });

  test('iOS 启动图与图标生成 Xcode 格式的 Contents.json', () {
    projectFixture(root);
    final c = config(), s = fixture(c);
    generate(root, c, s).apply();
    for (final role in ['background', 'foreground', 'branding']) {
      final text = File(
        p.join(
          root.path,
          'ios/Runner/Assets.xcassets/figma_splash_$role.imageset/Contents.json',
        ),
      ).readAsStringSync();
      expect(text, contains('"images" : ['));
      expect(text, contains('"author" : "xcode"'));
      final images = (jsonDecode(text) as Map)['images'] as List;
      expect(
        images.every((e) => (e as Map)['filename'] is String),
        isTrue,
        reason: '只写入带文件的槽位，避免 Xcode 显示 Unassigned',
      );
    }
  });
}
