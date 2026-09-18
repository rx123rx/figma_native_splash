import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'config.dart';

/// Icon-only settings. Splash commands never generate desktop icons.
class IconConfig {
  final Map<String, String> paths;
  final String ability;
  final FrameConfig frame;
  final List<String> platforms;
  final String prefix;
  final String? background;
  final bool adaptive, monochrome;
  final String androidManifest, ohosAppScope;
  IconConfig._(
    this.paths,
    this.ability,
    this.frame,
    this.platforms,
    this.prefix,
    this.background,
    this.adaptive,
    this.monochrome,
    this.androidManifest,
    this.ohosAppScope,
  );

  factory IconConfig.load(File file) {
    if (!file.existsSync()) throw SplashException('未找到配置：${file.path}');
    return IconConfig.parse(file.readAsStringSync());
  }
  factory IconConfig.parse(String text) {
    final map = configSection(text, 'icon');
    allowedKeys(map, {
      'figma',
      'platforms',
      'resource_prefix',
      'background_color',
      'android',
      'project',
    }, 'icon');
    if (!map.containsKey('figma')) throw SplashException('生成图标必须提供 icon.figma');
    final frame = FrameConfig.parse(
      map['figma'],
      roles: {'background', 'foreground', 'monochrome'},
    );
    final platforms = configPlatforms(map, 'icon');
    final prefix = configString(
      map,
      'resource_prefix',
      'icon.resource_prefix',
      fallback: 'figma_icon',
    );
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(prefix)) {
      throw SplashException('icon.resource_prefix 只允许小写字母开头及小写字母、数字、下划线');
    }
    final background = map.containsKey('background_color')
        ? configString(map, 'background_color', 'icon.background_color')
        : null;
    if (background != null &&
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(background)) {
      throw SplashException('icon.background_color 必须是带引号的 #RRGGBB');
    }
    final android = configMap(map, 'android');
    allowedKeys(android, {'adaptive', 'monochrome'}, 'icon.android');
    bool boolean(String key, bool fallback) {
      if (!android.containsKey(key)) return fallback;
      if (android[key] is! bool) {
        throw SplashException('icon.android.$key 必须为 true 或 false');
      }
      return android[key] as bool;
    }

    final adaptive = boolean('adaptive', true),
        monochrome = boolean('monochrome', false);
    if (monochrome && !adaptive) {
      throw SplashException('monochrome: true 要求 adaptive: true');
    }
    final project = configMap(map, 'project');
    allowedKeys(project, {
      'android_res',
      'android_manifest',
      'ios_runner',
      'ohos_main',
      'ohos_app_scope',
      'ohos_ability',
    }, 'icon.project');
    final defaults = {
      'android_res': 'android/app/src/main/res',
      'ios_runner': 'ios/Runner',
      'ohos_main': 'ohos/entry/src/main',
    };
    final paths = {
      for (final entry in defaults.entries)
        entry.key: safeRelative(
          configString(
            project,
            entry.key,
            'icon.project.${entry.key}',
            fallback: entry.value,
          ),
        ),
    };
    return IconConfig._(
      paths,
      configString(
        project,
        'ohos_ability',
        'icon.project.ohos_ability',
        fallback: 'EntryAbility',
      ),
      frame,
      platforms,
      prefix,
      background,
      adaptive,
      monochrome,
      safeRelative(
        configString(
          project,
          'android_manifest',
          'icon.project.android_manifest',
          fallback: 'android/app/src/main/AndroidManifest.xml',
        ),
      ),
      safeRelative(
        configString(
          project,
          'ohos_app_scope',
          'icon.project.ohos_app_scope',
          fallback: 'ohos/AppScope',
        ),
      ),
    );
  }
  List<String> get roles => [
    if (platforms.contains('android') && adaptive) ...[
      'background',
      'foreground',
    ],
    if (platforms.contains('android') && monochrome) 'monochrome',
  ];
  String get sourceHash => sha256
      .convert(
        utf8.encode(jsonEncode({'frame': frame.toJson(), 'roles': roles})),
      )
      .toString();
}
