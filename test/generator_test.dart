import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:figma_native_splash/src/artwork.dart';
import 'support.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('figma-splash-test-'));
  tearDown(() => root.deleteSync(recursive: true));
  test('三端生成保留工程逻辑，重复生成不产生差异', () {
    projectFixture(root);
    final c = config(extra: 'ohos:\n  app_splash: true'), s = fixture(c);
    final plan = generate(root, c, s);
    expect(plan.changes, isNotEmpty);
    expect(
      File(
        p.join(
          root.path,
          'ios/Runner/Base.lproj/figma_splash_LaunchScreen.storyboard',
        ),
      ).existsSync(),
      isFalse,
    );
    plan.apply();
    expect(generate(root, c, s).changes, isEmpty);
    final android = XmlDocument.parse(
      File(
        p.join(root.path, 'android/app/src/main/res/values/styles.xml'),
      ).readAsStringSync(),
    );
    expect(
      android
          .findAllElements('style')
          .singleWhere((e) => e.getAttribute('name') == 'NormalTheme')
          .innerText
          .trim(),
      '?android:colorBackground',
    );
    final page = File(
      p.join(root.path, 'ohos/entry/src/main/ets/pages/Index.ets'),
    ).readAsStringSync();
    expect(page, contains('onBackPress(): boolean { return true; }'));
    expect(page, contains('splashScreenView: FigmaSplash'));
    final module = File(
      p.join(root.path, 'ohos/entry/src/main/module.json5'),
    ).readAsStringSync();
    expect(module, contains('// keep comment'));
    expect(module, contains('ohos.permission.INTERNET'));
    expect(module, contains('"icon":"\$media:icon"'));
  });
  test('仅选 Android 不要求其他平台目录', () {
    projectFixture(root);
    Directory(p.join(root.path, 'ios')).deleteSync(recursive: true);
    Directory(p.join(root.path, 'ohos')).deleteSync(recursive: true);
    final c = config();
    generate(root, c, fixture(c), platforms: ['android']).apply();
    expect(Directory(p.join(root.path, 'ios')).existsSync(), isFalse);
  });
  test('任一平台校验失败时不写入其他平台', () {
    projectFixture(root);
    File(p.join(root.path, 'ios/Runner/Info.plist')).deleteSync();
    final c = config();
    expect(
      () => generate(root, c, fixture(c)),
      throwsA(isA<SplashException>()),
    );
    expect(
      Directory(
        p.join(root.path, 'android/app/src/main/res/drawable-nodpi'),
      ).existsSync(),
      isFalse,
    );
  });
  test('保护手动改过的生成资源和首次生成的同名资源', () {
    projectFixture(root);
    final c = config(), s = fixture(c);
    final output = 'android/app/src/main/res/values/figma_splash.xml';
    write(root, output, 'manual');
    expect(() => generate(root, c, s), throwsA(isA<SplashException>()));
    File(p.join(root.path, output)).deleteSync();
    generate(root, c, s).apply();
    write(root, output, 'manual');
    expect(() => generate(root, c, s), throwsA(isA<SplashException>()));
  });
  test('更新已有鸿蒙 builder 引用但保留原方法', () {
    projectFixture(root);
    final path = 'ohos/entry/src/main/ets/pages/Index.ets';
    var page = File(p.join(root.path, path)).readAsStringSync();
    page = page.replaceFirst(
      'viewId: this.viewId,',
      'viewId: this.viewId, splashScreenView: this.oldBuilder,',
    );
    write(root, path, page);
    final c = config(extra: 'ohos:\n  app_splash: true');
    generate(root, c, fixture(c), platforms: ['ohos']).apply();
    expect(
      File(p.join(root.path, path)).readAsStringSync(),
      contains('splashScreenView: FigmaSplash'),
    );
  });
  test('鸿蒙默认只生成系统启动资源，页面保持不变', () {
    projectFixture(root);
    final c = config(), s = fixture(c);
    final page = File(
      p.join(root.path, 'ohos/entry/src/main/ets/pages/Index.ets'),
    );
    final before = page.readAsStringSync();
    final plan = generate(root, c, s, platforms: ['ohos']);
    expect(c.ohosAppSplash, isFalse);
    expect(plan.writes.keys.where((key) => key.endsWith('.ets')), isEmpty);
    plan.apply();
    expect(page.readAsStringSync(), before);
    expect(
      File(
        p.join(
          root.path,
          'ohos/entry/src/main/resources/base/media/figma_splash_icon.png',
        ),
      ).existsSync(),
      isTrue,
    );
    expect(generate(root, c, s, platforms: ['ohos']).changes, isEmpty);
  });
  test('鸿蒙宣传图开关往返、资源清理和 dry-run', () {
    projectFixture(root);
    final off = config(), on = config(extra: 'ohos:\n  app_splash: true');
    final s = fixture(off);
    expect(
      on.sourceHash,
      off.sourceHash,
    ); // Changing layout does not require sync.
    generate(root, on, s, platforms: ['ohos']).apply();
    final page = File(
      p.join(root.path, 'ohos/entry/src/main/ets/pages/Index.ets'),
    );
    final view = File(
      p.join(root.path, 'ohos/entry/src/main/ets/figma_splash/FigmaSplash.ets'),
    );
    expect(view.existsSync(), isTrue);
    final before = page.readAsStringSync();
    final plan = generate(root, off, s, platforms: ['ohos']);
    expect(plan.deletes.length, 7);
    expect(page.readAsStringSync(), before);
    expect(view.existsSync(), isTrue);
    plan.apply();
    expect(view.existsSync(), isFalse);
    expect(page.readAsStringSync(), isNot(contains('FigmaSplash')));
    expect(page.readAsStringSync(), isNot(contains('splashScreenView')));
    expect(page.readAsStringSync(), contains('viewId: this.viewId'));
    expect(generate(root, off, s, platforms: ['ohos']).changes, isEmpty);
    generate(root, on, s, platforms: ['ohos']).apply();
    expect(view.existsSync(), isTrue);
    expect(generate(root, on, s, platforms: ['ohos']).changes, isEmpty);
  });
  test('关闭宣传图保护自定义 builder 和被修改的生成文件', () {
    projectFixture(root);
    final path = 'ohos/entry/src/main/ets/pages/Index.ets';
    final page = File(p.join(root.path, path));
    write(
      root,
      path,
      page.readAsStringSync().replaceFirst(
        'viewId: this.viewId,',
        'viewId: this.viewId, splashScreenView: this.customBuilder,',
      ),
    );
    final before = page.readAsStringSync();
    final off = config(), s = fixture(off);
    generate(root, off, s, platforms: ['ohos']).apply();
    expect(page.readAsStringSync(), before);
    final on = config(extra: 'ohos:\n  app_splash: true');
    generate(root, on, s, platforms: ['ohos']).apply();
    write(
      root,
      'ohos/entry/src/main/ets/figma_splash/FigmaSplash.ets',
      'manual change',
    );
    expect(
      () => generate(root, off, s, platforms: ['ohos']),
      throwsA(isA<SplashException>()),
    );
    expect(page.readAsStringSync(), contains('splashScreenView: FigmaSplash'));
  });
  test('鸿蒙 app_splash 拒绝字符串和未知字段', () {
    expect(
      () => config(extra: 'ohos:\n  app_splash: "false"'),
      throwsA(isA<SplashException>()),
    );
    expect(
      () => config(extra: 'ohos:\n  splash: true'),
      throwsA(isA<SplashException>()),
    );
  });
  test('快照检测素材篡改和来源变更', () {
    final c = config(), s = fixture(c);
    saveSnapshot(root, s);
    expect(DesignSnapshot.load(root, c).frames.length, 2);
    File(
      p.join(root.path, snapshotDirectory, 'phone/foreground.png'),
    ).writeAsBytesSync([0]);
    expect(() => DesignSnapshot.load(root, c), throwsA(isA<SplashException>()));
    saveSnapshot(root, s);
    expect(
      () => DesignSnapshot.load(root, config(tablet: false)),
      throwsA(isA<SplashException>()),
    );
  });
  test('窄屏、横屏、Pad 和小窗口的图层无越界或重叠', () {
    final s = fixture(config());
    for (final size in [
      [320.0, 568.0],
      [375.0, 812.0],
      [812.0, 375.0],
      [600.0, 320.0],
      [600.0, 400.0],
      [834.0, 1194.0],
      [1194.0, 834.0],
    ]) {
      final layout = fitLayout(s, size[0], size[1]);
      for (final rect in [layout.foreground, layout.branding]) {
        expect(rect.x, greaterThanOrEqualTo(0));
        expect(rect.y, greaterThanOrEqualTo(0));
        expect(rect.x + rect.width, lessThanOrEqualTo(size[0]));
        expect(rect.y + rect.height, lessThanOrEqualTo(size[1]));
      }
      expect(
        layout.foreground.y + layout.foreground.height + 31.9,
        lessThanOrEqualTo(layout.branding.y),
      );
    }
  });
  test('Android 12 所有非透明像素位于系统安全圆内', () {
    final source = img.fill(
      img.Image(width: 1050, height: 920, numChannels: 4),
      color: img.ColorRgba8(255, 0, 0, 255),
    );
    final output = systemIcon(source);
    var radius = 0.0;
    for (final pixel in output) {
      if (pixel.a > 0) {
        radius = math.max(
          radius,
          math.sqrt(math.pow(pixel.x - 576, 2) + math.pow(pixel.y - 576, 2)),
        );
      }
    }
    expect(radius, lessThan(384));
    expect(systemBrand(source).width, 800);
  });
  test('横屏预览背景裁剪后仍铺满整个画布', () {
    final c = config(), s = fixture(c);
    final output = preview(s, 1194, 834, '#0000FF');
    for (final point in [
      [0, 0],
      [1193, 0],
      [0, 833],
      [1193, 833],
    ]) {
      final pixel = output.getPixel(point[0], point[1]);
      expect(pixel.b, 35);
      expect(pixel.r, 245);
    }
  });
  test('拒绝输出路径中的符号链接', () {
    projectFixture(root);
    final outside = Directory.systemTemp.createTempSync('splash-outside-');
    try {
      Link(
        p.join(root.path, 'android/app/src/main/res/drawable-nodpi'),
      ).createSync(outside.path);
      final c = config();
      expect(
        () => generate(root, c, fixture(c)),
        throwsA(isA<SplashException>()),
      );
    } finally {
      outside.deleteSync(recursive: true);
    }
  });
}
