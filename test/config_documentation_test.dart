import 'dart:io';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  const minimal = '''
figma:
  phone: https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2
''';
  test('README complete sample matches the standalone example and parses', () {
    final readme = File('README.md').readAsStringSync();
    final sample = readme
        .split('<!-- BEGIN FULL CONFIG -->\n```yaml\n')[1]
        .split('\n```\n<!-- END FULL CONFIG -->')[0];
    expect(File('example/figma_splash.yaml').readAsStringSync(), '$sample\n');
    final config = SplashConfig.parse(sample);
    expect(config.frames.keys, ['phone', 'tablet']);
    expect(config.frames['phone']!.nodes.length, 3);
    expect(config.frames['tablet']!.nodes.length, 3);
    expect(config.platforms, ['android', 'ios', 'ohos']);
    expect(config.ohosAppSplash, isFalse);
    final paths = <String>[];
    void flatten(YamlMap value, String prefix) {
      for (final entry in value.entries) {
        final path = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
        paths.add(path);
        if (entry.value is YamlMap) flatten(entry.value as YamlMap, path);
      }
    }

    flatten(loadYaml(sample) as YamlMap, '');
    expect(
      paths,
      unorderedEquals([
        'schema_version',
        'figma',
        'figma.phone',
        'figma.phone.url',
        'figma.phone.nodes',
        'figma.phone.nodes.background',
        'figma.phone.nodes.foreground',
        'figma.phone.nodes.branding',
        'figma.tablet',
        'figma.tablet.url',
        'figma.tablet.nodes',
        'figma.tablet.nodes.background',
        'figma.tablet.nodes.foreground',
        'figma.tablet.nodes.branding',
        'platforms',
        'resource_prefix',
        'background_color',
        'ohos',
        'ohos.app_splash',
        'project',
        'project.android_res',
        'project.ios_runner',
        'project.ohos_main',
        'project.ohos_page',
        'project.ohos_ability',
      ]),
    );
  });
  test('Omitted optional fields use the documented defaults', () {
    final config = SplashConfig.parse(minimal);
    expect(config.frames.keys, ['phone']);
    expect(config.frames['phone']!.nodes, isEmpty);
    expect(config.platforms, ['android', 'ios', 'ohos']);
    expect(config.prefix, 'figma_splash');
    expect(config.color, '#FFFFFF');
    expect(config.ohosAppSplash, isFalse);
    expect(config.ability, 'EntryAbility');
    expect(config.paths, {
      'android_res': 'android/app/src/main/res',
      'ios_runner': 'ios/Runner',
      'ohos_main': 'ohos/entry/src/main',
      'ohos_page': 'ohos/entry/src/main/ets/pages/Index.ets',
    });
  });
  test('Explicit null and wrong scalar types never masquerade as defaults', () {
    for (final field in [
      'schema_version: null',
      'schema_version: 1.0',
      'schema_version: "1"',
      'platforms: null',
      'platforms: []',
      'resource_prefix: null',
      'resource_prefix: 123',
      'background_color: null',
      'background_color: 123456',
      'ohos: null',
      'ohos:\n  app_splash: null',
      'project: null',
      'project:\n  ohos_ability: null',
      'project:\n  android_res: false',
      'project:\n  ios_runner: ""',
    ]) {
      expect(
        () => SplashConfig.parse('$minimal$field\n'),
        throwsA(isA<SplashException>()),
        reason: field,
      );
    }
  });
  test('Phone/url required; node mappings optional and string-only', () {
    for (final text in [
      'figma: {}',
      'figma: null',
      'platforms: [android]',
      'figma:\n  phone: {}',
      'figma:\n  phone: null',
      'figma:\n  phone:\n    url: 123',
      '$minimal  tablet: {}',
      'figma:\n  phone:\n    url: https://figma.com/design/Example?node-id=1-2\n    nodes: null',
      'figma:\n  phone:\n    url: https://figma.com/design/Example?node-id=1-2\n    nodes:\n      background: 123',
    ]) {
      expect(
        () => SplashConfig.parse(text),
        throwsA(isA<SplashException>()),
        reason: text,
      );
    }
    final config = SplashConfig.parse('''
figma:
  phone:
    url: https://figma.com/design/Example?node-id=1-2
    nodes:
      branding: "10-3"
ohos: {}
project: {}
''');
    expect(config.frames['phone']!.nodes, {'branding': '10:3'});
    expect(config.ohosAppSplash, isFalse);
  });
  test('Changing OHOS module does not silently change the page default', () {
    final config = SplashConfig.parse(
      '${minimal}project:\n  ohos_main: ohos/custom/src/main\n',
    );
    expect(
      config.paths['ohos_page'],
      'ohos/entry/src/main/ets/pages/Index.ets',
    );
  });
}
