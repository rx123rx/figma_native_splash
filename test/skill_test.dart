import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const skillPath = 'skills/figma-native-splash';
const repository = 'https://github.com/rx123rx/figma_native_splash';

void main() {
  group('Agent Skill', () {
    late String skill;
    late YamlMap frontmatter;

    setUpAll(() {
      final file = File('$skillPath/SKILL.md');
      expect(
        file.existsSync(),
        isTrue,
        reason: '$skillPath/SKILL.md must ship with the package',
      );
      skill = file.readAsStringSync();
      const delimiter = '---';
      expect(
        skill.startsWith('$delimiter\n'),
        isTrue,
        reason: 'SKILL.md must start with YAML frontmatter',
      );
      final end = skill.indexOf('\n$delimiter\n', delimiter.length);
      expect(end, greaterThan(0), reason: 'frontmatter must be closed');
      frontmatter =
          loadYaml(skill.substring(delimiter.length + 1, end)) as YamlMap;
    });

    test('frontmatter declares the skill and matches its folder', () {
      expect(frontmatter['name'], 'figma-native-splash');
      final folder = Directory(
        skillPath,
      ).uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      expect(frontmatter['name'], folder);
      expect(frontmatter['license'], 'MIT');

      final description = frontmatter['description'];
      expect(description, isA<String>());
      expect(description, contains('figma_native_splash'));
      expect((description as String).length, lessThanOrEqualTo(1024));

      final metadata = frontmatter['metadata'];
      expect(metadata, isA<YamlMap>());
      expect((metadata as YamlMap)['repository'], repository);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('repository: $repository'),
      );
    });

    test('relative links resolve and HarmonyOS stays covered', () {
      for (final path in [
        '$skillPath/SKILL.md',
        '$skillPath/references/config-reference.md',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        final text = file.readAsStringSync();
        for (final match in RegExp(r'\]\(([^)#\s]+)\)').allMatches(text)) {
          final target = match.group(1)!;
          if (target.startsWith('http') || target.startsWith('#')) continue;
          final uri = file.parent.uri.resolve(target);
          final exists =
              File.fromUri(uri).existsSync() ||
              Directory.fromUri(uri).existsSync();
          expect(exists, isTrue, reason: '$path links to missing $target');
        }
      }
      expect(skill, contains('HarmonyOS'));
      expect(skill, contains('startWindowIcon'));
      expect(skill, contains('app_splash'));
      expect(skill, contains('ohos'));
    });

    test('READMEs document the install command and the current version', () {
      final version =
          (loadYaml(File('pubspec.yaml').readAsStringSync())
                  as YamlMap)['version']
              as String;
      for (final name in ['README.md', 'README_EN.md']) {
        final text = File(name).readAsStringSync();
        expect(
          text,
          contains('npx skills add rx123rx/figma_native_splash'),
          reason: name,
        );
        expect(text, contains('$skillPath/SKILL.md'), reason: name);
        expect(
          text,
          contains('figma_native_splash: ^$version'),
          reason: '$name must show the current version',
        );
      }
    });

    test('README links stay absolute so they work on pub.dev', () {
      for (final name in ['README.md', 'README_EN.md']) {
        final text = File(name).readAsStringSync();
        for (final match in RegExp(r'\]\(([^)#\s]+)\)').allMatches(text)) {
          final target = match.group(1)!;
          expect(
            target,
            anyOf(startsWith('http'), startsWith('#')),
            reason: '$name has a repo-relative link: $target',
          );
        }
      }
    });
  });
}
