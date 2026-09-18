// Generates a disposable project fixture for native compiler checks.
// Uses synthetic artwork only; no network access or private design assets.
import 'dart:io';
import 'package:figma_native_splash/figma_native_splash.dart';
import '../test/support.dart' as support;

void main(List<String> args) {
  if (args.isEmpty) {
    throw ArgumentError(
      'Usage: dart run tool/create_validation_project.dart OUTPUT',
    );
  }
  final root = Directory(args.first);
  if (root.existsSync()) throw ArgumentError('OUTPUT must not exist');
  root.createSync(recursive: true);
  support.projectFixture(root);
  final config = support.config(
    extra: 'background_color: "#FFE7CC"\nohos:\n  app_splash: true',
  );
  final snapshot = support.fixture(config);
  support.saveSnapshot(root, snapshot);
  support.write(root, 'figma_splash.yaml', '''figma:
  phone: https://www.figma.com/design/Example?node-id=1-2
  tablet: https://www.figma.com/design/Example?node-id=1-3
background_color: "#FFE7CC"
ohos:
  app_splash: true
''');
  generate(root, config, snapshot).apply();
  print(root.path);
}
