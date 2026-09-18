import 'dart:convert';
import 'dart:math' as math;
import 'package:xml/xml.dart';
import 'config.dart';
import 'snapshot.dart';
import 'output.dart';
import 'ios_template.dart';
import 'artwork.dart';
import 'xcode_project.dart';

void generateIos(
  OutputPlan plan,
  SplashConfig config,
  DesignSnapshot snapshot,
) {
  final runner = config.paths['ios_runner']!, prefix = config.prefix;
  final phone = snapshot.frames['phone']!,
      tablet = snapshot.frames['tablet'] ?? phone;
  final names = {
    'background': '${prefix}_background',
    'foreground': '${prefix}_foreground',
    'branding': '${prefix}_branding',
  };
  for (final role in names.keys) {
    final folder = '$runner/Assets.xcassets/${names[role]}.imageset';
    final entries = <Map<String, String>>[];
    for (final entry in {
      'phone': phone,
      if (snapshot.frames.containsKey('tablet')) 'tablet': tablet,
    }.entries) {
      final filename = '${entry.key}.png';
      plan.bytes(
        '$folder/$filename',
        snapshot.assets[entry.value.layers[role]!.asset]!,
      );
      entries.add({
        'idiom': entry.key == 'phone' ? 'universal' : 'ipad',
        'filename': filename,
        'scale': '3x',
      });
    }
    plan.text(
      '$folder/Contents.json',
      '${const JsonEncoder.withIndent('  ').convert({
        'images': entries,
        'info': {'version': 1, 'author': 'figma_native_splash'},
      })}\n',
    );
  }
  final document = XmlDocument.parse(iosTemplate);
  XmlElement byId(String id) => document.descendants
      .whereType<XmlElement>()
      .singleWhere((e) => e.getAttribute('id') == id);
  void update(String id, Map<String, String> values) {
    for (final entry in values.entries) {
      byId(id).setAttribute(entry.key, entry.value);
    }
  }

  void curve(String id, double x1, double y1, double x2, double y2) {
    var slope = x2 == x1 ? 0.0 : (y2 - y1) / (x2 - x1);
    final intercept = y1 - slope * x1;
    // Auto Layout does not accept zero multipliers for relational dimensions.
    if (slope.abs() < 0.000001) slope = 0.000001;
    update(id, {
      'multiplier': slope.toStringAsFixed(6),
      'constant': intercept.toStringAsFixed(3),
    });
  }

  final fg = phone.layers['foreground']!.rect,
      tf = tablet.layers['foreground']!.rect;
  final brand = phone.layers['branding']!.rect,
      tb = tablet.layers['branding']!.rect;
  for (final pair in [(fg, tf), (brand, tb)]) {
    if ((pair.$1.width / pair.$1.height - pair.$2.width / pair.$2.height)
            .abs() >
        .02) {
      throw SplashException('iOS 第一版要求手机与 Pad 对应前景图层使用相同宽高比');
    }
  }
  update('headline-aspect', {'multiplier': '${fg.width}:${fg.height}'});
  update('brand-aspect', {'multiplier': '${brand.width}:${brand.height}'});
  update('headline-max-width', {
    'constant': math.max(fg.width, tf.width).toString(),
  });
  update('brand-max-width', {
    'constant': math.max(brand.width, tb.width).toString(),
  });
  curve(
    'headline-preferred-width',
    phone.width,
    fg.width,
    tablet.width,
    tf.width,
  );
  curve(
    'brand-preferred-width',
    phone.width,
    brand.width,
    tablet.width,
    tb.width,
  );
  curve(
    'headline-vertical-position',
    phone.height / 2,
    fg.y + fg.height / 2,
    tablet.height / 2,
    tf.y + tf.height / 2,
  );
  curve(
    'brand-preferred-bottom',
    phone.height,
    brand.y + brand.height,
    tablet.height,
    tb.y + tb.height,
  );
  update('headline-optical-center', {
    'constant': (fg.x + fg.width / 2 - phone.width / 2).toString(),
  });
  update('brand-center', {
    'constant': (brand.x + brand.width / 2 - phone.width / 2).toString(),
  });
  final mapping = {
    'LaunchBackground': names['background']!,
    'LaunchHeadline': names['foreground']!,
    'LaunchBrand': names['branding']!,
  };
  for (final element in document.descendants.whereType<XmlElement>()) {
    for (final attr in ['image', 'name']) {
      final original = element.getAttribute(attr);
      if (mapping.containsKey(original)) {
        element.setAttribute(attr, mapping[original]!);
      }
    }
  }
  final rgb = color(config.color);
  final background = byId('Ze5-6b-2t3').findElements('color').single;
  for (final entry in {'red': rgb.r, 'green': rgb.g, 'blue': rgb.b}.entries) {
    background.setAttribute(entry.key, (entry.value / 255).toStringAsFixed(6));
  }
  final storyboard = '${prefix}_LaunchScreen';
  integrateIosStoryboard(plan, runner, storyboard);
  plan.text(
    '$runner/Base.lproj/$storyboard.storyboard',
    '${document.toXmlString(pretty: true)}\n',
  );
  final plistPath = '$runner/Info.plist';
  final plist = XmlDocument.parse(plan.read(plistPath));
  final dict = plist.rootElement.findElements('dict').single;
  final elements = dict.childElements.toList();
  final keyIndex = elements.indexWhere(
    (e) => e.name.local == 'key' && e.innerText == 'UILaunchStoryboardName',
  );
  if (keyIndex < 0) {
    plan.integrationIssues.add(
      'Info.plist 缺少 UILaunchStoryboardName，请执行 create 修复',
    );
    dict.children.addAll([
      XmlElement(XmlName('key'), [], [XmlText('UILaunchStoryboardName')]),
      XmlElement(XmlName('string'), [], [XmlText(storyboard)]),
    ]);
  } else {
    if (keyIndex + 1 >= elements.length ||
        elements[keyIndex + 1].name.local != 'string') {
      throw SplashException('Info.plist 的 UILaunchStoryboardName 格式无效');
    }
    if (elements[keyIndex + 1].innerText != storyboard) {
      plan.integrationIssues.add('Info.plist 尚未指向生成的启动图，请执行 create 修复');
    }
    elements[keyIndex + 1].children
      ..clear()
      ..add(XmlText(storyboard));
  }
  plan.text(plistPath, '${plist.toXmlString(pretty: true)}\n', own: false);
}
