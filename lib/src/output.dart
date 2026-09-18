import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'config.dart';

class OutputPlan {
  final Directory project;
  final Map<String, List<int>> writes = {};
  final Set<String> owned = {};
  final Set<String> deletes = {};
  OutputPlan(this.project);
  String absolute(String relative) {
    final path = p.join(project.absolute.path, safeRelative(relative));
    var cursor = path;
    while (p.isWithin(project.absolute.path, cursor)) {
      if (FileSystemEntity.isLinkSync(cursor)) {
        throw SplashException('输出路径不能经过符号链接：$relative');
      }
      cursor = p.dirname(cursor);
    }
    return path;
  }

  void bytes(String path, List<int> bytes, {bool own = true}) {
    absolute(path);
    writes[path] = bytes;
    if (own) owned.add(path);
  }

  void text(String path, String text, {bool own = true}) =>
      bytes(path, utf8.encode(text), own: own);
  String read(String path) {
    if (writes.containsKey(path)) return utf8.decode(writes[path]!);
    final file = File(absolute(path));
    if (!file.existsSync()) throw SplashException('找不到工程文件：$path');
    return file.readAsStringSync();
  }

  void track(String platform, String prefix) {
    final manifestPath = '.figma_splash/generated_$platform.json';
    final manifest = File(absolute(manifestPath));
    final previous = manifest.existsSync()
        ? asMap(jsonDecode(manifest.readAsStringSync()), 'generated manifest')
        : <String, dynamic>{};
    if (previous.isNotEmpty && previous['prefix'] != prefix) {
      throw SplashException('resource_prefix 已变化，请先迁移旧资源，避免残留引用');
    }
    final hashes = asMap(previous['files'] ?? {}, 'generated files');
    for (final entry in hashes.entries) {
      final file = File(absolute(entry.key));
      if (file.existsSync() &&
          sha256.convert(file.readAsBytesSync()).toString() != entry.value) {
        throw SplashException('已生成文件被手动修改：${entry.key}。请保留改动并恢复该文件后再生成');
      }
      if (!owned.contains(entry.key)) deletes.add(entry.key);
    }
    for (final path in owned) {
      final file = File(absolute(path));
      if (!hashes.containsKey(path) &&
          file.existsSync() &&
          sha256.convert(file.readAsBytesSync()) !=
              sha256.convert(writes[path]!)) {
        throw SplashException('新资源与已有文件冲突：$path，请更换 resource_prefix');
      }
    }
    text(
      manifestPath,
      '${const JsonEncoder.withIndent('  ').convert({
        'prefix': prefix,
        'files': {for (final path in owned) path: sha256.convert(writes[path]!).toString()},
      })}\n',
      own: false,
    );
  }

  void merge(OutputPlan plan) {
    for (final entry in plan.writes.entries) {
      if (writes.containsKey(entry.key)) {
        throw SplashException('输出文件冲突：${entry.key}');
      }
      writes[entry.key] = entry.value;
    }
    deletes.addAll(plan.deletes);
  }

  List<String> get changes => [
    for (final entry in writes.entries)
      if (!File(absolute(entry.key)).existsSync() ||
          sha256.convert(File(absolute(entry.key)).readAsBytesSync()) !=
              sha256.convert(entry.value))
        entry.key,
    ...deletes.where((path) => File(absolute(path)).existsSync()),
  ]..sort();
  void apply() {
    final paths = changes;
    final before = {
      for (final path in paths)
        path: File(absolute(path)).existsSync()
            ? File(absolute(path)).readAsBytesSync()
            : null,
    };
    try {
      for (final path in paths) {
        final file = File(absolute(path));
        if (deletes.contains(path)) {
          file.deleteSync();
        } else {
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(writes[path]!, flush: true);
        }
      }
    } catch (_) {
      for (final entry in before.entries) {
        final file = File(absolute(entry.key));
        if (entry.value != null) {
          file.writeAsBytesSync(entry.value!, flush: true);
        } else if (file.existsSync()) {
          file.deleteSync();
        }
      }
      rethrow;
    }
  }
}
