import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:figma_native_splash/figma_native_splash.dart';
import 'package:figma_native_splash/src/cli.dart';
import 'package:figma_native_splash/src/output.dart';
import 'package:figma_native_splash/src/xcode_project.dart';
import 'support.dart';

void main() {
  late Directory root;
  const file = 'ios/Runner.xcodeproj/project.pbxproj';
  const storyboard = 'figma_splash_LaunchScreen';
  File projectFile() => File(p.join(root.path, file));
  OutputPlan register() {
    final plan = OutputPlan(root);
    integrateIosStoryboard(plan, 'ios/Runner', storyboard);
    return plan;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('splash-xcode-');
    write(root, file, xcodeFixture);
  });
  tearDown(() {
    exitCode = 0;
    root.deleteSync(recursive: true);
  });

  test('首次接入新增文件和 Resources 引用，保留旧启动图及自定义脚本', () {
    final plan = register();
    expect(plan.changes, [file]);
    expect(plan.integrationIssues.single, contains('Resources'));
    expect(projectFile().readAsStringSync(), xcodeFixture);
    plan.apply();
    final updated = projectFile().readAsStringSync();
    expect(updated, contains('Base.lproj/LaunchScreen.storyboard'));
    expect(
      updated,
      contains('path = "Runner/Base.lproj/$storyboard.storyboard"'),
    );
    expect(
      updated,
      contains("shellScript = \"echo 'tokens: { }; ( ); /* keep */';\";"),
    );
    expect('isa = PBXBuildFile'.allMatches(updated).length, 2);
    expect(register().changes, isEmpty);
    expect(register().integrationIssues, isEmpty);
  });

  test('复用已经接入的 Base 本地化组，工程逐字保持不变', () {
    final source = xcodeFixture.replaceAll(
      'LaunchScreen.storyboard',
      '$storyboard.storyboard',
    );
    projectFile().writeAsStringSync(source);
    final plan = register();
    expect(plan.changes, isEmpty);
    expect(plan.integrationIssues, isEmpty);
    expect(projectFile().readAsStringSync(), source);
  });

  test('文件引用存在但未加入应用 Resources 时补齐，之后重复生成无变化', () {
    final source = xcodeFixture
        .replaceAll('LaunchScreen.storyboard', '$storyboard.storyboard')
        .replaceFirst('files = (A00000000000000000000008,);', 'files = ();');
    projectFile().writeAsStringSync(source);
    final plan = register();
    expect(plan.integrationIssues, isNotEmpty);
    plan.apply();
    expect(
      'isa = PBXFileReference'
          .allMatches(projectFile().readAsStringSync())
          .length,
      1,
    );
    expect(register().changes, isEmpty);
  });

  test('没有 Resources 阶段时创建并接入应用 Target', () {
    projectFile().writeAsStringSync(
      xcodeFixture.replaceFirst(
        'buildPhases = (A00000000000000000000004, A0000000000000000000000A,);',
        'buildPhases = (A0000000000000000000000A,);',
      ),
    );
    register().apply();
    expect(
      'isa = PBXResourcesBuildPhase'
          .allMatches(projectFile().readAsStringSync())
          .length,
      2,
    );
    expect(register().changes, isEmpty);
  });

  test('追加引用兼容没有末尾逗号的数组和尾部注释', () {
    projectFile().writeAsStringSync(
      xcodeFixture
          .replaceFirst(
            'children = (A00000000000000000000005,);',
            'children = (A00000000000000000000005 /* group */);',
          )
          .replaceFirst(
            'files = (A00000000000000000000008,);',
            'files = (A00000000000000000000008 /* old */);',
          ),
    );
    register().apply();
    expect(projectFile().readAsStringSync(), contains('/* old */'));
    expect(register().changes, isEmpty);
  });

  test('项目和目录名带空格、项目重命名时正常接入', () {
    Directory(
      p.join(root.path, 'ios/Runner.xcodeproj'),
    ).renameSync(p.join(root.path, 'ios/My App.xcodeproj'));
    final plan = OutputPlan(root);
    integrateIosStoryboard(plan, 'ios/My App', storyboard);
    plan.apply();
    final result = File(
      p.join(root.path, 'ios/My App.xcodeproj/project.pbxproj'),
    ).readAsStringSync();
    expect(
      result,
      contains('path = "My App/Base.lproj/$storyboard.storyboard"'),
    );
    final repeat = OutputPlan(root);
    integrateIosStoryboard(repeat, 'ios/My App', storyboard);
    expect(repeat.changes, isEmpty);
  });

  test('多个 Target 时只改应用 Resources，保留扩展 Target', () {
    final source = xcodeFixture
        .replaceFirst(
          'targets = (A00000000000000000000003,);',
          'targets = (A00000000000000000000003, EXTENSION,);',
        )
        .replaceFirst('objects = {', '''objects = {
    EXTENSION = {isa = PBXNativeTarget; name = Widget; productType = "com.apple.product-type.app-extension"; buildPhases = (EXT_RES,);};
    EXT_RES = {isa = PBXResourcesBuildPhase; files = ();};''');
    projectFile().writeAsStringSync(source);
    register().apply();
    expect(
      projectFile().readAsStringSync(),
      contains('EXT_RES = {isa = PBXResourcesBuildPhase; files = ();};'),
    );
    expect(register().changes, isEmpty);
  });

  test('缺少或存在多个 Xcode 工程时拒绝写入', () {
    Directory(p.join(root.path, 'ios/Another.xcodeproj')).createSync();
    expect(register, throwsA(isA<SplashException>()));
    expect(projectFile().readAsStringSync(), xcodeFixture);
    Directory(p.join(root.path, 'ios')).deleteSync(recursive: true);
    expect(register, throwsA(isA<SplashException>()));
  });

  test('不支持的自动同步 Target 和重复打包均明确报错', () {
    projectFile().writeAsStringSync(
      xcodeFixture.replaceFirst(
        'name = Runner;',
        'name = Runner; fileSystemSynchronizedGroups = (SYNC,);',
      ),
    );
    expect(
      register,
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('自动同步'),
        ),
      ),
    );
    projectFile().writeAsStringSync(
      xcodeFixture
          .replaceAll('LaunchScreen.storyboard', '$storyboard.storyboard')
          .replaceFirst(
            'files = (A00000000000000000000008,);',
            'files = (A00000000000000000000008,A00000000000000000000008,);',
          ),
    );
    expect(
      register,
      throwsA(
        isA<SplashException>().having(
          (e) => e.message,
          'message',
          contains('重复打包'),
        ),
      ),
    );
  });

  test('本地化组名和构建过滤异常不会被误判为已接入', () {
    final registered = xcodeFixture.replaceAll(
      'LaunchScreen.storyboard',
      '$storyboard.storyboard',
    );
    final cases = [
      registered.replaceFirst(
        'name = $storyboard.storyboard;',
        'name = Other.storyboard;',
      ),
      registered.replaceFirst(
        'runOnlyForDeploymentPostprocessing = 0;',
        'runOnlyForDeploymentPostprocessing = 1;',
      ),
      registered.replaceFirst(
        'buildActionMask = 2147483647;',
        'buildActionMask = 0;',
      ),
      registered.replaceFirst(
        'isa = PBXBuildFile;',
        'isa = PBXBuildFile; platformFilter = macos;',
      ),
    ];
    for (final source in cases) {
      projectFile().writeAsStringSync(source);
      expect(register, throwsA(isA<SplashException>()));
      expect(projectFile().readAsStringSync(), source);
    }
  });

  test('格式错误和失效对象引用在写入之前失败', () {
    for (final text in [
      '{objects = {',
      xcodeFixture.replaceFirst(
        'mainGroup = A00000000000000000000002;',
        'mainGroup = MISSING;',
      ),
    ]) {
      projectFile().writeAsStringSync(text);
      expect(register, throwsA(isA<SplashException>()));
      expect(projectFile().readAsStringSync(), text);
    }
  });

  test('CLI check 发现缺少注册，dry-run 不落盘，create 修复后 check 通过', () async {
    projectFixture(root);
    final c = config(tablet: false, extra: 'platforms: [ios]');
    saveSnapshot(root, fixture(c));
    write(root, 'figma_splash.yaml', '''
splash:
  figma:
    phone: https://www.figma.com/design/Example?node-id=1-2
  platforms: [ios]
''');
    await runCli(['--project', root.path], command: 'check');
    expect(exitCode, 2);
    expect(projectFile().readAsStringSync(), xcodeFixture);
    exitCode = 0;
    await runCli(['--project', root.path, '--dry-run'], command: 'create');
    expect(exitCode, 0);
    expect(projectFile().readAsStringSync(), xcodeFixture);
    await runCli(['--project', root.path], command: 'create');
    expect(exitCode, 0);
    final manifest =
        jsonDecode(
              File(
                p.join(root.path, '.figma_splash/generated_ios.json'),
              ).readAsStringSync(),
            )
            as Map;
    expect((manifest['files'] as Map).containsKey(file), isFalse);
    await runCli(['--project', root.path], command: 'check');
    expect(exitCode, 0);
    expect(register().changes, isEmpty);
  });
}
