import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'config.dart';
import 'output.dart';

// Parse OpenStep plist syntax while retaining source spans. Only the needed
// arrays and object entries are patched; build settings and comments survive.
class _Value {
  final int start, end;
  final Object value;
  _Value(this.start, this.end, this.value);
  Map<String, _Value> get map => value is Map<String, _Value>
      ? value as Map<String, _Value>
      : throw SplashException('Xcode 工程字段应为字典');
  List<_Value> get list => value is List<_Value>
      ? value as List<_Value>
      : throw SplashException('Xcode 工程字段应为列表');
  String get string => value is String
      ? value as String
      : throw SplashException('Xcode 工程字段应为字符串');
}

class _Parser {
  final String source;
  int offset = 0;
  _Parser(this.source);
  Never fail() =>
      throw SplashException('无法解析 Xcode project.pbxproj（位置 $offset）');
  void skip() {
    while (offset < source.length) {
      if (source[offset].trim().isEmpty) {
        offset++;
      } else if (source.startsWith('/*', offset)) {
        final end = source.indexOf('*/', offset + 2);
        if (end < 0) fail();
        offset = end + 2;
      } else if (source.startsWith('//', offset)) {
        final end = source.indexOf('\n', offset + 2);
        offset = end < 0 ? source.length : end + 1;
      } else {
        break;
      }
    }
  }

  void expect(String token) {
    skip();
    if (!source.startsWith(token, offset)) fail();
    offset += token.length;
  }

  _Value read() {
    skip();
    final start = offset;
    if (offset >= source.length) fail();
    final char = source[offset];
    if (char == '{') {
      offset++;
      final values = <String, _Value>{};
      while (true) {
        skip();
        if (offset >= source.length) fail();
        if (source[offset] == '}') {
          offset++;
          return _Value(start, offset, values);
        }
        final key = read().string;
        if (values.containsKey(key)) fail();
        expect('=');
        values[key] = read();
        expect(';');
      }
    }
    if (char == '(') {
      offset++;
      final values = <_Value>[];
      while (true) {
        skip();
        if (offset >= source.length) fail();
        if (source[offset] == ')') {
          offset++;
          return _Value(start, offset, values);
        }
        values.add(read());
        skip();
        if (offset < source.length && source[offset] == ',') {
          offset++;
        } else if (offset >= source.length || source[offset] != ')') {
          fail();
        }
      }
    }
    if (char == '"') {
      offset++;
      final text = StringBuffer();
      while (offset < source.length) {
        var char = source[offset++];
        if (char == '"') return _Value(start, offset, text.toString());
        if (char == '\\') {
          if (offset >= source.length) fail();
          char = source[offset++];
          char = switch (char) {
            'n' => '\n',
            'r' => '\r',
            't' => '\t',
            _ => char,
          };
        }
        text.write(char);
      }
      fail();
    }
    while (offset < source.length &&
        !RegExp(r'[\s{}()=;,]').hasMatch(source[offset]) &&
        !source.startsWith('/*', offset) &&
        !source.startsWith('//', offset)) {
      offset++;
    }
    if (start == offset) fail();
    return _Value(start, offset, source.substring(start, offset));
  }
}

