import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:figma_native_splash/figma_native_splash.dart';

void main() {
  test('README 合并配置包含完整图标段，与独立样例一致', () {
    final text = File('README.md').readAsStringSync();
    final sample = text
        .split('<!-- BEGIN COMPLETE CONFIG -->\n```yaml\n')[1]
        .split('\n```\n<!-- END COMPLETE CONFIG -->')[0];
    final document = loadYaml(sample) as YamlMap;
    expect(document.keys, ['schema_version', 'icon', 'splash']);
    final section = {
      'schema_version': document['schema_version'],
      'icon': document['icon'],
    };
    expect(
      loadYaml(File('example/figma_icon.yaml').readAsStringSync()),
      section,
    );
    final c = IconConfig.parse(sample);
    expect(c.platforms, ['android', 'ios', 'ohos']);
    expect(c.prefix, 'figma_icon');
    expect(c.background, '#FFFFFF');
    expect(c.frame.nodes.length, 3);
    final keys = <String>[];
    void walk(Map map, String prefix) {
      for (final entry in map.entries) {
        final key = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
        keys.add(key);
        if (entry.value is Map) walk(entry.value, key);
      }
    }

    walk(section, '');
    expect(
      keys,
      unorderedEquals([
        'schema_version',
        'icon.figma',
        'icon.figma.url',
        'icon.figma.nodes',
        'icon.figma.nodes.background',
        'icon.figma.nodes.foreground',
        'icon.figma.nodes.monochrome',
        'icon',
        'icon.platforms',
        'icon.resource_prefix',
        'icon.background_color',
        'icon.android',
        'icon.android.adaptive',
        'icon.android.monochrome',
        'icon.project',
        'icon.project.android_res',
        'icon.project.android_manifest',
        'icon.project.ios_runner',
        'icon.project.ohos_main',
        'icon.project.ohos_app_scope',
        'icon.project.ohos_ability',
      ]),
    );
  });
}
