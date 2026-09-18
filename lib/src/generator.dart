import 'dart:io';
import 'config.dart';
import 'snapshot.dart';
import 'output.dart';
import 'android.dart';
import 'ios.dart';
import 'ohos.dart';

OutputPlan generate(
  Directory project,
  SplashConfig config,
  DesignSnapshot snapshot, {
  List<String>? platforms,
}) {
  final selected = platforms ?? config.platforms;
  if (selected.any((platform) => !config.platforms.contains(platform))) {
    throw SplashException('所选平台未在配置中启用');
  }
  final result = OutputPlan(project);
  for (final platform in selected) {
    final plan = OutputPlan(project);
    switch (platform) {
      case 'android':
        generateAndroid(plan, config, snapshot);
      case 'ios':
        generateIos(plan, config, snapshot);
      case 'ohos':
        generateOhos(plan, config, snapshot);
      default:
        throw SplashException('未知平台：$platform');
    }
    plan.track(platform, config.prefix);
    result.merge(plan);
  }
  return result;
}
