import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'snapshot.dart';

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
