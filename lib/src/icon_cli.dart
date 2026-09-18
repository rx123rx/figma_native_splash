import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'config.dart';
import 'figma.dart';
import 'icon_config.dart';
import 'icon_snapshot.dart';
import 'icon_generator.dart';
import 'output.dart';

Future<void> runIconCli(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      defaultsTo: Directory.current.path,
      help: 'Flutter 工程根目录',
    )
    ..addOption('config', defaultsTo: 'figma_splash.yaml', help: '项目内配置文件')
    ..addOption(
      'platform',
      allowed: ['android', 'ios', 'ohos'],
      help: '仅生成/检查所选平台',
    )
    ..addFlag('dry-run', negatable: false, help: '不写文件；sync 仍会联网')
    ..addFlag('help', abbr: 'h', negatable: false, help: '显示图标命令帮助');
  try {
    final args = parser.parse(arguments);
    if (args['help'] as bool) {
      stdout.writeln(
        'figma_native_splash icon <sync|create|check|preview> [options]\n${parser.usage}',
      );
      return;
    }
    if (args.rest.length != 1 ||
        !['sync', 'create', 'check', 'preview'].contains(args.rest.single)) {
      throw SplashException('请指定 icon sync、create、check 或 preview');
    }
    final action = args.rest.single;
    if (args['platform'] != null && !['create', 'check'].contains(action)) {
      throw SplashException('--platform 仅适用于 icon create/check');
    }
    final root = Directory(p.normalize(p.absolute(args['project'] as String)));
    final config = IconConfig.load(
      File(p.join(root.path, safeRelative(args['config'] as String))),
    );
    final dry = args['dry-run'] as bool;
    void previews(OutputPlan plan, IconSnapshot snapshot) {
      for (final entry in iconPreviews(config, snapshot).entries) {
        plan.bytes('.figma_splash/icon_previews/${entry.key}', entry.value);
      }
    }

    void apply(OutputPlan plan) {
      for (final path in plan.changes) {
        stdout.writeln('${plan.deletes.contains(path) ? '删除' : '更新'} $path');
      }
      final count = plan.changes.length;
      if (!dry) plan.apply();
      stdout.writeln('${dry ? '预计变化' : '已更新'} $count 个文件${dry ? '（未写入）' : ''}');
    }

    if (action == 'sync') {
      final client = http.Client();
      try {
        final snapshot = await fetchIcon(
          FigmaClient(client, resolveFigmaAccessToken(config.accessToken)),
          config,
        );
        final plan = OutputPlan(root);
        for (final entry in snapshot.files().entries) {
          plan.bytes('$iconSnapshotDirectory/${entry.key}', entry.value);
        }
        previews(plan, snapshot);
        apply(plan);
      } finally {
        client.close();
      }
      return;
    }
    final snapshot = IconSnapshot.load(root, config);
    if (action == 'preview') {
      final plan = OutputPlan(root);
      previews(plan, snapshot);
      apply(plan);
      return;
    }
    final platform = args['platform'] as String?;
    final plan = generateIcons(
      root,
      config,
      snapshot,
      platforms: platform == null ? null : [platform],
    );
    if (action == 'check') {
      if (plan.changes.isNotEmpty || plan.integrationIssues.isNotEmpty) {
        throw SplashException(
          '图标资源或工程接入尚未同步（${plan.changes.length} 个待更新文件），请执行 icon create；可先使用 --dry-run 查看',
        );
      }
      stdout.writeln('图标快照、资源及工程接入检查通过。未修改工程。');
    } else {
      apply(plan);
    }
  } on SplashException catch (e) {
    stderr.writeln('错误：$e');
    exitCode = 2;
  } on FormatException catch (e) {
    stderr.writeln('配置或文件格式错误：${e.message}');
    exitCode = 2;
  } on TimeoutException {
    stderr.writeln('图标下载超时，已保留原有快照');
    exitCode = 2;
  } on http.ClientException {
    stderr.writeln('图标网络请求失败，已保留原有快照');
    exitCode = 2;
  } on FileSystemException catch (e) {
    stderr.writeln('文件操作失败：${e.message}');
    exitCode = 2;
  }
}
