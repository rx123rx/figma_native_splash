import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:figma_native_splash/figma_native_splash.dart';
import 'support.dart';

String iconYaml({
  String platforms = '[android, ios, ohos]',
  bool adaptive = true,
  bool monochrome = false,
  String extra = '',
}) =>
    '''figma:
  icon: https://www.figma.com/design/Example?node-id=1-2
icon:
  platforms: $platforms
  android:
    adaptive: $adaptive
    monochrome: $monochrome
$extra
''';

IconSnapshot iconFixture(IconConfig config) {
  final icon = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.fill(icon, color: img.ColorRgba8(15, 75, 160, 255));
  final foreground = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.fillRect(
    foreground,
    x1: 380,
    y1: 380,
    x2: 644,
    y2: 644,
    color: img.ColorRgba8(255, 140, 20, 255),
  );
  return IconSnapshot(
    {
      'icon.png': img.encodePng(icon),
      if (config.roles.contains('background'))
        'background.png': img.encodePng(icon),
      if (config.roles.contains('foreground'))
        'foreground.png': img.encodePng(foreground),
      if (config.roles.contains('monochrome'))
        'monochrome.png': img.encodePng(foreground),
    },
    {
      'sourceHash': config.sourceHash,
      'source': {
        'fileKey': 'Example',
        'nodeId': '1:2',
        'version': 'synthetic-test',
      },
    },
  );
}

void iconProjectFixture(Directory root) {
  projectFixture(root);
  final pbx = File(p.join(root.path, 'ios/Runner.xcodeproj/project.pbxproj'));
  pbx.writeAsStringSync(
    pbx
        .readAsStringSync()
        .replaceFirst(
          'name = Runner;',
          'name = Runner; buildConfigurationList = ICON_CONFIGS;',
        )
        .replaceFirst(
          'objects = {',
          '''objects = {
    ICON_CONFIGS = {isa = XCConfigurationList; buildConfigurations = (ICON_DEBUG,ICON_RELEASE,);};
    ICON_DEBUG = {isa = XCBuildConfiguration; name = Debug; buildSettings = {ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; DEVELOPMENT_TEAM = KEEP;};};
    ICON_RELEASE = {isa = XCBuildConfiguration; name = Release; buildSettings = {"ASSETCATALOG_COMPILER_APPICON_NAME[sdk=iphoneos*]" = OldIcon; PRODUCT_BUNDLE_IDENTIFIER = "com.example.app";};};''',
        ),
  );
  write(
    root,
    'android/app/src/main/AndroidManifest.xml',
    '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example.app"><application android:icon="@mipmap/ic_launcher"><activity android:name=".MainActivity" android:icon="@drawable/custom"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity><service android:name=".Unrelated" android:icon="@drawable/keep"/></application></manifest>''',
  );
  write(root, 'ohos/AppScope/app.json5', '''{
// app comment
app: {bundleName: 'com.example.app', icon: '\$media:old', vendor: 'Example', versionCode: 1}
}''');
}

void saveIconSnapshot(Directory root, IconSnapshot snapshot) {
  for (final entry in snapshot.files().entries) {
    final file = File(p.join(root.path, iconSnapshotDirectory, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value);
  }
}
