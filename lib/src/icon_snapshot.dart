import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'config.dart';
import 'icon_config.dart';
import 'figma.dart';
import 'output.dart';
import 'snapshot.dart';

const iconSnapshotDirectory = '.figma_splash/icon_snapshot';

class IconSnapshot {
  final Map<String, List<int>> assets;
  final Map<String, dynamic> metadata;
  IconSnapshot(this.assets, this.metadata);
  img.Image image(String name) {
    final bytes = assets['$name.png'];
    final image = bytes == null
        ? null
        : img.decodePng(Uint8List.fromList(bytes));
    if (image == null || image.width != image.height || image.width < 1024) {
      throw SplashException('图标 $name 必须是至少 1024×1024 的正方形 PNG');
    }
    return image;
  }

  void validate(IconConfig config) {
    if (metadata['sourceHash'] != config.sourceHash) {
      throw SplashException('图标来源或所需图层已变化，请执行 icon sync');
    }
    for (final name in ['icon', ...config.roles]) {
      image(name);
    }
  }

  factory IconSnapshot.load(Directory root, IconConfig config) {
    final plan = OutputPlan(root);
    final file = File(plan.absolute('$iconSnapshotDirectory/snapshot.json'));
    if (!file.existsSync()) throw SplashException('没有图标快照，请先执行 icon sync');
    final data = asMap(jsonDecode(file.readAsStringSync()), 'icon snapshot');
    if (data['schemaVersion'] != 1) {
      throw SplashException('图标快照版本不兼容，请重新 icon sync');
    }
    final assets = <String, List<int>>{};
    for (final entry in asMap(data['sha256'], 'icon sha256').entries) {
      if (![
        'icon.png',
        'background.png',
        'foreground.png',
        'monochrome.png',
      ].contains(entry.key)) {
        throw SplashException('未知图标快照文件：${entry.key}');
      }
      final bytes = File(
        plan.absolute('$iconSnapshotDirectory/${entry.key}'),
      ).readAsBytesSync();
      if (sha256.convert(bytes).toString() != entry.value) {
        throw SplashException('图标快照素材校验失败：${entry.key}');
      }
      assets[entry.key] = bytes;
    }
    final snapshot = IconSnapshot(assets, data)..validate(config);
    return snapshot;
  }
  Map<String, List<int>> files() => {
    ...assets,
    'snapshot.json': utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert({...metadata, 'schemaVersion': 1, 'sha256': assets.map((k, v) => MapEntry(k, sha256.convert(v).toString()))})}\n',
    ),
  };
}

/// Sync a standalone icon frame and optional full-canvas adaptive layers.
Future<IconSnapshot> fetchIcon(FigmaClient api, IconConfig config) async {
  if (api.token.trim().isEmpty) {
    throw SplashException(
      'icon sync 需要 FIGMA_ACCESS_TOKEN 环境变量或顶层 figma_access_token 配置',
    );
  }
  final link = config.frame.link;
  final data = await api.requestJson('files/${link.fileKey}/nodes', {
    'ids': link.nodeId,
  });
  final version = data['version'];
  if (version is! String || version.isEmpty) {
    throw SplashException('Figma 未返回图标设计版本');
  }
  final record = asMap(data['nodes'], 'nodes')[link.nodeId];
  if (record == null) throw SplashException('找不到图标画板');
  final root = asMap(asMap(record, 'node')['document'], 'document');
  if (!['FRAME', 'COMPONENT', 'INSTANCE'].contains(root['type']) ||
      root['visible'] == false) {
    throw SplashException('icon.figma 必须指向可见的 Frame/Component/Instance');
  }
  final bounds = DesignRect.fromJson(
    asMap(root['absoluteBoundingBox'], 'icon bounds'),
  );
  if ((bounds.width - bounds.height).abs() > .01 ||
      bounds.width < 256 ||
      bounds.width > 4096) {
    throw SplashException('图标画板必须为正方形，边长 256～4096，推荐 1024');
  }
  final descendants = <Map<String, dynamic>>[];
  void walk(Map<String, dynamic> node) {
    for (final raw in node['children'] as List? ?? []) {
      final child = asMap(raw, 'icon child');
      if (child['visible'] == false) continue;
      descendants.add(child);
      walk(child);
    }
  }

  walk(root);
  if (config.roles.isEmpty &&
      descendants.any((node) => node['name'] == 'icon/monochrome')) {
    throw SplashException(
      '整张图标画板中不能包含可见的 icon/monochrome 辅助层；请隐藏它，或启用 Android adaptive 使用前景和背景合成图标',
    );
  }
  final exports = <String, String>{'icon': link.nodeId};
  for (final role in config.roles) {
    final id = config.frame.nodes[role];
    final matches = descendants
        .where((n) => id == null ? n['name'] == 'icon/$role' : n['id'] == id)
        .toList();
    if (matches.length != 1) {
      throw SplashException(
        'icon/$role 匹配到 ${matches.length} 个可见图层；请使用约定名称或 icon.figma.nodes 映射',
      );
    }
    final layer = matches.single;
    final r = DesignRect.fromJson(
      asMap(layer['absoluteBoundingBox'], 'icon/$role bounds'),
    );
    if ((r.x - bounds.x).abs() > .01 ||
        (r.y - bounds.y).abs() > .01 ||
        (r.width - bounds.width).abs() > .01 ||
        (r.height - bounds.height).abs() > .01) {
      throw SplashException('icon/$role 外层容器必须与图标画板同位置、同尺寸，以保留透明留白和图层对齐');
    }
    exports[role] = layer['id'] as String;
  }
  if (exports.values.toSet().length != exports.length) {
    throw SplashException('图标角色不能映射到同一个节点');
  }
  final response = await api.requestJson('images/${link.fileKey}', {
    'ids': exports.values.join(','),
    'version': version,
    'format': 'png',
    'scale': (1024 / bounds.width).toString(),
    'use_absolute_bounds': 'true',
  });
  if (response['err'] != null) throw SplashException('Figma 图标导出失败');
  final urls = asMap(response['images'], 'images'),
      assets = <String, List<int>>{};
  for (final entry in exports.entries) {
    final uri = Uri.tryParse(urls[entry.value]?.toString() ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw SplashException('无效图标下载地址');
    }
    final response = await api.client
        .get(uri)
        .timeout(const Duration(seconds: 90));
    if (response.statusCode != 200 ||
        response.bodyBytes.length > 40 * 1024 * 1024) {
      throw SplashException('图标下载失败或素材超过 40 MB');
    }
    assets['${entry.key}.png'] = response.bodyBytes;
  }
  final snapshot = IconSnapshot(assets, {
    'sourceHash': config.sourceHash,
    'source': {...link.toJson(), 'version': version},
    'syncedAt': DateTime.now().toUtc().toIso8601String(),
  })..validate(config);
  return snapshot;
}
