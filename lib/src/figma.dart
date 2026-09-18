import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'snapshot.dart';

class FigmaClient {
  final http.Client client;
  final String token;
  FigmaClient(this.client, this.token);
  Future<Map<String, dynamic>> requestJson(
    String path,
    Map<String, String> query,
  ) async {
    final response = await client
        .get(
          Uri.https('api.figma.com', '/v1/$path', query),
          headers: {'X-Figma-Token': token},
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      final hint = switch (response.statusCode) {
        401 || 403 =>
          '检查 FIGMA_ACCESS_TOKEN 或 figma_access_token、file_content:read 权限和文件访问权限',
        429 =>
          'Figma 请求限流，请稍后重试（Retry-After: ${response.headers['retry-after'] ?? '未提供'}）',
        404 => '文件、节点或设计版本不存在',
        _ => '请稍后重试',
      };
      throw SplashException('Figma API HTTP ${response.statusCode}：$hint');
    }
    return asMap(jsonDecode(response.body), 'Figma response');
  }

  Future<DesignSnapshot> fetch(SplashConfig config) async {
    if (token.trim().isEmpty) {
      throw SplashException(
        '请通过 FIGMA_ACCESS_TOKEN 环境变量或顶层 figma_access_token 配置提供 Figma Personal Access Token',
      );
    }
    final versions = <String, String>{};
    final frames = <String, DesignFrame>{};
    final assets = <String, List<int>>{};
    final sources = <String, dynamic>{};
    for (final entry in config.frames.entries) {
      final link = entry.value.link;
      final response = await requestJson('files/${link.fileKey}/nodes', {
        'ids': link.nodeId,
        if (versions.containsKey(link.fileKey))
          'version': versions[link.fileKey]!,
      });
      final version = response['version']?.toString();
      if (version == null || version.isEmpty) {
        throw SplashException('Figma 未返回设计版本，无法生成一致的快照');
      }
      versions[link.fileKey] = version;
      final record = asMap(response['nodes'], 'nodes')[link.nodeId];
      if (record == null) throw SplashException('找不到 ${entry.key} 画板节点');
      final root = asMap(asMap(record, 'node')['document'], 'document');
      if (!['FRAME', 'COMPONENT', 'INSTANCE'].contains(root['type'])) {
        throw SplashException(
          '${entry.key} 链接应指向启动图画板 Frame/Component/Instance',
        );
      }
      final bounds = DesignRect.fromJson(
        asMap(root['absoluteBoundingBox'], '画板边界'),
      );
      final descendants = <Map<String, dynamic>>[];
      void walk(Map<String, dynamic> node) {
        for (final child in (node['children'] as List? ?? [])) {
          final map = asMap(child, 'child');
          if (map['visible'] == false) continue;
          descendants.add(map);
          walk(map);
        }
      }

      walk(root);
      final layers = <String, DesignLayer>{};
      for (final role in ['background', 'foreground', 'branding']) {
        final mapped = entry.value.nodes[role];
        final found = descendants
            .where(
              (node) => mapped != null
                  ? node['id'] == mapped
                  : node['name'] == 'splash/$role',
            )
            .toList();
        if (found.length != 1) {
          throw SplashException(
            '${entry.key} 的 $role 匹配到 ${found.length} 个可见图层；请命名为 splash/$role 或在 nodes 中指定该画板内的节点 ID',
          );
        }
        final node = found.single;
        // Figma exports the rendered transform into the PNG. Use its
        // axis-aligned absolute bounds, not the untransformed local size.
        // A reflection may also report a rotation; do not reject it or
        // apply the transform again to the downloaded image.
        final r = DesignRect.fromJson(
          asMap(node['absoluteBoundingBox'], '$role 边界'),
        );
        layers[role] = DesignLayer(
          node['id'] as String,
          '${entry.key}/$role.png',
          DesignRect(r.x - bounds.x, r.y - bounds.y, r.width, r.height),
        );
      }
      final background = layers['background']!.rect;
      if (background.x.abs() > 1 ||
          background.y.abs() > 1 ||
          (background.width - bounds.width).abs() > 1 ||
          (background.height - bounds.height).abs() > 1) {
        throw SplashException('${entry.key} 的 background 容器必须覆盖完整画板');
      }
      final exportIds = [
        link.nodeId,
        ...layers.values.map((layer) => layer.nodeId),
      ];
      final exports = await requestJson('images/${link.fileKey}', {
        'ids': exportIds.join(','),
        'format': 'png',
        'scale': '3',
        'use_absolute_bounds': 'true',
        'version': version,
      });
      if (exports['err'] != null) {
        throw SplashException('Figma 图片导出失败，请检查图层可导出状态');
      }
      final urls = asMap(exports['images'], 'images');
      final names = {
        link.nodeId: '${entry.key}/reference.png',
        for (final layer in layers.values) layer.nodeId: layer.asset,
      };
      for (final image in names.entries) {
        final uri = Uri.tryParse(urls[image.key]?.toString() ?? '');
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw SplashException('Figma 未返回有效的图片下载地址');
        }
        // Download URLs never receive the Figma token.
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 90));
        if (response.statusCode != 200) {
          throw SplashException('Figma 素材下载失败 HTTP ${response.statusCode}');
        }
        if (response.bodyBytes.length > 40 * 1024 * 1024) {
          throw SplashException('单张素材超过 40 MB，请缩小设计稿');
        }
        assets[image.value] = response.bodyBytes;
      }
      frames[entry.key] = DesignFrame(bounds.width, bounds.height, layers);
      sources[entry.key] = {...link.toJson(), 'version': version};
    }
    final snapshot = DesignSnapshot(frames, {
      'sourceHash': config.sourceHash,
      'sources': sources,
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
    }, assets);
    for (final frame in frames.values) {
      for (final layer in frame.layers.values) {
        final image = snapshot.image(layer.asset);
        if ((image.width / image.height - layer.rect.width / layer.rect.height)
                .abs() >
            .03) {
          throw SplashException(
            '导出图片比例与图层不一致：${layer.asset}，'
            'PNG 为 ${image.width}×${image.height}，'
            '变换后边界为 ${layer.rect.width}×${layer.rect.height}；'
            '请检查 Figma 导出边界，必要时用覆盖完整视觉内容的 Frame 包裹',
          );
        }
      }
    }
    return snapshot;
  }
}
