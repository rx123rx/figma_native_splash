import 'dart:convert';
import 'config.dart';
import 'ohos.dart' show matchingEnd;

/// A small span reader for native JSON5 objects; edits preserve comments and
/// unrelated fields. Unsupported/ambiguous input fails before writing files.
class Json5Object {
  final String source;
  final int start, end;
  final Map<String, ({int start, int end})> properties = {};
  Json5Object(this.source, this.start)
    : end = matchingEnd(source, start, '{', '}') {
    var cursor = start + 1;
    while (true) {
      cursor = skip(source, cursor);
      if (cursor == end) break;
      final keyStart = cursor;
      String key;
      if (source[cursor] == '"' || source[cursor] == "'") {
        cursor = stringEnd(source, cursor);
        key = readString(source.substring(keyStart, cursor));
      } else {
        final match = RegExp(r'[A-Za-z_$][\w$]*').matchAsPrefix(source, cursor);
        if (match == null) throw SplashException('无法解析 JSON5 字段名');
        key = match.group(0)!;
        cursor = match.end;
      }
      cursor = skip(source, cursor);
      if (source[cursor] != ':') throw SplashException('JSON5 字段缺少冒号');
      cursor = skip(source, cursor + 1);
      final valueStart = cursor;
      if (source[cursor] == '{' || source[cursor] == '[') {
        cursor =
            matchingEnd(
              source,
              cursor,
              source[cursor],
              source[cursor] == '{' ? '}' : ']',
            ) +
            1;
      } else if (source[cursor] == '"' || source[cursor] == "'") {
        cursor = stringEnd(source, cursor);
      } else {
        while (cursor < end &&
            ![',', '}', '\n', '\r'].contains(source[cursor]) &&
            !source.startsWith('//', cursor) &&
            !source.startsWith('/*', cursor)) {
          cursor++;
        }
      }
      if (properties.containsKey(key)) throw SplashException('JSON5 字段重复：$key');
      properties[key] = (start: valueStart, end: cursor);
      cursor = skip(source, cursor);
      if (cursor == end) break;
      if (source[cursor] != ',') throw SplashException('JSON5 字段之间缺少逗号');
      cursor++;
    }
  }
  static int skip(String text, int offset) {
    while (offset < text.length) {
      if (text[offset].trim().isEmpty) {
        offset++;
      } else if (text.startsWith('//', offset)) {
        final next = text.indexOf('\n', offset + 2);
        offset = next < 0 ? text.length : next + 1;
      } else if (text.startsWith('/*', offset)) {
        final next = text.indexOf('*/', offset + 2);
        if (next < 0) throw SplashException('JSON5 注释未闭合');
        offset = next + 2;
      } else {
        break;
      }
    }
    if (offset >= text.length) throw SplashException('JSON5 内容不完整');
    return offset;
  }

  static int stringEnd(String text, int offset) {
    final quote = text[offset++];
    while (offset < text.length) {
      final char = text[offset++];
      if (char == quote) return offset;
      if (char == '\\') offset++;
    }
    throw SplashException('JSON5 字符串未闭合');
  }

  static String readString(String text) {
    if (text.startsWith('"')) return jsonDecode(text) as String;
    if (text.startsWith("'") && text.endsWith("'") && !text.contains('\\')) {
      return text.substring(1, text.length - 1);
    }
    throw SplashException('JSON5 名称必须使用字符串；复杂转义请改用双引号');
  }

  Json5Object object(String key) {
    final prop = properties[key];
    if (prop == null || source[prop.start] != '{') {
      throw SplashException('JSON5 缺少对象：$key');
    }
    return Json5Object(source, prop.start);
  }

  List<Json5Object> objects(String key) {
    final prop = properties[key];
    if (prop == null || source[prop.start] != '[') {
      throw SplashException('JSON5 缺少数组：$key');
    }
    var cursor = skip(source, prop.start + 1);
    final values = <Json5Object>[];
    while (source[cursor] != ']') {
      if (source[cursor] != '{') throw SplashException('$key 只支持对象数组');
      final object = Json5Object(source, cursor);
      values.add(object);
      cursor = skip(source, object.end + 1);
      if (source[cursor] == ',') {
        cursor = skip(source, cursor + 1);
      } else if (source[cursor] != ']') {
        throw SplashException('JSON5 数组缺少逗号');
      }
    }
    return values;
  }

  String? string(String key) {
    final prop = properties[key];
    return prop == null
        ? null
        : readString(source.substring(prop.start, prop.end).trim());
  }

  String setString(String key, String value) {
    final prop = properties[key];
    if (prop != null) {
      return source.replaceRange(prop.start, prop.end, jsonEncode(value));
    }
    return source.replaceRange(
      start + 1,
      start + 1,
      '\n${jsonEncode(key)}: ${jsonEncode(value)},',
    );
  }

  static Json5Object root(String text) {
    final offset = skip(text, 0);
    if (text[offset] != '{') throw SplashException('JSON5 根节点必须为对象');
    return Json5Object(text, offset);
  }
}
