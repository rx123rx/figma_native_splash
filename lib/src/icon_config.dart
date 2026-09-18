import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';
import 'config.dart';

/// Icon-only settings. Splash commands never generate desktop icons.
class IconConfig {
  final SplashConfig shared;
  final FrameConfig frame;
  final List<String> platforms;
  final String prefix;
  final String? background;
  final bool adaptive, monochrome;
  final String androidManifest, ohosAppScope;
  IconConfig._(
    this.shared,
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
    final shared = SplashConfig.parse(text, requirePhone: false);
    final root = asMap(loadYaml(text), '配置');
    final figma = asMap(root['figma'], 'figma');
    if (!figma.containsKey('icon')) {
      throw SplashException('生成图标必须提供 figma.icon');
    }
    final frame = FrameConfig.parse(
      figma['icon'],
      roles: {'background', 'foreground', 'monochrome'},
    );
    final map = configMap(root, 'icon');
    allowedKeys(map, {
      'platforms',
      'resource_prefix',
      'background_color',
      'android',
    }, 'icon');
    final raw = map.containsKey('platforms')
        ? map['platforms']
        : shared.platforms;
    if (raw is! List ||
        raw.isEmpty ||
        raw.any(
          (v) => v is! String || !['android', 'ios', 'ohos'].contains(v),
        )) {
      throw SplashException('icon.platforms 必须是非空的平台列表（android/ios/ohos）');
    }
    final prefix = configString(
      map,
      'resource_prefix',
      'icon.resource_prefix',
      fallback: 'figma_icon',
    );
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(prefix)) {
      throw SplashException('icon.resource_prefix 只允许小写字母开头及小写字母、数字、下划线');
    }
    if (prefix == shared.prefix) {
      throw SplashException('图标与启动图不能使用相同 resource_prefix');
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
    final project = configMap(root, 'project');
    return IconConfig._(
      shared,
      frame,
      raw.cast<String>().toSet().toList(),
      prefix,
      background,
      adaptive,
      monochrome,
      safeRelative(
        configString(
          project,
          'android_manifest',
          'project.android_manifest',
          fallback: 'android/app/src/main/AndroidManifest.xml',
        ),
      ),
      safeRelative(
        configString(
          project,
          'ohos_app_scope',
          'project.ohos_app_scope',
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
