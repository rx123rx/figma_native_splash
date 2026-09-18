import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:test/test.dart';

const icon = '''icon:
  figma: https://figma.com/design/Example?node-id=1-2
''';
const splash = '''splash:
  figma:
    phone: https://figma.com/design/Example?node-id=1-2
''';

void main() {
  test('两段独立使用默认平台、底色和工程路径', () {
    final text = '''$icon$splash
  platforms: [ios]
  background_color: "#123456"
  project:
    ios_runner: ios/Custom
    ohos_ability: CustomAbility
''';
    final i = IconConfig.parse(text), s = SplashConfig.parse(text);
    expect(i.platforms, ['android', 'ios', 'ohos']);
    expect(i.background, isNull);
    expect(i.paths['ios_runner'], 'ios/Runner');
    expect(i.ability, 'EntryAbility');
    expect(s.platforms, ['ios']);
    expect(s.color, '#123456');
    expect(s.paths['ios_runner'], 'ios/Custom');
    expect(s.ability, 'CustomAbility');

    final reverse = '''$splash$icon
  platforms: [ohos]
  background_color: "#654321"
  project:
    ios_runner: ios/IconHost
    ohos_ability: IconAbility
''';
    final s2 = SplashConfig.parse(reverse), i2 = IconConfig.parse(reverse);
    expect(s2.platforms, ['android', 'ios', 'ohos']);
    expect(s2.color, '#FFFFFF');
    expect(s2.paths['ios_runner'], 'ios/Runner');
    expect(s2.ability, 'EntryAbility');
    expect(i2.platforms, ['ohos']);
    expect(i2.background, '#654321');
    expect(i2.paths['ios_runner'], 'ios/IconHost');
    expect(i2.ability, 'IconAbility');
  });

  test('仅配置一个功能时另一命令明确报缺少配置段', () {
    expect(IconConfig.parse(icon).frame.link.nodeId, '1:2');
    expect(SplashConfig.parse(splash).frames.keys, ['phone']);
    expect(
      () => SplashConfig.parse(icon),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('缺少 splash'),
        ),
      ),
    );
    expect(
      () => IconConfig.parse(splash),
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('缺少 icon'),
        ),
      ),
    );
  });

  test('拒绝功能字段放在顶层或与分段结构混用', () {
    for (final text in [
      'figma:\n  phone: https://figma.com/design/Example?node-id=1-2',
      'platforms: [ios]\n$icon$splash',
      'project: {}\n$icon$splash',
      'schema_version: 1\nbackground_color: "#FFFFFF"\n$icon$splash',
    ]) {
      for (final parse in [IconConfig.parse, SplashConfig.parse]) {
        expect(
          () => parse(text),
          throwsA(
            isA<SplashException>().having(
              (e) => e.message,
              'message',
              contains('未知字段'),
            ),
          ),
        );
      }
    }
  });

  test('配置版本与顶层映射严格校验，默认版本为 1', () {
    for (final value in ['null', '1.0', '"1"', '2', '3', 'false']) {
      for (final parse in [IconConfig.parse, SplashConfig.parse]) {
        expect(
          () => parse('schema_version: $value\n$icon$splash'),
          throwsA(isA<SplashException>()),
        );
      }
    }
    for (final text in [
      'icon: null\n$splash',
      '$icon\nsplash: []',
      'typo: true\n$icon$splash',
    ]) {
      for (final parse in [IconConfig.parse, SplashConfig.parse]) {
        expect(() => parse(text), throwsA(isA<SplashException>()));
      }
    }
    expect(
      IconConfig.parse('schema_version: 1\n$icon').sourceHash,
      IconConfig.parse(icon).sourceHash,
    );
    expect(
      SplashConfig.parse('schema_version: 1\n$splash').sourceHash,
      SplashConfig.parse(splash).sourceHash,
    );
  });

  test('两段均存在时拒绝前缀冲突，单段允许自定义前缀', () {
    final text = '$icon  resource_prefix: figma_splash\n$splash';
    for (final parse in [IconConfig.parse, SplashConfig.parse]) {
      expect(
        () => parse(text),
        throwsA(
          isA<SplashException>().having(
            (e) => e.message,
            'message',
            contains('不能相同'),
          ),
        ),
      );
    }
    expect(
      IconConfig.parse('$icon  resource_prefix: figma_splash').prefix,
      'figma_splash',
    );
  });

  test('选中功能的未知字段和另一功能专用路径不能静默通过', () {
    for (final field in [
      'android: {}',
      'project: {android_manifest: app.xml}',
      'project: {ohos_app_scope: ohos/AppScope}',
    ]) {
      expect(
        () => SplashConfig.parse('$splash  $field'),
        throwsA(isA<SplashException>()),
      );
    }
    for (final field in ['ohos: {}', 'project: {ohos_page: Index.ets}']) {
      expect(
        () => IconConfig.parse('$icon  $field'),
        throwsA(isA<SplashException>()),
      );
    }
  });
}
