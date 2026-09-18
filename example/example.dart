import 'package:figma_native_splash/figma_native_splash.dart';

/// Parse configuration without contacting Figma or modifying an application.
void main() {
  final config = SplashConfig.parse('''
splash:
  figma:
    phone: https://www.figma.com/design/ExampleFileKey/Launch?node-id=1-2
  platforms: [android, ios]
  ohos:
    app_splash: false
''');
  print('Platforms: ${config.platforms.join(', ')}');
  print('Resource prefix: ${config.prefix}');
  print('OHOS app splash: ${config.ohosAppSplash}');
}
