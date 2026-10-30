import 'dart:io';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:figma_native_splash/src/xml_format.dart';
import 'support.dart';
import 'icon_support.dart';

/// 与 Flutter Android 模板一致：4 空格缩进、多属性换行、自闭合标签带空格。
/// 属性不超过 3 个的元素按 `xml` 包的固定内联写法给出，
/// 避免把包的限制当成回归。
const _manifest =
    '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:name=".LexueApplication"
        android:icon="@mipmap/old_icon"
        android:label="Demo"
        android:roundIcon="@mipmap/old_icon">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('figma-xml-format-'));
  tearDown(() => root.deleteSync(recursive: true));

  test('formatXml 使用 4 空格缩进、长属性换行、自闭合带空格', () {
    final text = formatXml(XmlDocument.parse(_manifest));
    expect(text, contains('\n    <uses-permission'));
    expect(text, contains('\n        <activity'));
    expect(text, contains('android.permission.INTERNET" />'));
    // 4 个属性超过单行阈值，应逐个换行并缩进 8 空格。
    expect(text, contains('\n    <application\n        android:name='));
    // 2 个属性仍内联，与原文件一致。
    expect(text, contains('<manifest xmlns:android='));
  });

  test('AndroidManifest.xml 生成后不重排原有风格', () {
    projectFixture(root);
    iconProjectFixture(root);
    write(root, 'android/app/src/main/AndroidManifest.xml', _manifest);
    final c = IconConfig.parse(
      iconYaml(platforms: '[android]', adaptive: false),
    );
    generateIcons(root, c, iconFixture(c)).apply();
    final text = File(
      p.join(root.path, 'android/app/src/main/AndroidManifest.xml'),
    ).readAsStringSync();
    expect(text, contains('android:icon="@mipmap/figma_icon"'));
    expect(text, contains('android:roundIcon="@mipmap/figma_icon"'));
    // 除图标属性外，缩进与换行应与手写版本一致。
    final expected = _manifest
        .replaceAll('@mipmap/old_icon', '@mipmap/figma_icon')
        .replaceAll(RegExp(r'\n\s*\n'), '\n');
    expect(text, expected);
  });
}
