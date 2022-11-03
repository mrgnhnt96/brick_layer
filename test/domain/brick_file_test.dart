// ignore_for_file: cascade_invocations

import 'package:brick_oven/domain/yaml_value.dart';
import 'package:brick_oven/enums/mustache_format.dart';
import 'package:brick_oven/src/exception.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import 'package:brick_oven/domain/brick_file.dart';
import 'package:brick_oven/domain/brick_path.dart';
import 'package:brick_oven/domain/name.dart';
import 'package:brick_oven/domain/variable.dart';
import 'package:brick_oven/enums/mustache_sections.dart';
import 'package:yaml/yaml.dart';

import '../utils/mocks.dart';

void main() {
  const defaultFileName = 'file';
  const defaultFile = '$defaultFileName.dart';
  final defaultPath = join('path', 'to', defaultFile);

  const fileExtensions = {
    'file.dart': '.dart',
    'file.dart.mustache': '.dart.mustache',
    'file.mustache': '.mustache',
    'file.js': '.js',
    'file.md': '.md',
  };

  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
  });

  group('$BrickFile unnamed ctor', () {
    final instance = BrickFile(defaultPath);

    test('can be instanciated', () {
      expect(instance, isA<BrickFile>());
    });

    test('variables is an empty list', () {
      expect(instance.variables, isEmpty);
    });

    test('prefix is null', () {
      expect(instance.name?.prefix, isNull);
    });

    test('suffix is null', () {
      expect(instance.name?.suffix, isNull);
    });

    test('providedName is null', () {
      expect(instance.name?.value, isNull);
    });
  });

  group('#fromYaml', () {
    test('throws $ConfigException on null value', () {
      expect(
        () => BrickFile.fromYaml(const YamlValue.none(), path: 'path'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws $ConfigException on incorrect type', () {
      expect(
        () => BrickFile.fromYaml(YamlValue.from(''), path: 'path'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws $ConfigException on incorrect type', () {
      expect(
        () => BrickFile.fromYaml(YamlValue.from(''), path: 'path'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('gets files name when not provided value in the name key', () {
      const fileName = 'file';
      const ext = '.dart';
      const file = '$fileName$ext';
      final paths = [
        join('path', file),
        join('path', 'to', file),
        join('path', 'to', 'some', file),
      ];

      for (final path in paths) {
        final yaml = loadYaml('''
name:
''') as YamlMap;

        final file = BrickFile.fromYaml(YamlValue.from(yaml), path: path);

        expect(
          file.fileName,
          '{{{$fileName}}}$ext',
        );
      }
    });

    test('can parse all provided values', () {
      final yaml = loadYaml('''
name:
  value: George
  prefix: Mr.
  suffix: Sr.

vars:
  name: value
''') as YamlMap;

      final instance =
          BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

      expect(instance.variables, hasLength(1));
      expect(instance.path, defaultPath);
      expect(instance.name?.prefix, 'Mr.');
      expect(instance.name?.suffix, 'Sr.');
      expect(instance.name?.value, 'George');
    });

    test('can parse empty variables', () {
      final yaml = loadYaml('''
name:
''') as YamlMap;

      final instance =
          BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

      expect(instance.variables, isEmpty);

      final yaml2 = loadYaml('''
vars:
''') as YamlMap;

      final instance2 =
          BrickFile.fromYaml(YamlValue.from(yaml2), path: defaultPath);

      expect(instance2.variables, isEmpty);
    });

    test('throws $ConfigException if yaml is error', () {
      expect(
        () => BrickFile.fromYaml(
          const YamlValue.error('error'),
          path: defaultPath,
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws $ConfigException if yaml is incorrect type', () {
      expect(
        () => BrickFile.fromYaml(
          const YamlValue.string('Hi, hows it going?'),
          path: defaultPath,
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    group('name', () {
      test('can parse when key is not provided', () {
        final yaml = loadYaml('''
vars:
''') as YamlMap;

        final instance =
            BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

        expect(instance.name, isNull);
      });

      test('can parse when string provided', () {
        final yaml = loadYaml('''
name: Alfalfa
''') as YamlMap;

        final instance =
            BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

        expect(instance.name?.value, 'Alfalfa');
      });

      test('can parse when map is provided', () {
        final yaml = loadYaml('''
name:
  value: Mickie Ds
''') as YamlMap;

        final instance =
            BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

        expect(instance.name?.value, 'Mickie Ds');
      });

      test('can parse when value is not provided', () {
        final yaml = loadYaml('''
name:
''') as YamlMap;

        final instance =
            BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

        expect(instance.name?.value, defaultFileName);
      });

      test('throws $ConfigException when not configured correctly', () {
        final yaml = loadYaml('''
name:
  value:
    - 1
''') as YamlMap;

        expect(
          () => BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath),
          throwsA(isA<ConfigException>()),
        );
      });
    });

    group('variables', () {
      test('return with vars empty when not provided', () {
        final yaml = loadYaml('''
name:
''') as YamlMap;
        final instance =
            BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath);

        expect(instance.variables, isEmpty);
      });

      test('throws $ConfigException if vars is not of map', () {
        final yaml = loadYaml('''
vars:
  - name
''') as YamlMap;

        expect(
          () => BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath),
          throwsA(isA<ConfigException>()),
        );
      });

      test('throws $ConfigException if vars value is not configured correctly',
          () {
        final yaml = loadYaml('''
vars:
  name:
    - value
''') as YamlMap;

        expect(
          () => BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath),
          throwsA(isA<ConfigException>()),
        );
      });
    });
  });

  test('throws if extra keys are provided', () {
    final yaml = loadYaml('''
yooooo:
''') as YamlMap;

    expect(
      () => BrickFile.fromYaml(YamlValue.from(yaml), path: defaultPath),
      throwsA(isA<ConfigException>()),
    );
  });

  group('#fileName', () {
    const defaultFile = 'file.dart';
    const defaultPath = defaultFile;
    const name = 'name';
    const prefix = 'prefix';
    const suffix = 'suffix';

    test('return the file name formatted when no provided name', () {
      const instance = BrickFile(defaultFile);

      expect(instance.fileName, defaultFile);
    });

    test('return the provided name', () {
      const instance = BrickFile.config(defaultPath, name: Name(name));

      expect(instance.fileName, '{{{$name}}}.dart');
    });

    test('prepends the prefix', () {
      const instance = BrickFile.config(
        defaultPath,
        name: Name(name, prefix: prefix),
      );

      expect(instance.fileName, '$prefix{{{$name}}}.dart');
    });

    test('appends the suffix', () {
      const instance = BrickFile.config(
        defaultPath,
        name: Name(name, suffix: suffix),
      );

      expect(instance.fileName, contains('{{{$name}}}$suffix'));
    });

    test('formats the name to mustache format when provided', () {
      const instance = BrickFile.config(
        defaultPath,
        name: Name(name, format: MustacheFormat.snakeCase),
      );

      expect(
        instance.fileName,
        contains('{{#snakeCase}}{{{$name}}}{{/snakeCase}}'),
      );
    });

    test('does not format the name to mustache format when not provided', () {
      const instance = BrickFile.config(defaultPath, name: Name(name));

      expect(
        instance.fileName,
        contains('{{{$name}}}'),
      );
    });

    test('includes the extension', () {
      for (final file in fileExtensions.keys) {
        final expected = fileExtensions[file]!;
        final instance = BrickFile.config(file);

        expect(instance.fileName, endsWith(expected));
      }
    });
  });

  group('#extension', () {
    test('returns the extension', () {
      for (final file in fileExtensions.keys) {
        final expected = fileExtensions[file];
        final instance = BrickFile.config(file);

        expect(instance.extension, expected);
      }
    });

    test('returns multi extension', () {
      final extensions =
          List<String>.generate(10, (index) => "${'.g' * index}.dart");

      for (final extension in extensions) {
        final fileName = 'file$extension';
        final instance = BrickFile.config(fileName);

        expect(instance.extension, extension);
      }
    });
  });

  group('#hasConfiguredName', () {
    test('returns true when a name is provided', () {
      const file = BrickFile.config('path/to/file.dart', name: Name('name'));

      expect(file.hasConfiguredName, isTrue);
    });

    test('returns false when no name is provided', () {
      const file = BrickFile.config('path/to/file.dart');

      expect(file.hasConfiguredName, isFalse);
    });
  });

  group('#nonformattedName', () {
    test('returns the basename when no name is provided', () {
      const file = BrickFile.config('path/to/file.dart');

      expect(file.simpleName, 'file.dart');
    });

    test('returns the provided name', () {
      const file = BrickFile.config('path/to/file.dart', name: Name('name'));

      expect(file.simpleName, '{name}.dart');
    });

    test('returns the provided name with prefix', () {
      const file = BrickFile.config(
        'path/to/file.dart',
        name: Name(
          'name',
          prefix: 'prefix_',
        ),
      );

      expect(file.simpleName, 'prefix_{name}.dart');
    });

    test('returns the provided name with suffix', () {
      const file = BrickFile.config(
        'path/to/file.dart',
        name: Name(
          'name',
          suffix: '_suffix',
        ),
      );

      expect(file.simpleName, '{name}_suffix.dart');
    });
  });

  group('#writeTargetFiles', () {
    late FileSystem fileSystem;
    late File sourceFile;
    const sourceFilePath = 'source.dart';
    const content = 'content';

    BrickPath brickPath({
      String? name,
      String? path,
    }) {
      return BrickPath(
        name: Name(name ?? 'name'),
        path: path ?? defaultPath,
      );
    }

    setUp(() {
      fileSystem = MemoryFileSystem();
      sourceFile = fileSystem.file(sourceFilePath)
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    });

    test('writes a file on the root level', () {
      const instance = BrickFile.config(defaultFile);

      instance.writeTargetFile(
        sourceFile: sourceFile,
        configuredDirs: [],
        targetDir: '',
        fileSystem: fileSystem,
        logger: mockLogger,
      );

      final newFile = fileSystem.file(defaultFile);

      expect(newFile.existsSync(), isTrue);
    });

    test('writes a file on a nested level', () {
      const instance = BrickFile.config(defaultFile);

      instance.writeTargetFile(
        sourceFile: sourceFile,
        configuredDirs: [],
        targetDir: 'nested',
        fileSystem: fileSystem,
        logger: mockLogger,
      );

      final newFile = fileSystem.file(
        join(
          'nested',
          defaultFile,
        ),
      );

      expect(newFile.existsSync(), isTrue);
    });

    test('updates path with configured directory', () {
      final instance = BrickFile.config(defaultPath);
      const replacement = 'something';
      final dir = brickPath(name: replacement, path: join('path', 'to'));

      instance.writeTargetFile(
        sourceFile: sourceFile,
        configuredDirs: [dir],
        targetDir: '',
        fileSystem: fileSystem,
        logger: mockLogger,
      );

      final newFile = fileSystem.file(
        join(
          'path',
          '{{{$replacement}}}',
          defaultFile,
        ),
      );

      expect(newFile.existsSync(), isTrue);
    });

    test('updates file name when provided', () {
      const replacement = 'something';
      final instance =
          BrickFile.config(defaultPath, name: const Name(replacement));

      instance.writeTargetFile(
        sourceFile: sourceFile,
        configuredDirs: [],
        targetDir: '',
        fileSystem: fileSystem,
        logger: mockLogger,
      );

      final newFile = fileSystem.file(
        join(
          'path',
          'to',
          '{{{$replacement}}}.dart',
        ),
      );

      expect(newFile.existsSync(), isTrue);
    });

    test('copies file when no variables are provided', () {
      const instance = BrickFile.config(defaultFile);

      instance.writeTargetFile(
        sourceFile: sourceFile,
        configuredDirs: [],
        targetDir: '',
        fileSystem: fileSystem,
        logger: mockLogger,
      );

      final newFile = fileSystem.file(defaultFile);

      expect(newFile.readAsStringSync(), content);
    });

    group('#variables', () {
      test('replaces variable placeholders with name', () {
        const newName = 'new-name';
        const placeholder = 'MEEEEE';
        const content = 'replace: $placeholder';

        const variable = Variable(name: newName, placeholder: placeholder);
        const instance = BrickFile.config(defaultFile, variables: [variable]);

        sourceFile.writeAsStringSync(content);

        instance.writeTargetFile(
          sourceFile: sourceFile,
          configuredDirs: [],
          targetDir: '',
          fileSystem: fileSystem,
          logger: mockLogger,
        );

        final newFile = fileSystem.file(defaultFile);

        expect(newFile.readAsStringSync(), 'replace: {{$newName}}');
      });

      const formats = [
        'camel',
        'constant',
        'dot',
        'header',
        'lower',
        'pascal',
        'param',
        'path',
        'sentence',
        'snake',
        'title',
        'upper',
      ];

      test('replaces sub string', () {
        const newName = 'new-name';
        const placeholder = '_name_';
        const contents = {
          'x$placeholder': 'x{{$newName}}',
          '${placeholder}s': '{{$newName}}s'
        };
        const variable = Variable(name: newName, placeholder: placeholder);
        const instance = BrickFile.config(defaultFile, variables: [variable]);

        for (final content in contents.entries) {
          sourceFile.writeAsStringSync(content.key);
          instance.writeTargetFile(
            sourceFile: sourceFile,
            configuredDirs: [],
            targetDir: '',
            fileSystem: fileSystem,
            logger: mockLogger,
          );

          final newFile = fileSystem.file(defaultFile);

          expect(newFile.readAsStringSync(), content.value);
        }
      });

      test('replaces all occurrences when found in the same line', () {
        const newName = 'new-name';
        const placeholder = 'name';

        const variable = Variable(name: newName, placeholder: placeholder);
        const instance = BrickFile.config(defaultFile, variables: [variable]);

        const content =
            '$placeholder 1 $placeholder 2 $placeholder 3 $placeholder/$placeholder.dart';

        sourceFile.writeAsStringSync(content);
        instance.writeTargetFile(
          sourceFile: sourceFile,
          configuredDirs: [],
          targetDir: '',
          fileSystem: fileSystem,
          logger: mockLogger,
        );

        final newFile = fileSystem.file(defaultFile);

        expect(
          newFile.readAsStringSync(),
          '{{$newName}} 1 {{$newName}} 2 {{$newName}} 3 {{$newName}}/{{$newName}}.dart',
        );
      });

      test('replaces loops & vars when found in the same line', () {
        const newName = 'new-name';
        const placeholder = 'name';

        const variable = Variable(name: newName, placeholder: placeholder);
        const instance = BrickFile.config(defaultFile, variables: [variable]);

        const content =
            '\n\n\n\nstart$placeholder 1 $placeholder 2 $placeholder 3\n\n\n\n';

        sourceFile.writeAsStringSync(content);
        instance.writeTargetFile(
          sourceFile: sourceFile,
          configuredDirs: [],
          targetDir: '',
          fileSystem: fileSystem,
          logger: mockLogger,
        );

        final newFile = fileSystem.file(defaultFile);

        expect(newFile.readAsStringSync(), '\n{{#$newName}}\n');
      });

      group('formats', () {
        const newName = 'new-name';
        const placeholder = '_SCREEN_';
        const variable = Variable(name: newName, placeholder: placeholder);
        const instance = BrickFile.config(defaultFile, variables: [variable]);

        Map<String, String> getContents({
          required String format,
          String prefix = '',
          String suffix = '',
          String before = '',
          String after = '',
        }) {
          final caseFormats = [
            format,
            '${format}Case',
            '${format}CASE'.toUpperCase(),
            '${format}case'.toLowerCase(),
          ];

          final value =
              '$before$prefix{{#${format}Case}}{{{$newName}}}{{/${format}Case}}$suffix$after';

          return caseFormats.fold(<String, String>{}, (p, caseFormat) {
            final key = '$before'
                '$prefix'
                '$placeholder'
                '$caseFormat'
                '$suffix'
                '$after';
            p[key] = value;

            return p;
          });
        }

        for (final format in formats) {
          group('($format)', () {
            test('replaces variable placeholder with name', () {
              final contents = getContents(format: format);

              for (final content in contents.entries) {
                sourceFile.writeAsStringSync(content.key);
                instance.writeTargetFile(
                  sourceFile: sourceFile,
                  configuredDirs: [],
                  targetDir: '',
                  fileSystem: fileSystem,
                  logger: mockLogger,
                );

                final newFile = fileSystem.file(defaultFile);

                expect(
                  newFile.readAsStringSync(),
                  content.value,
                );
              }
            });

            test('replaces variable placeholder with name, maintaining prefix',
                () {
              final contents = getContents(format: format, prefix: 'prefix_');

              for (final content in contents.entries) {
                sourceFile.writeAsStringSync(content.key);
                instance.writeTargetFile(
                  sourceFile: sourceFile,
                  configuredDirs: [],
                  targetDir: '',
                  fileSystem: fileSystem,
                  logger: mockLogger,
                );

                final newFile = fileSystem.file(defaultFile);

                expect(
                  newFile.readAsStringSync(),
                  content.value,
                );
              }
            });

            test('replaces variable placeholder with name, maintaining suffix',
                () {
              final contents = getContents(format: format, suffix: '_suffix');

              for (final content in contents.entries) {
                sourceFile.writeAsStringSync(content.key);
                instance.writeTargetFile(
                  sourceFile: sourceFile,
                  configuredDirs: [],
                  targetDir: '',
                  fileSystem: fileSystem,
                  logger: mockLogger,
                );

                final newFile = fileSystem.file(defaultFile);

                expect(
                  newFile.readAsStringSync(),
                  content.value,
                );
              }
            });

            test(
                'replaces variable placeholder with name, maintaining pre/post text',
                () {
              final contents = getContents(
                format: format,
                before: 'some text before ',
                after: ' some text after',
              );

              for (final content in contents.entries) {
                sourceFile.writeAsStringSync(content.key);
                instance.writeTargetFile(
                  sourceFile: sourceFile,
                  configuredDirs: [],
                  targetDir: '',
                  fileSystem: fileSystem,
                  logger: mockLogger,
                );

                final newFile = fileSystem.file(defaultFile);

                expect(
                  newFile.readAsStringSync(),
                  content.value,
                );
              }
            });

            test(
                'replaces variable placeholder with name, maintaining pre/post text and prefix/suffix',
                () {
              final contents = getContents(
                format: format,
                before: 'some text before ',
                after: ' some text after',
              );

              for (final content in contents.entries) {
                sourceFile.writeAsStringSync(content.key);
                instance.writeTargetFile(
                  sourceFile: sourceFile,
                  configuredDirs: [],
                  targetDir: '',
                  fileSystem: fileSystem,
                  logger: mockLogger,
                );

                final newFile = fileSystem.file(defaultFile);

                expect(
                  newFile.readAsStringSync(),
                  content.value,
                );
              }
            });
          });
        }
      });

      group('sections', () {
        const newName = 'new-name';
        const placeholder = 'MEEEEE';

        for (final section in MustacheSections.values) {
          Map<String, String> getContent() {
            return {
              '${section.configName}$placeholder':
                  '{{${section.symbol}$newName}}',
            };
          }

          group('(${section.name})', () {
            test(
              'replaces variable placeholder',
              () {
                final contents = getContent();

                for (final content in contents.entries) {
                  const variable =
                      Variable(name: newName, placeholder: placeholder);
                  const instance =
                      BrickFile.config(defaultFile, variables: [variable]);

                  sourceFile.writeAsStringSync(content.key);

                  instance.writeTargetFile(
                    sourceFile: sourceFile,
                    configuredDirs: [],
                    targetDir: '',
                    fileSystem: fileSystem,
                    logger: mockLogger,
                  );

                  final newFile = fileSystem.file(defaultFile);

                  expect(newFile.readAsStringSync(), content.value);
                }
              },
            );
          });
        }
      });

      test(
        'replaces variable placeholder with section end syntax',
        () {
          const newName = 'new-name';
          const placeholder = 'MEEEEE';
          const content = 'replace: n$placeholder';

          const variable = Variable(name: newName, placeholder: placeholder);
          const instance = BrickFile.config(defaultFile, variables: [variable]);

          sourceFile.writeAsStringSync(content);

          instance.writeTargetFile(
            sourceFile: sourceFile,
            configuredDirs: [],
            targetDir: '',
            fileSystem: fileSystem,
            logger: mockLogger,
          );

          final newFile = fileSystem.file(defaultFile);

          expect(newFile.readAsStringSync(), 'replace: {{^$newName}}');
        },
      );

      test(
        'throws error when variable is wrapped with brackets',
        () {
          const newName = 'new-name';
          const placeholder = 'MEEEEE';
          const content = 'replace: {${placeholder}camel}';

          const variable = Variable(name: newName, placeholder: placeholder);
          const instance = BrickFile.config(defaultFile, variables: [variable]);

          sourceFile.writeAsStringSync(content);

          void writeFile() {
            instance.writeTargetFile(
              sourceFile: sourceFile,
              configuredDirs: [],
              targetDir: '',
              fileSystem: fileSystem,
              logger: mockLogger,
            );
          }

          expect(writeFile, throwsA(isA<FileException>()));
        },
      );
    });

    test('replaces mustache loop comment', () {
      const placeholder = '_HELLO_';
      const replacement = 'hello';

      Map<String, String> lines(String configName, String symbol) {
        final expected = '{{$symbol$replacement}}';
        return {
          '//': expected,
          '#': expected,
          r'\*': expected,
          r'*\': expected,
          '/*': expected,
          '*/': expected,
        }.map((key, value) {
          return MapEntry('$key $configName$placeholder', value);
        });
      }

      final loops = {
        ...lines('start', '#'),
        ...lines('end', '/'),
        ...lines('nstart', '^'),
      };

      const variable = Variable(placeholder: placeholder, name: replacement);
      const instance = BrickFile.config(defaultFile, variables: [variable]);

      for (final loop in loops.keys) {
        final newFile = fileSystem.file(defaultFile);

        sourceFile.writeAsStringSync(loop);

        instance.writeTargetFile(
          sourceFile: sourceFile,
          configuredDirs: [],
          targetDir: '',
          fileSystem: fileSystem,
          logger: mockLogger,
        );

        expect(newFile.readAsStringSync(), loops[loop]);
      }
    });

    test('prints warning if excess variables exist', () {
      verifyNever(() => mockLogger.warn(any()));

      const variable = Variable(placeholder: '_HELLO_', name: 'hello');
      const extraVariable = Variable(placeholder: '_GOODBYE_', name: 'goodbye');
      const instance =
          BrickFile.config(defaultFile, variables: [variable, extraVariable]);

      sourceFile.writeAsStringSync('replace: _HELLO_');

      instance.writeTargetFile(
        sourceFile: sourceFile,
        configuredDirs: [],
        targetDir: '',
        fileSystem: fileSystem,
        logger: mockLogger,
      );

      verify(
        () => mockLogger.warn(
          'The following variables are configured in brick_oven.yaml '
          'but not used in file `${sourceFile.path}`:\n'
          '"${extraVariable.name}"',
        ),
      ).called(1);
    });
  });
}
