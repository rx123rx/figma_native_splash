import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'config.dart';
import 'figma.dart';
import 'snapshot.dart';
import 'generator.dart';
import 'output.dart';
import 'artwork.dart';

Future<void> runCli(List<String> arguments, {String? command}) async {
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
      help: '仅生成所选平台',
    )
    ..addFlag('dry-run', negatable: false, help: '仅列出将变化的文件，不写入')
    ..addFlag('help', abbr: 'h', negatable: false, help: '显示帮助');
  try {
    final args = parser.parse(arguments);
    if (args['help'] as bool) {
      stdout.writeln(
        'figma_native_splash <sync|create|check|preview> [options]\n${parser.usage}',
      );
      return;
    }
    final action = command ?? (args.rest.isNotEmpty ? args.rest.first : 'help');
    if ((command == null && args.rest.length > 1) ||
        (command != null && args.rest.isNotEmpty)) {
      throw SplashException('存在多余的位置参数');
    }
    if (!['sync', 'create', 'check', 'preview'].contains(action)) {
      throw SplashException('请指定 sync、create、check 或 preview，使用 --help 查看帮助');
    }
    if (args['platform'] != null && !['create', 'check'].contains(action)) {
      throw SplashException(
        '--platform 仅适用于 create 和 check；sync/preview 处理完整设计快照',
      );
    }
    final project = Directory(
      p.normalize(p.absolute(args['project'] as String)),
    );
    final config = SplashConfig.load(
      File(p.join(project.path, safeRelative(args['config'] as String))),
    );
    final dryRun = args['dry-run'] as bool;
    if (action == 'sync') {
      final client = http.Client();
      try {
        final snapshot = await FigmaClient(
          client,
          Platform.environment['FIGMA_ACCESS_TOKEN'] ?? '',
        ).fetch(config);
        final plan = OutputPlan(project);
        for (final entry in snapshot.files().entries) {
          plan.bytes('$snapshotDirectory/${entry.key}', entry.value);
        }
        _previews(plan, snapshot, config);
        _apply(plan, dryRun);
        stdout.writeln(
          dryRun ? '同步预览完成，未保存快照' : '设计快照与构图预览已保存。执行 create 生成原生资源。',
        );
      } finally {
        client.close();
      }
      return;
    }
    final snapshot = DesignSnapshot.load(project, config);
    if (action == 'preview') {
      final plan = OutputPlan(project);
      _previews(plan, snapshot, config);
      _apply(plan, dryRun);
      return;
    }
    final platform = args['platform'] as String?;
    final plan = generate(
      project,
      config,
      snapshot,
      platforms: platform == null ? null : [platform],
    );
    if (action == 'check') {
      stdout.writeln(
        '配置、素材哈希、工程接入和输出冲突检查通过；待更新文件 ${plan.changes.length} 个。未修改工程。',
      );
    } else {
      _apply(plan, dryRun);
    }
  } on SplashException catch (error) {
    stderr.writeln('错误：$error');
    exitCode = 2;
  } on FormatException catch (error) {
    stderr.writeln('配置或文件格式错误：${error.message}');
    exitCode = 2;
  } on TimeoutException {
    stderr.writeln('网络请求超时，已保留原有快照，请稍后重试');
    exitCode = 2;
  } on http.ClientException {
    stderr.writeln('网络请求失败，请检查网络后重试');
    exitCode = 2;
  } on FileSystemException catch (error) {
    stderr.writeln('文件操作失败：${error.message}');
    exitCode = 2;
  }
}

void _apply(OutputPlan plan, bool dryRun) {
  final changes = plan.changes;
  for (final path in changes) {
    stdout.writeln('${plan.deletes.contains(path) ? '删除' : '更新'} $path');
  }
  if (!dryRun) plan.apply();
  stdout.writeln(
    '${dryRun ? '预计变化' : '已更新'} ${changes.length} 个文件${dryRun ? '（未写入）' : ''}',
  );
}

void _previews(OutputPlan plan, DesignSnapshot snapshot, SplashConfig config) {
  final sizes = {
    'phone_portrait': [375, 812],
    'phone_landscape': [812, 375],
    'tablet_portrait': [834, 1194],
    'tablet_landscape': [1194, 834],
    'small_window': [600, 400],
  };
  for (final entry in sizes.entries) {
    plan.bytes(
      '.figma_splash/previews/${entry.key}.png',
      img.encodePng(
        preview(snapshot, entry.value[0], entry.value[1], config.color),
      ),
    );
  }
  final icon = systemIcon(
    snapshot.image(snapshot.frames['phone']!.layers['foreground']!.asset),
  );
  final branding = systemBrand(
    snapshot.image(snapshot.frames['phone']!.layers['branding']!.asset),
  );
  final android = canvas(375, 812, background: config.color);
  img.compositeImage(
    android,
    img.copyResize(icon, width: 288, height: 288),
    dstX: 43,
    dstY: 262,
  );
  img.compositeImage(
    android,
    img.copyResize(branding, width: 200, height: 80),
    dstX: 87,
    dstY: 692,
  );
  plan.bytes(
    '.figma_splash/previews/android12_schematic.png',
    img.encodePng(android),
  );
  plan.text(
    '.figma_splash/previews/README.txt',
    '构图预览，不是模拟器截图。Android 12 示意图的实际位置/尺寸由系统决定。iOS 使用 Auto Layout，Android 旧版使用窗口尺寸档位，鸿蒙使用可用窗口尺寸；三者不保证逐像素一致。请编译并验证真机或模拟器的启动过渡。\n',
  );
}
