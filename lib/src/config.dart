import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class SplashException implements Exception {
  final String message;
  SplashException(this.message);
  @override
  String toString() => message;
}

Map<String, dynamic> asMap(dynamic value, String label) {
  if (value is! Map) throw SplashException('$label 必须为映射');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void allowedKeys(Map<String, dynamic> map, Set<String> keys, String label) {
  final unknown = map.keys.where((key) => !keys.contains(key));
  if (unknown.isNotEmpty) {
    throw SplashException('$label 包含未知字段：${unknown.join(', ')}');
  }
}

/// Read a string without silently accepting numbers, booleans, or null.
String configString(
  Map<String, dynamic> map,
  String key,
  String label, {
  String? fallback,
}) {
  if (!map.containsKey(key) && fallback != null) return fallback;
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw SplashException('$label 必须为非空字符串');
  }
  return value;
}

Map<String, dynamic> configMap(Map<String, dynamic> map, String key) =>
    map.containsKey(key) ? asMap(map[key], key) : <String, dynamic>{};

/// Read the configuration document envelope. Each command parses only its own section;
/// there are no inherited platform, color, path or source settings.
Map<String, dynamic> configSection(String text, String section) {
  final root = asMap(loadYaml(text), '配置');
  allowedKeys(root, {'schema_version', 'icon', 'splash'}, '配置根节点');
  if (root.containsKey('schema_version') &&
      (root['schema_version'] is! int || root['schema_version'] != 1)) {
    throw SplashException('schema_version 仅支持整数 1，省略时默认 1');
  }
  for (final key in ['icon', 'splash']) {
    if (root.containsKey(key)) asMap(root[key], key);
  }
  if (!root.containsKey(section)) {
    throw SplashException('缺少 $section 配置段，请仅运行已配置功能的命令');
  }
  if (root.containsKey('icon') && root.containsKey('splash')) {
    final icon = asMap(root['icon'], 'icon');
    final splash = asMap(root['splash'], 'splash');
    if ((icon['resource_prefix'] ?? 'figma_icon') ==
        (splash['resource_prefix'] ?? 'figma_splash')) {
      throw SplashException(
        'icon.resource_prefix 与 splash.resource_prefix 不能相同',
      );
    }
  }
  return asMap(root[section], section);
}

List<String> configPlatforms(Map<String, dynamic> map, String section) {
  final raw = map.containsKey('platforms')
      ? map['platforms']
      : ['android', 'ios', 'ohos'];
  if (raw is! List ||
      raw.isEmpty ||
      raw.any(
        (value) =>
            value is! String || !['android', 'ios', 'ohos'].contains(value),
      )) {
    throw SplashException('$section.platforms 必须是非空的平台列表（android/ios/ohos）');
  }
  return raw.cast<String>().toSet().toList();
}

String safeRelative(String value) {
  final normalized = p.normalize(value);
  if (p.isAbsolute(value) ||
      normalized == '..' ||
      normalized.startsWith('../') ||
      value.contains('\\')) {
    throw SplashException('路径必须位于项目内：$value');
  }
  return normalized;
}

class FigmaLink {
  final String fileKey;
  final String nodeId;
  FigmaLink(this.fileKey, this.nodeId);
  factory FigmaLink.parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !['www.figma.com', 'figma.com'].contains(uri.host)) {
      throw SplashException('请提供 HTTPS Figma design/file 链接');
    }
    final segments = uri.pathSegments;
    if (segments.length < 2 || !['design', 'file'].contains(segments[0])) {
      throw SplashException('仅支持 Figma Design 文件');
    }
    var key = segments[1];
    if (segments.length > 3 && segments[2] == 'branch') key = segments[3];
    final node = uri.queryParameters['node-id']?.replaceAll('-', ':');
    if (node == null ||
        !RegExp(r'^\d+:\d+$').hasMatch(node) ||
        !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(key)) {
      throw SplashException('Figma 链接必须包含有效文件 ID 和 node-id');
    }
    return FigmaLink(key, node);
  }
  Map<String, dynamic> toJson() => {'fileKey': fileKey, 'nodeId': nodeId};
}