/// Register the generated storyboard in the selected app target's Resources.
/// Ambiguous projects are rejected before any output is written.
void integrateIosStoryboard(OutputPlan plan, String runner, String storyboard) {
  final parent = p.dirname(runner);
  final directory = Directory(plan.absolute(parent));
  if (!directory.existsSync()) throw SplashException('找不到 iOS 工程目录：$parent');
  final projects = directory
      .listSync(followLinks: false)
      .where((entry) => entry.path.endsWith('.xcodeproj'))
      .toList();
  if (projects.length != 1) {
    throw SplashException(
      'iOS Runner 同级目录必须有唯一 .xcodeproj，实际找到 ${projects.length} 个',
    );
  }
  final projectPath = p.join(
    parent,
    p.basename(projects.single.path),
    'project.pbxproj',
  );
  final source = plan.read(projectPath);
  final parser = _Parser(source);
  final root = parser.read();
  parser.skip();
  if (parser.offset != source.length) parser.fail();
  final objectsValue = root.map['objects'];
  if (objectsValue == null) throw SplashException('Xcode 工程缺少 objects');
  final objects = objectsValue.map;
  _Value object(String id) =>
      objects[id] ?? (throw SplashException('Xcode 工程引用不存在的对象：$id'));
  String? field(_Value value, String key) => value.map[key]?.string;
  List<String> ids(_Value value, String key) =>
      value.map[key]?.list.map((v) => v.string).toList() ?? [];
  final projectId = root.map['rootObject']?.string;
  if (projectId == null) throw SplashException('Xcode 工程缺少 rootObject');
  final project = object(projectId);
  final apps = ids(project, 'targets').where((id) {
    final target = object(id);
    return field(target, 'isa') == 'PBXNativeTarget' &&
        field(target, 'productType') == 'com.apple.product-type.application';
  }).toList();
  final named = apps
      .where((id) => field(object(id), 'name') == p.basename(runner))
      .toList();
  final selected = named.isEmpty ? apps : named;
  if (selected.length != 1) {
    throw SplashException(
      '无法唯一确定 iOS 应用 Target，请确保应用 Target 名称与 ios_runner 目录名一致',
    );
  }
  final target = object(selected.single);
  if (ids(target, 'fileSystemSynchronizedGroups').isNotEmpty) {
    throw SplashException('暂不支持 Xcode 自动同步文件夹 Target，请先将应用源码组转换为普通 Group');
  }
  final mainId = field(project, 'mainGroup');
  if (mainId == null) throw SplashException('Xcode 工程缺少 mainGroup');
  final main = object(mainId);
  final expected = p.normalize(
    p.join(
      p.relative(runner, from: parent),
      'Base.lproj',
      '$storyboard.storyboard',
    ),
  );
  final candidates = <String>{};
  final active = <String>{};
  void walk(String id, String base, String? variant) {
    if (!active.add(id)) throw SplashException('Xcode Group 引用存在循环');
    final node = object(id), type = field(object(id), 'isa');
    final tree = field(node, 'sourceTree') ?? '<group>';
    final path = field(node, 'path') ?? '';
    if (!['<group>', 'SOURCE_ROOT'].contains(tree)) {
      active.remove(id);
      return;
    }
    final resolved = p.normalize(
      p.join(tree == 'SOURCE_ROOT' ? '.' : base, path),
    );
    if (type == 'PBXFileReference' && resolved == expected) {
      if (variant != null &&
          field(object(variant), 'name') != '$storyboard.storyboard') {
        throw SplashException(
          '启动图本地化组名称与生成的 Storyboard 不一致，请先修正 Xcode Group 名称',
        );
      }
      candidates.add(variant ?? id);
    } else if (type == 'PBXGroup' || type == 'PBXVariantGroup') {
      for (final child in ids(node, 'children')) {
        walk(child, resolved, type == 'PBXVariantGroup' ? id : variant);
      }
    }
    active.remove(id);
  }

  walk(mainId, '.', null);
  if (candidates.length > 1) throw SplashException('Xcode 中存在多个指向生成启动图的文件引用');
  final resourcePhases = ids(target, 'buildPhases')
      .where((id) => field(object(id), 'isa') == 'PBXResourcesBuildPhase')
      .toList();
  if (resourcePhases.length > 1) {
    throw SplashException('应用 Target 存在多个 Resources 阶段');
  }
  final additions = StringBuffer();
  final usedIds = objects.keys.toSet();
  String newId(String role) {
    var salt = 0;
    while (true) {
      final id = sha256
          .convert(utf8.encode('$expected:${selected.single}:$role:${salt++}'))
          .toString()
          .substring(0, 24)
          .toUpperCase();
      if (usedIds.add(id)) return id;
    }
  }

  final edits = <({int start, int end, String text})>[];
  void append(_Value owner, String key, String id) {
    final existing = owner.map[key];
    if (existing == null) {
      edits.add((
        start: owner.end - 1,
        end: owner.end - 1,
        text: '\n\t\t\t$key = ($id,);\n\t\t',
      ));
    } else {
      final list = existing.list;
      // Preserve comments after the last item; accept arrays without a trailing comma.
      if (list.isNotEmpty) {
        final tail = _Parser(source.substring(list.last.end, existing.end - 1));
        tail.skip();
        if (tail.offset == tail.source.length) {
          edits.add((start: list.last.end, end: list.last.end, text: ','));
        }
      }
      edits.add((
        start: existing.end - 1,
        end: existing.end - 1,
        text: '\n\t\t\t\t$id,\n\t\t\t',
      ));
    }
  }

  var ref = candidates.singleOrNull;
  if (ref == null) {
    ref = newId('file');
    // SOURCE_ROOT avoids depending on a particular user-visible Group layout.
    additions.writeln(
      '\t\t$ref = {isa = PBXFileReference; lastKnownFileType = file.storyboard; path = ${jsonEncode(expected)}; sourceTree = SOURCE_ROOT; };',
    );
    append(main, 'children', ref);
  }
  final phase = resourcePhases.isEmpty ? null : object(resourcePhases.single);
  if (phase != null &&
      (field(phase, 'runOnlyForDeploymentPostprocessing') == '1' ||
          field(phase, 'buildActionMask') == '0')) {
    throw SplashException('应用 Resources 阶段被限制为非普通构建，无法保证启动图打包');
  }
  final matching = phase == null
      ? <String>[]
      : ids(
          phase,
          'files',
        ).where((id) => field(object(id), 'fileRef') == ref).toList();
  if (matching.length > 1) throw SplashException('生成启动图在应用 Resources 中被重复打包');
  if (matching.isNotEmpty &&
      (object(matching.single).map.containsKey('platformFilters') ||
          object(matching.single).map.containsKey('platformFilter'))) {
    throw SplashException('启动图 Resources 引用带 platformFilters，请移除平台限制后重试');
  }
  if (matching.isEmpty) {
    final build = newId('build');
    additions.writeln('\t\t$build = {isa = PBXBuildFile; fileRef = $ref; };');
    if (phase != null) {
      append(phase, 'files', build);
    } else {
      final phaseId = newId('resources');
      additions.writeln(
        '\t\t$phaseId = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ($build,); runOnlyForDeploymentPostprocessing = 0; };',
      );
      append(target, 'buildPhases', phaseId);
    }
  }
  if (additions.isNotEmpty) {
    edits.add((
      start: objectsValue.end - 1,
      end: objectsValue.end - 1,
      text: '\n$additions\t',
    ));
  }
  if (edits.isEmpty) return;
  edits.sort((a, b) => b.start.compareTo(a.start));
  var updated = source;
  for (final edit in edits) {
    updated = updated.replaceRange(edit.start, edit.end, edit.text);
  }
  plan.text(projectPath, updated, own: false);
  plan.integrationIssues.add(
    'iOS 启动图尚未注册到应用 Resources：$projectPath；请执行 create 修复',
  );
}
