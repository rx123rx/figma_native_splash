import 'package:xml/xml.dart';

/// 把 XML 文档序列化成接近工程原有风格的文本。
///
/// `xml` 包默认把属性全部挤在一行、丢掉空行、自闭合标签写成 `/>`。
/// AndroidManifest.xml 这类由开发者手工维护的文件被整份重排后，
/// 每次生成都会产生上百行格式 diff，掩盖真正的改动。这里：
///
/// - 缩进默认 4 空格，与 Flutter Android 模板一致；
/// - 元素属性超过 [inlineAttributeLimit] 个时，每个属性独占一行；
/// - 自闭合标签在 `/` 前保留一个空格（`<x />`）。
///
/// 空行无法通过 writer 参数保留（`xml` 包会丢弃纯空白文本节点），
/// 生成后的文件因此比手写版本更紧凑，但缩进与属性换行与原文一致。
String formatXml(
  XmlDocument document, {
  String indent = '    ',
  int inlineAttributeLimit = 3,
}) {
  return '${document.toXmlString(pretty: true, indent: indent, newLine: '\n', spaceBeforeSelfClose: (_) => true, indentAttribute: (attribute) {
    final element = attribute.parentElement;
    if (element == null) return false;
    return element.attributes.length > inlineAttributeLimit;
  })}\n';
}
