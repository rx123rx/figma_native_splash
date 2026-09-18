import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'config.dart';
import 'snapshot.dart';
import 'output.dart';
import 'artwork.dart';

/// Locate matching delimiters while ignoring comments and quoted literals.
int matchingEnd(String source, int start, String open, String close) {
  var depth = 0;
  String? quote;
  var line = false, block = false;
  for (var i = start; i < source.length; i++) {
    final c = source[i], next = i + 1 < source.length ? source[i + 1] : '';
    if (line) {
      if (c == '\n') line = false;
      continue;
    }
    if (block) {
      if (c == '*' && next == '/') {
        block = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (c == '\\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && next == '/') {
      line = true;
      i++;
      continue;
    }
    if (c == '/' && next == '*') {
      block = true;
      i++;
      continue;
    }
    if (c == '"' || c == "'" || c == '`') {
      quote = c;
      continue;
    }
    if (c == open) depth++;
    if (c == close) {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw SplashException('无法解析原生文件的括号边界');
}

void generateOhos(
  OutputPlan plan,
  SplashConfig config,
  DesignSnapshot snapshot,
) {
  final main = config.paths['ohos_main']!,
      page = config.paths['ohos_page']!,
      prefix = config.prefix;
  final phone = snapshot.frames['phone']!,
      tablet = snapshot.frames['tablet'] ?? phone;
  if (config.ohosAppSplash) {
    for (final entry in {'phone': phone, 'tablet': tablet}.entries) {
      for (final role in ['background', 'foreground', 'branding']) {
        plan.bytes(
          '$main/resources/base/media/${prefix}_${entry.key}_$role.png',
          snapshot.assets[entry.value.layers[role]!.asset]!,
        );
      }
    }
  }
  plan.bytes(
    '$main/resources/base/media/${prefix}_icon.png',
    img.encodePng(systemIcon(snapshot.image(phone.layers['branding']!.asset))),
  );
  plan.text(
    '$main/resources/base/element/${prefix}_colors.json',
    '${jsonEncode({
      'color': [
        {'name': '${prefix}_surface', 'value': config.color},
      ],
    })}\n',
  );
  final modulePath = '$main/module.json5';
  var module = plan.read(modulePath);
  final ability = RegExp(
    '"name"\\s*:\\s*"${RegExp.escape(config.ability)}"',
  ).allMatches(module).toList();
  if (ability.length != 1) {
    throw SplashException('找不到唯一鸿蒙 Ability：${config.ability}');
  }
  final start = module.lastIndexOf('{', ability.single.start),
      end = matchingEnd(module, start, '{', '}');
  var body = module.substring(start, end + 1);
  for (final entry in {
    'startWindowIcon': '\$media:${prefix}_icon',
    'startWindowBackground': '\$color:${prefix}_surface',
  }.entries) {
    final pattern = RegExp('"${entry.key}"\\s*:\\s*"[^"\\n]*"');
    if (pattern.allMatches(body).length > 1) {
      throw SplashException('鸿蒙 ${entry.key} 重复');
    }
    if (pattern.hasMatch(body)) {
      body = body.replaceFirst(pattern, '"${entry.key}": "${entry.value}"');
    } else {
      body = body.replaceFirst(
        '{',
        '{\n        "${entry.key}": "${entry.value}",',
      );
    }
  }
  module = module.replaceRange(start, end + 1, body);
  plan.text(modulePath, module, own: false);
  final viewPath = '$main/ets/figma_splash/FigmaSplash.ets';
  var importPath = p
      .withoutExtension(p.relative(viewPath, from: p.dirname(page)))
      .replaceAll('\\', '/');
  if (!importPath.startsWith('.')) importPath = './$importPath';
  final importLine = "import { FigmaSplash } from '$importPath';";
  if (!config.ohosAppSplash) {
    // Only remove integration inserted by this tool. Existing custom builders
    // belong to the host application and must remain untouched.
    if (!File(plan.absolute(page)).existsSync()) return;
    var pageText = plan.read(page);
    if (!pageText.contains(importLine)) {
      if (RegExp(r'\bFigmaSplash\b').hasMatch(pageText)) {
        throw SplashException('FigmaSplash 接入已被修改，请检查引用后关闭 app_splash');
      }
      return;
    }
    final calls = RegExp(
      r'\bFlutterPage\s*\(\s*\{',
    ).allMatches(pageText).toList();
    if (calls.length != 1) {
      throw SplashException('关闭鸿蒙 app_splash 时无法定位唯一 FlutterPage，请检查生成器的接入引用');
    }
    final start = pageText.indexOf('{', calls.single.start);
    final end = matchingEnd(pageText, start, '{', '}');
    var args = pageText.substring(start, end + 1);
    final property = RegExp(
      r'\bsplashScreenView\s*:\s*FigmaSplash\s*(?=[,}])[,]?',
    );
    args = args.replaceFirst(property, '');
    pageText = pageText
        .replaceRange(start, end + 1, args)
        .replaceFirst('$importLine\n', '')
        .replaceFirst(importLine, '');
    if (RegExp(r'\bFigmaSplash\b').hasMatch(pageText)) {
      throw SplashException('FigmaSplash 仍有其他引用，关闭 app_splash 前请先处理这些引用');
    }
    plan.text(page, pageText, own: false);
    return;
  }
  var pageText = plan.read(page);
  final calls = RegExp(
    r'\bFlutterPage\s*\(\s*\{',
  ).allMatches(pageText).toList();
  if (calls.length != 1) {
    throw SplashException(
      '鸿蒙页面需有唯一 FlutterPage({...})，自定义页面请指定 project.ohos_page',
    );
  }
  final call = calls.single,
      objectStart = pageText.indexOf('{', call.start),
      objectEnd = matchingEnd(pageText, objectStart, '{', '}');
  var args = pageText.substring(objectStart, objectEnd + 1);
  final property = RegExp(
    r'splashScreenView\s*:\s*([a-zA-Z_$][\w$]*(?:\.[a-zA-Z_$][\w$]*)*)\s*(?=[,}])',
  );
  if (args.contains('splashScreenView') && !property.hasMatch(args)) {
    throw SplashException('splashScreenView 为复杂表达式，请先改为 builder 引用后生成');
  }
  if (property.hasMatch(args)) {
    args = args.replaceFirst(property, 'splashScreenView: FigmaSplash');
  } else {
    args = args.replaceFirst('{', '{\n        splashScreenView: FigmaSplash,');
  }
  pageText = pageText.replaceRange(objectStart, objectEnd + 1, args);
  if (!pageText.contains(importLine)) {
    if (RegExp(
      r'\bFigmaSplash\b',
    ).hasMatch(pageText.substring(0, call.start))) {
      throw SplashException('FigmaSplash 名称已被使用');
    }
    pageText = '$importLine\n$pageText';
  }
  plan.text(page, pageText, own: false);
  String rect(DesignRect r) => '[${r.x}, ${r.y}, ${r.width}, ${r.height}]';
  plan.text(viewPath, '''// Generated by figma_native_splash. Do not edit.
const PHONE: number[] = [${phone.width}, ${phone.height}];
const TABLET: number[] = [${tablet.width}, ${tablet.height}];
const PHONE_FOREGROUND: number[] = ${rect(phone.layers['foreground']!.rect)};
const TABLET_FOREGROUND: number[] = ${rect(tablet.layers['foreground']!.rect)};
const PHONE_BRANDING: number[] = ${rect(phone.layers['branding']!.rect)};
const TABLET_BRANDING: number[] = ${rect(tablet.layers['branding']!.rect)};

@Component
struct FigmaSplashView {
  @State areaWidth: number = PHONE[0];
  @State areaHeight: number = PHONE[1];

  private mix(a: number, b: number): number {
    const t = TABLET[0] === PHONE[0] ? 0 : Math.max(0, Math.min(1, (this.areaWidth - PHONE[0]) / (TABLET[0] - PHONE[0])));
    return a + (b - a) * t;
  }

  private frame(branding: boolean): number[] {
    const a = branding ? PHONE_BRANDING : PHONE_FOREGROUND;
    const b = branding ? TABLET_BRANDING : TABLET_FOREGROUND;
    const source = this.areaWidth >= 600 ? b : a;
    const aspect = source[2] / source[3];
    const width = Math.min(this.mix(a[2], b[2]), Math.max(1, this.areaWidth - 48), this.areaHeight * (branding ? 0.16 : 0.38) * aspect);
    const height = width / aspect;
    const shift = this.mix(a[0] + a[2] / 2 - PHONE[0] / 2, b[0] + b[2] / 2 - TABLET[0] / 2);
    const x = Math.max(16, Math.min(this.areaWidth - width - 16, this.areaWidth / 2 + shift - width / 2));
    if (branding) {
      const bottom = Math.max(16, this.mix((PHONE[1] - a[1] - a[3]) / PHONE[1], (TABLET[1] - b[1] - b[3]) / TABLET[1]) * this.areaHeight);
      return [x, this.areaHeight - bottom - height, width, height];
    }
    const centerY = this.mix((a[1] + a[3] / 2) / PHONE[1], (b[1] + b[3] / 2) / TABLET[1]) * this.areaHeight;
    const brand = this.frame(true);
    return [x, Math.max(16, Math.min(centerY - height / 2, brand[1] - 32 - height)), width, height];
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(this.areaWidth >= 600 ? \$r('app.media.${prefix}_tablet_background') : \$r('app.media.${prefix}_phone_background'))
        .width('100%').height('100%').objectFit(ImageFit.Cover)
      Image(this.areaWidth >= 600 ? \$r('app.media.${prefix}_tablet_foreground') : \$r('app.media.${prefix}_phone_foreground'))
        .width(this.frame(false)[2]).height(this.frame(false)[3]).objectFit(ImageFit.Contain)
        .position({ x: this.frame(false)[0], y: this.frame(false)[1] })
      Image(this.areaWidth >= 600 ? \$r('app.media.${prefix}_tablet_branding') : \$r('app.media.${prefix}_phone_branding'))
        .width(this.frame(true)[2]).height(this.frame(true)[3]).objectFit(ImageFit.Contain)
        .position({ x: this.frame(true)[0], y: this.frame(true)[1] })
    }
    .width('100%').height('100%').backgroundColor('${config.color}')
    .onAreaChange((_oldArea: Area, area: Area) => {
      this.areaWidth = Math.max(1, parseFloat(area.width.toString()));
      this.areaHeight = Math.max(1, parseFloat(area.height.toString()));
    })
  }
}

@Builder
export function FigmaSplash() {
  FigmaSplashView()
}
''');
}
