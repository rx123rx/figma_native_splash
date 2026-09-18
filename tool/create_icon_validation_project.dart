import 'dart:io';
import 'package:figma_native_splash/figma_native_splash.dart';
import '../test/icon_support.dart';
import '../test/support.dart' show write;

/// Synthetic fixtures only; never replaces an application's design snapshot.
void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('Provide a new output directory');
  final root = Directory(args.single);
  if (root.existsSync()) throw ArgumentError('Output directory must not exist');
  root.createSync(recursive: true);
  final yaml = iconYaml(monochrome: true),
      config = IconConfig.parse(iconYaml(monochrome: true));
  iconProjectFixture(root);
  write(root, 'figma_splash.yaml', yaml);
  final snapshot = iconFixture(config);
  saveIconSnapshot(root, snapshot);
  generateIcons(root, config, snapshot).apply();
  print(root.absolute.path);
}
