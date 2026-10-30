import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:figma_native_splash/src/artwork.dart';
import 'support.dart';

/// PNG 块名列表，用于断言产物没有携带源文件的元数据。
List<String> chunks(List<int> bytes) {
  final data = Uint8List.fromList(bytes);
  final names = <String>[];
  for (var offset = 8; offset + 8 <= data.length;) {
    final length = data.buffer
        .asByteData(data.offsetInBytes + offset)
        .getUint32(0);
    names.add(String.fromCharCodes(data.sublist(offset + 4, offset + 8)));
    offset += 12 + length;
  }
  return names;
}

void main() {
  late Directory root;
  setUp(
    () => root = Directory.systemTemp.createTempSync('figma-android-test-'),
  );
  tearDown(() => root.deleteSync(recursive: true));

  test('normalizePng 去掉源文件元数据并统一编码', () {
    final source = img.Image(
      width: 4,
      height: 4,
      textData: {'Comment': 'figma export'},
    );
    img.fill(source, color: img.ColorRgb8(245, 125, 35));
    final encoded = img.encodePng(source);
    expect(chunks(encoded), contains('tEXt'));

    final normalized = normalizePng(encoded);
    expect(chunks(normalized), isNot(contains('tEXt')));
    expect(normalized, normalizePng(normalized));
    final decoded = img.decodePng(Uint8List.fromList(normalized))!;
    expect(decoded.width, 4);
    expect(decoded.getPixel(1, 1).r, 245);
  });

  test('非 PNG 素材报错而不是写入损坏资源', () {
    expect(() => normalizePng([1, 2, 3, 4]), throwsA(isA<SplashException>()));
  });

  test('Android 与鸿蒙启动图使用规范化后的 PNG', () {
    projectFixture(root);
    final c = config(extra: 'ohos:\n  app_splash: true'), s = fixture(c);
    generate(root, c, s).apply();
    for (final (dir, name) in [
      ('android/app/src/main/res/drawable-nodpi', 'phone'),
      ('android/app/src/main/res/drawable-w600dp-nodpi', 'tablet'),
      ('ohos/entry/src/main/resources/base/media', 'phone'),
      ('ohos/entry/src/main/resources/base/media', 'tablet'),
    ]) {
      for (final role in ['background', 'foreground', 'branding']) {
        final suffix = dir.startsWith('ohos') ? '${name}_$role' : role;
        final file = File('${p.join(root.path, dir)}/figma_splash_$suffix.png');
        expect(
          chunks(file.readAsBytesSync()),
          isNot(contains('tEXt')),
          reason: '${file.path} 不应携带源文件元数据',
        );
      }
    }
    for (final role in ['background', 'foreground', 'branding']) {
      final android = File(
        p.join(
          root.path,
          'android/app/src/main/res/drawable-nodpi/figma_splash_$role.png',
        ),
      ).readAsBytesSync();
      final ohos = File(
        p.join(
          root.path,
          'ohos/entry/src/main/resources/base/media/figma_splash_phone_$role.png',
        ),
      ).readAsBytesSync();
      expect(android, ohos, reason: '同一图层在两端应得到相同字节');
    }
  });
}
