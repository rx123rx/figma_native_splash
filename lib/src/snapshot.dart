import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'config.dart';

const snapshotDirectory = '.figma_splash/snapshot';

class DesignRect {
  final double x, y, width, height;
  DesignRect(this.x, this.y, this.width, this.height) {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        width <= 0 ||
        height <= 0) {
      throw SplashException('设计图层尺寸无效');
    }
  }
  factory DesignRect.fromJson(Map<String, dynamic> json) => DesignRect(
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['width'] as num).toDouble(),
    (json['height'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class DesignLayer {
  final String nodeId, asset;
  final DesignRect rect;
  DesignLayer(this.nodeId, this.asset, this.rect);
  factory DesignLayer.fromJson(Map<String, dynamic> json) => DesignLayer(
    json['nodeId'] as String,
    safeRelative(json['asset'] as String),
    DesignRect.fromJson(asMap(json['rect'], 'rect')),
  );
  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'asset': asset,
    'rect': rect.toJson(),
  };
}

class DesignFrame {
  final double width, height;
  final Map<String, DesignLayer> layers;
  DesignFrame(this.width, this.height, this.layers) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw SplashException('画板尺寸无效');
    }
    if (!['background', 'foreground', 'branding'].every(layers.containsKey)) {
      throw SplashException('快照缺少必需图层');
    }
  }
  factory DesignFrame.fromJson(Map<String, dynamic> json) => DesignFrame(
    (json['width'] as num).toDouble(),
    (json['height'] as num).toDouble(),
    asMap(json['layers'], 'layers').map(
      (key, value) => MapEntry(key, DesignLayer.fromJson(asMap(value, key))),
    ),
  );
  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'layers': layers.map((key, value) => MapEntry(key, value.toJson())),
  };
}

class DesignSnapshot {
  final Map<String, DesignFrame> frames;
  final Map<String, dynamic> metadata;
  final Map<String, List<int>> assets;
  DesignSnapshot(this.frames, this.metadata, this.assets);
  factory DesignSnapshot.load(Directory project, SplashConfig config) {
    final root = Directory(p.join(project.path, snapshotDirectory));
    final file = File(p.join(root.path, 'snapshot.json'));
    if (!file.existsSync()) throw SplashException('没有设计快照，请先执行 sync');
    final data = asMap(jsonDecode(file.readAsStringSync()), 'snapshot');
    if (data['schemaVersion'] != 1) throw SplashException('快照版本不兼容，请重新 sync');
    if (data['sourceHash'] != config.sourceHash) {
      throw SplashException('Figma 链接或节点映射已变化，请重新 sync');
    }
    final assets = <String, List<int>>{};
    for (final entry in asMap(data['sha256'], 'sha256').entries) {
      final name = safeRelative(entry.key);
      final asset = File(p.join(root.path, name));
      if (!asset.existsSync()) throw SplashException('快照素材缺失：$name');
      final bytes = asset.readAsBytesSync();
      if (sha256.convert(bytes).toString() != entry.value) {
        throw SplashException('快照素材校验失败：$name，请重新 sync');
      }
      assets[name] = bytes;
    }
    final frames = asMap(data['frames'], 'frames').map(
      (key, value) => MapEntry(key, DesignFrame.fromJson(asMap(value, key))),
    );
    if (!frames.containsKey('phone')) throw SplashException('快照缺少手机画板');
    final snapshot = DesignSnapshot(frames, data, assets);
    for (final frame in frames.values) {
      for (final layer in frame.layers.values) {
        snapshot.image(layer.asset);
      }
    }
    return snapshot;
  }
  img.Image image(String name) {
    final bytes = assets[name];
    if (bytes == null) throw SplashException('快照缺少素材：$name');
    final decoded = img.decodePng(Uint8List.fromList(bytes));
    if (decoded == null) throw SplashException('素材不是有效 PNG：$name');
    return decoded;
  }

  Map<String, List<int>> files() {
    final json = {
      ...metadata,
      'schemaVersion': 1,
      'frames': frames.map((key, value) => MapEntry(key, value.toJson())),
      'sha256': assets.map(
        (key, value) => MapEntry(key, sha256.convert(value).toString()),
      ),
    };
    return {
      ...assets,
      'snapshot.json': utf8.encode(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      ),
    };
  }
}

/// Shared fitting rules. Coordinates in the design are references, not device identities.
class FittedLayout {
  final DesignRect foreground, branding;
  FittedLayout(this.foreground, this.branding);
}

FittedLayout fitLayout(DesignSnapshot snapshot, double width, double height) {
  final phone = snapshot.frames['phone']!;
  final tablet = snapshot.frames['tablet'] ?? phone;
  final ratio = phone.width == tablet.width
      ? 0.0
      : ((width - phone.width) / (tablet.width - phone.width)).clamp(0.0, 1.0);
  double mix(double a, double b) => a + (b - a) * ratio;
  final source = width >= 600 ? tablet : phone;
  DesignRect fit(String role, double heightCap) {
    final a = phone.layers[role]!.rect, b = tablet.layers[role]!.rect;
    final aspect =
        source.layers[role]!.rect.width / source.layers[role]!.rect.height;
    final w = math.min(
      mix(a.width, b.width),
      math.min(math.max(1.0, width - 48), height * heightCap * aspect),
    );
    final offset = mix(
      a.x + a.width / 2 - phone.width / 2,
      b.x + b.width / 2 - tablet.width / 2,
    );
    final x = (width / 2 + offset - w / 2).clamp(
      16.0,
      math.max(16.0, width - w - 16),
    );
    return DesignRect(x.toDouble(), 0, w, w / aspect);
  }

  final fg = fit('foreground', .38), brand = fit('branding', .16);
  final a = phone.layers['foreground']!.rect,
      b = tablet.layers['foreground']!.rect;
  final centerY =
      mix(
        (a.y + a.height / 2) / phone.height,
        (b.y + b.height / 2) / tablet.height,
      ) *
      height;
  final ba = phone.layers['branding']!.rect,
      bb = tablet.layers['branding']!.rect;
  final bottom = math.max(
    16.0,
    mix(
          (phone.height - ba.y - ba.height) / phone.height,
          (tablet.height - bb.y - bb.height) / tablet.height,
        ) *
        height,
  );
  final brandY = height - bottom - brand.height;
  final fgY = (centerY - fg.height / 2).clamp(
    16.0,
    math.max(16.0, brandY - 32 - fg.height),
  );
  return FittedLayout(
    DesignRect(fg.x, fgY.toDouble(), fg.width, fg.height),
    DesignRect(brand.x, brandY, brand.width, brand.height),
  );
}
