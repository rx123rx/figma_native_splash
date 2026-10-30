import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'config.dart';
import 'snapshot.dart';

/// 把快照里的原始素材重新编码成规范的 PNG。
///
/// 快照保存的是 Figma 导出的原文件，可能带 `pHYs` / `sRGB` / `gAMA` / `tEXt`
/// 等元数据，也可能使用索引色（`PLTE` + `tRNS`）。直接拼字节写进平台资源时，
/// 各端产物格式不一致，也容易被资源工具二次改写。按解码后的像素重新编码，
/// 保证同一图层在 Android、iOS、鸿蒙得到格式一致的 PNG。
List<int> normalizePng(List<int> bytes) {
  final image = img.decodePng(Uint8List.fromList(bytes));
  if (image == null) {
    throw SplashException('素材不是有效的 PNG，无法写入平台资源');
  }
  // encodePng 默认会把解码得到的 textData 写回 tEXt 块，平台资源不需要这些元数据。
  image.textData = null;
  return img.encodePng(image);
}

img.ColorRgb8 color(String value) => img.ColorRgb8(
  int.parse(value.substring(1, 3), radix: 16),
  int.parse(value.substring(3, 5), radix: 16),
  int.parse(value.substring(5, 7), radix: 16),
);
img.Image canvas(int width, int height, {String? background}) {
  final result = img.Image(width: width, height: height, numChannels: 4);
  if (background != null) img.fill(result, color: color(background));
  return result;
}

img.Image fitImage(img.Image source, int width, int height) {
  final factor = math.min(width / source.width, height / source.height);
  return img.copyResize(
    source,
    width: math.max(1, (source.width * factor).round()),
    height: math.max(1, (source.height * factor).round()),
    interpolation: img.Interpolation.cubic,
  );
}

img.Image systemIcon(img.Image source) {
  // Fit the full rectangle inside a radius-360 circle (system safe radius: 384).
  final factor =
      720 /
      math.sqrt(source.width * source.width + source.height * source.height);
  final scaled = img.copyResize(
    source,
    width: math.max(1, (source.width * factor).floor()),
    height: math.max(1, (source.height * factor).floor()),
    interpolation: img.Interpolation.cubic,
  );
  final result = canvas(1152, 1152);
  img.compositeImage(
    result,
    scaled,
    dstX: (1152 - scaled.width) ~/ 2,
    dstY: (1152 - scaled.height) ~/ 2,
  );
  return result;
}

img.Image systemBrand(img.Image source) {
  final result = canvas(800, 320), scaled = fitImage(source, 768, 288);
  img.compositeImage(
    result,
    scaled,
    dstX: (800 - scaled.width) ~/ 2,
    dstY: (320 - scaled.height) ~/ 2,
  );
  return result;
}

img.Image preview(
  DesignSnapshot snapshot,
  int width,
  int height,
  String background,
) {
  final frame =
      snapshot.frames[width >= 600 ? 'tablet' : 'phone'] ??
      snapshot.frames['phone']!;
  final source = snapshot.image(frame.layers['background']!.asset);
  final factor = math.max(width / source.width, height / source.height);
  final scaled = img.copyResize(
    source,
    width: (source.width * factor).ceil(),
    height: (source.height * factor).ceil(),
    interpolation: img.Interpolation.linear,
  );
  final result = canvas(width, height, background: background);
  final cropped = img.copyCrop(
    scaled,
    x: (scaled.width - width) ~/ 2,
    y: (scaled.height - height) ~/ 2,
    width: width,
    height: height,
  );
  img.compositeImage(result, cropped);
  final layout = fitLayout(snapshot, width.toDouble(), height.toDouble());
  for (final entry in {
    'foreground': layout.foreground,
    'branding': layout.branding,
  }.entries) {
    final image = fitImage(
      snapshot.image(frame.layers[entry.key]!.asset),
      entry.value.width.round(),
      entry.value.height.round(),
    );
    img.compositeImage(
      result,
      image,
      dstX: entry.value.x.round(),
      dstY: entry.value.y.round(),
    );
  }
  return result;
}
