import 'dart:io';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'support.dart';

void main() {
  const minimal = '''
figma:
  phone: https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2
''';
  test(
    'README combined sample contains the complete splash example and parses',
    () {
      final readme = File('README.md').readAsStringSync();
      final sample = readme
          .split('<!-- BEGIN COMPLETE CONFIG -->\n```yaml\n')[1]
          .split('\n```\n<!-- END COMPLETE CONFIG -->')[0];
      final document = loadYaml(sample) as YamlMap;
      expect(document.keys, [
        'figma_access_token',
        'schema_version',
        'icon',
        'splash',
      ]);
      final section = {
        'figma_access_token': document['figma_access_token'],
        'schema_version': document['schema_version'],
        'splash': document['splash'],
      };
      expect(
        loadYaml(File('example/figma_splash.yaml').readAsStringSync()),
        section,
      );
      final config = SplashConfig.parse(sample);
      expect(config.frames.keys, ['phone', 'tablet']);
      expect(config.frames['phone']!.nodes.length, 3);
      expect(config.frames['tablet']!.nodes.length, 3);
      expect(config.platforms, ['android', 'ios', 'ohos']);
      expect(config.ohosAppSplash, isFalse);
      final paths = <String>[];
      void flatten(Map value, String prefix) {
        for (final entry in value.entries) {
          final path = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
          paths.add(path);
          if (entry.value is Map) flatten(entry.value as Map, path);
        }
      }

      flatten(section, '');
      expect(
        paths,
        unorderedEquals([
          'figma_access_token',
          'schema_version',
          'splash',
          'splash.figma',
          'splash.figma.phone',
          'splash.figma.phone.url',
          'splash.figma.phone.nodes',
          'splash.figma.phone.nodes.background',
          'splash.figma.phone.nodes.foreground',
          'splash.figma.phone.nodes.branding',
          'splash.figma.tablet',
          'splash.figma.tablet.url',
          'splash.figma.tablet.nodes',
          'splash.figma.tablet.nodes.background',
          'splash.figma.tablet.nodes.foreground',
          'splash.figma.tablet.nodes.branding',
          'splash.platforms',
          'splash.resource_prefix',
          'splash.background_color',
          'splash.ohos',
          'splash.ohos.app_splash',
          'splash.project',
          'splash.project.android_res',
          'splash.project.ios_runner',
          'splash.project.ohos_main',
          'splash.project.ohos_page',
          'splash.project.ohos_ability',
        ]),
      );
    },
  );
  test('Omitted optional fields use the documented defaults', () {
    final config = SplashConfig.parse(splashYaml(minimal));
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
        () => SplashConfig.parse(splashYaml('$minimal$field\n')),
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
        () => SplashConfig.parse(splashYaml(text)),
        throwsA(isA<SplashException>()),
        reason: text,
      );
    }
    final config = SplashConfig.parse(
      splashYaml('''
figma:
  phone:
    url: https://figma.com/design/Example?node-id=1-2
    nodes:
      branding: "10-3"
ohos: {}
project: {}
'''),
    );
    expect(config.frames['phone']!.nodes, {'branding': '10:3'});
    expect(config.ohosAppSplash, isFalse);
  });
  test('Changing OHOS module does not silently change the page default', () {
    final config = SplashConfig.parse(
      splashYaml('${minimal}project:\n  ohos_main: ohos/custom/src/main\n'),
    );
    expect(
      config.paths['ohos_page'],
      'ohos/entry/src/main/ets/pages/Index.ets',
    );
  });
}