class FrameConfig {
  final FigmaLink link;
  final Map<String, String> nodes;
  FrameConfig(this.link, this.nodes);
  factory FrameConfig.parse(
    dynamic value, {
    Set<String> roles = const {'background', 'foreground', 'branding'},
  }) {
    if (value is String) return FrameConfig(FigmaLink.parse(value), {});
    final map = asMap(value, 'figma 画板');
    allowedKeys(map, {'url', 'nodes'}, 'figma 画板');
    final nodes = configMap(map, 'nodes');
    allowedKeys(nodes, roles, 'nodes');
    final result = <String, String>{};
    for (final entry in nodes.entries) {
      final node = configString(
        nodes,
        entry.key,
        'nodes.${entry.key}',
      ).replaceAll('-', ':');
      if (!RegExp(r'^\d+:\d+$').hasMatch(node)) {
        throw SplashException('无效图层节点：${entry.key}');
      }
      result[entry.key] = node;
    }
    return FrameConfig(
      FigmaLink.parse(configString(map, 'url', 'figma 画板 url')),
      result,
    );
  }
  Map<String, dynamic> toJson() => {'link': link.toJson(), 'nodes': nodes};
}

class SplashConfig {
  final Map<String, FrameConfig> frames;
  final List<String> platforms;
  final String prefix;
  final String color;
  final Map<String, String> paths;
  final String ability;
  final bool ohosAppSplash;
  SplashConfig(
    this.frames,
    this.platforms,
    this.prefix,
    this.color,
    this.paths,
    this.ability, {
    this.ohosAppSplash = false,
  });
  factory SplashConfig.load(File file) {
    if (!file.existsSync()) throw SplashException('未找到配置：${file.path}');
    return SplashConfig.parse(file.readAsStringSync());
  }
  factory SplashConfig.parse(String text) {
    final map = configSection(text, 'splash');
    allowedKeys(map, {
      'figma',
      'platforms',
      'resource_prefix',
      'background_color',
      'project',
      'ohos',
    }, 'splash');
    final figma = asMap(map['figma'], 'splash.figma');
    allowedKeys(figma, {'phone', 'tablet'}, 'splash.figma');
    if (!figma.containsKey('phone')) {
      throw SplashException('生成启动图必须提供 splash.figma.phone');
    }
    final frames = {
      for (final entry in figma.entries)
        entry.key: FrameConfig.parse(entry.value),
    };
    final platforms = configPlatforms(map, 'splash');
    final prefix = configString(
      map,
      'resource_prefix',
      'splash.resource_prefix',
      fallback: 'figma_splash',
    );
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(prefix)) {
      throw SplashException('resource_prefix 只允许小写字母、数字、下划线');
    }
    final color = configString(
      map,
      'background_color',
      'splash.background_color',
      fallback: '#FFFFFF',
    );
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      throw SplashException('background_color 必须为带引号的 #RRGGBB');
    }
    final ohos = configMap(map, 'ohos');
    allowedKeys(ohos, {'app_splash'}, 'splash.ohos');
    final appSplash = ohos.containsKey('app_splash')
        ? ohos['app_splash']
        : false;
    if (appSplash is! bool) {
      throw SplashException('splash.ohos.app_splash 必须为 true 或 false');
    }
    final project = configMap(map, 'project');
    allowedKeys(project, {
      'android_res',
      'ios_runner',
      'ohos_main',
      'ohos_page',
      'ohos_ability',
    }, 'splash.project');
    final defaults = {
      'android_res': 'android/app/src/main/res',
      'ios_runner': 'ios/Runner',
      'ohos_main': 'ohos/entry/src/main',
      'ohos_page': 'ohos/entry/src/main/ets/pages/Index.ets',
    };
    final paths = {
      for (final entry in defaults.entries)
        entry.key: safeRelative(
          configString(
            project,
            entry.key,
            'splash.project.${entry.key}',
            fallback: entry.value,
          ),
        ),
    };
    return SplashConfig(
      frames,
      platforms,
      prefix,
      color,
      paths,
      configString(
        project,
        'ohos_ability',
        'splash.project.ohos_ability',
        fallback: 'EntryAbility',
      ),
      ohosAppSplash: appSplash,
    );
  }
  String get sourceHash => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            for (final entry in frames.entries) entry.key: entry.value.toJson(),
          }),
        ),
      )
      .toString();
}
