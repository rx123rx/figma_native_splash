import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:figma_native_splash/figma_native_splash.dart';

void main() {
  test('README 图标完整配置与独立样例一致，覆盖全部图标选项', () {
    final text = File('README.md').readAsStringSync();
    final sample = text
        .split('<!-- BEGIN ICON CONFIG -->\n```yaml\n')[1]
        .split('\n```\n<!-- END ICON CONFIG -->')[0];
    expect(File('example/figma_icon.yaml').readAsStringSync(), '$sample\n');
    final c = IconConfig.parse(sample);
    expect(c.platforms, ['android', 'ios', 'ohos']);
    expect(c.prefix, 'figma_icon');
    expect(c.background, '#FFFFFF');
    expect(c.frame.nodes.length, 3);
    final keys = <String>[];
    void walk(YamlMap map, String prefix) {
      for (final entry in map.entries) {
        final key = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
        keys.add(key);
        if (entry.value is YamlMap) walk(entry.value, key);
      }
    }

    walk(loadYaml(sample) as YamlMap, '');
    expect(
      keys,
      unorderedEquals([
        'schema_version',
        'figma',
        'figma.icon',
        'figma.icon.url',
        'figma.icon.nodes',
        'figma.icon.nodes.background',
        'figma.icon.nodes.foreground',
        'figma.icon.nodes.monochrome',
        'platforms',
        'icon',
        'icon.platforms',
        'icon.resource_prefix',
        'icon.background_color',
        'icon.android',
        'icon.android.adaptive',
        'icon.android.monochrome',
        'project',
        'project.android_res',
        'project.android_manifest',
        'project.ios_runner',
        'project.ohos_main',
        'project.ohos_app_scope',
        'project.ohos_ability',
      ]),
    );
  });
}
