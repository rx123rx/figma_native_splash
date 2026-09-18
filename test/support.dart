import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:figma_native_splash/figma_native_splash.dart';

SplashConfig config({String extra = '', bool tablet = true}) =>
    SplashConfig.parse('''
figma:
  phone: https://www.figma.com/design/Example?node-id=1-2
  ${tablet ? 'tablet: https://www.figma.com/design/Example?node-id=1-3' : ''}
$extra
''');
List<int> png(int width, int height) => img.encodePng(
  img.fill(
    img.Image(width: width, height: height, numChannels: 4),
    color: img.ColorRgba8(245, 125, 35, 255),
  ),
);
DesignSnapshot fixture(SplashConfig config) {
  final assets = <String, List<int>>{};
  final frames = <String, DesignFrame>{};
  for (final name in config.frames.keys) {
    final tablet = name == 'tablet',
        width = name == 'tablet' ? 834.0 : 375.0,
        height = name == 'tablet' ? 1194.0 : 812.0;
    final fw = tablet ? 350.0 : 227.0, bw = tablet ? 272.0 : 148.0;
    final rects = {
      'background': DesignRect(0, 0, width, height),
      'foreground': DesignRect(
        (width - fw) / 2 + 10,
        height * .38 - fw * .88 / 2,
        fw,
        fw * .88,
      ),
      'branding': DesignRect(
        (width - bw) / 2,
        height - 60 - bw / 3,
        bw,
        bw / 3,
      ),
    };
    frames[name] = DesignFrame(width, height, {
      for (final entry in rects.entries)
        entry.key: DesignLayer(
          '$name-${entry.key}',
          '$name/${entry.key}.png',
          entry.value,
        ),
    });
    for (final layer in frames[name]!.layers.values) {
      assets[layer.asset] = png(
        layer.rect.width.round(),
        layer.rect.height.round(),
      );
    }
  }
  return DesignSnapshot(frames, {
    'sourceHash': config.sourceHash,
    'sources': {'test': 'synthetic fixture, not live Figma'},
  }, assets);
}

void write(Directory root, String path, String text) {
  final file = File(p.join(root.path, path));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text);
}

void projectFixture(Directory root) {
  write(root, 'android/app/src/main/res/values/styles.xml', '''<resources>
<style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowFullscreen">false</item></style>
<style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar"><item name="android:windowBackground">?android:colorBackground</item></style>
</resources>''');
  write(
    root,
    'ios/Runner/Info.plist',
    '''<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.example.demo</string><key>UILaunchStoryboardName</key><string>LaunchScreen</string></dict></plist>''',
  );
  write(root, 'ohos/entry/src/main/module.json5', '''{
// keep comment
"module":{"name":"entry","abilities":[{"name":"EntryAbility","icon":"\$media:icon","startWindowIcon":"\$media:icon","startWindowBackground":"\$color:white",}],"requestPermissions":[{"name":"ohos.permission.INTERNET"}]}}
''');
  write(
    root,
    'ohos/entry/src/main/ets/pages/Index.ets',
    "import { FlutterPage } from '@ohos/flutter_ohos';\n@Entry\n@Component\nstruct Index { build() { Column() { FlutterPage({ viewId: this.viewId, }) } } onBackPress(): boolean { return true; } }\n",
  );
}

void saveSnapshot(Directory root, DesignSnapshot snapshot) {
  for (final entry in snapshot.files().entries) {
    final f = File(p.join(root.path, snapshotDirectory, entry.key));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(entry.value);
  }
}
