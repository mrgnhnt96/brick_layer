import 'package:brick_oven/domain/brick_file.dart';
import 'package:brick_oven/domain/brick_source.dart';
import 'package:brick_oven/domain/variable.dart';
import 'package:brick_oven/domain/yaml_value.dart';
import 'package:brick_oven/src/exception.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../test_utils/mocks.dart';

void main() {
  const localPath = 'local_path';
  late MockLogger mockLogger;

  setUp(() {
    mockLogger = MockLogger();
  });

  List<String> createFakeFiles(
    void Function(FileSystem) createFileSystem,
  ) {
    final fileSystem = MemoryFileSystem();
    createFileSystem(fileSystem);

    final fakePaths = [
      join(localPath, 'file1.dart'),
      join(localPath, 'to', 'file2.dart'),
      join(localPath, 'to', 'some', 'file3.dart'),
    ];

    for (final file in fakePaths) {
      fileSystem.file(file).createSync(recursive: true);
    }

    return fakePaths;
  }

  test('can be instantiated', () {
    final instance =
        BrickSource(localPath: 'test', fileSystem: MemoryFileSystem());

    expect(instance, isA<BrickSource>());
  });

  group('#none', () {
    test('local path is null', () {
      final instance = BrickSource.none(fileSystem: MemoryFileSystem());

      expect(instance.localPath, isNull);
    });
  });

  group('#fromYaml', () {
    const path = 'test';

    group('source key', () {
      test('should return when provided', () {
        final yaml = loadYaml('''
$path
''') as String;
        final instance = BrickSource.fromYaml(
          YamlValue.from(yaml),
          fileSystem: MemoryFileSystem(),
        );

        expect(instance.localPath, path);
      });

      test('should return when empty', () {
        final instance = BrickSource.fromYaml(
          YamlValue.from(YamlMap.wrap({'path': ''})),
          fileSystem: MemoryFileSystem(),
        );

        expect(instance.localPath, isNull);
      });

      test(
          'should return when relative path when configPath is provided with source path',
          () {
        final instance = BrickSource.fromYaml(
          YamlValue.from('.'),
          configPath: 'path/to/config.yaml',
          fileSystem: MemoryFileSystem(),
        );

        expect(instance.localPath, 'path/to');
      });

      test(
          'should throw $ConfigException when source is null and configPath is provided',
          () {
        BrickSource instance() {
          return BrickSource.fromYaml(
            YamlValue.from(null),
            configPath: 'path/to/config.yaml',
            fileSystem: MemoryFileSystem(),
          );
        }

        expect(instance, throwsA(isA<ConfigException>()));
      });

      test(
          'should throw $ConfigException when path value is null and configPath is provided',
          () {
        final yaml = loadYaml('''
path:
''') as YamlMap;

        BrickSource instance() {
          return BrickSource.fromYaml(
            YamlValue.from(yaml),
            configPath: 'path/to/config.yaml',
            fileSystem: MemoryFileSystem(),
          );
        }

        expect(instance, throwsA(isA<ConfigException>()));
      });

      test('should return when path key is provided', () {
        final yaml = loadYaml('''
path: $path
''') as YamlMap;

        final instance = BrickSource.fromYaml(
          YamlValue.yaml(yaml),
          fileSystem: MemoryFileSystem(),
        );

        expect(instance.localPath, path);
      });

      test(
          'should throw $ConfigException when extra keys in yaml map are provided',
          () {
        final yaml = loadYaml('''
path: $path
extra: key
''') as YamlMap;

        expect(
          () => BrickSource.fromYaml(
            YamlValue.yaml(yaml),
            fileSystem: MemoryFileSystem(),
          ),
          throwsA(isA<ConfigException>()),
        );
      });

      test('should throw $ConfigException when yaml is error', () {
        expect(
          () => BrickSource.fromYaml(
            const YamlError('error'),
            fileSystem: MemoryFileSystem(),
          ),
          throwsA(isA<ConfigException>()),
        );
      });

      test('should return null when path value is not provided', () {
        final yaml = loadYaml('''
path:
''') as YamlMap;

        final instance = BrickSource.fromYaml(
          YamlValue.from(yaml),
          fileSystem: MemoryFileSystem(),
        );

        expect(instance.localPath, isNull);
      });

      test('should throw $ConfigException when path is not type string', () {
        final yaml = loadYaml('''
path:
  - $path
''') as YamlMap;

        expect(
          () => BrickSource.fromYaml(
            YamlValue.yaml(yaml),
            fileSystem: MemoryFileSystem(),
          ),
          throwsA(isA<ConfigException>()),
        );
      });

      test('should return null when not provided', () {
        final instance = BrickSource.fromYaml(
          const YamlValue.none(),
          fileSystem: MemoryFileSystem(),
        );

        expect(instance.localPath, isNull);
      });
    });
  });

  group('#files', () {
    test('should return no files when no source is provided', () {
      final instance = BrickSource.none(fileSystem: MemoryFileSystem());

      expect(instance.files(), isEmpty);
    });

    test('should return files from local directory', () {
      late BrickSource source;

      final fakePaths = createFakeFiles((fs) {
        source = BrickSource.memory(
          localPath: localPath,
          fileSystem: fs,
        );
      });

      final files = source.files();

      expect(files, hasLength(fakePaths.length));

      for (final file in files) {
        expect(fakePaths, contains('$localPath$separator${file.path}'));
      }
    });
  });

  group('#sourceDir', () {
    test('should return local path when provided', () {
      final instance = BrickSource.memory(
        localPath: localPath,
        fileSystem: MemoryFileSystem(),
      );

      expect(instance.sourceDir, localPath);
    });
  });

  group('#mergeFilesAndConfig', () {
    test('should return all source files', () {
      late BrickSource source;

      final fakePaths = createFakeFiles((fs) {
        source = BrickSource.memory(
          localPath: localPath,
          fileSystem: fs,
        );
      });

      final mergedFiles = source.mergeFilesAndConfig([], logger: mockLogger);

      expect(mergedFiles, hasLength(fakePaths.length));

      for (final file in mergedFiles) {
        expect(fakePaths, contains('$localPath$separator${file.path}'));
      }

      verifyNoMoreInteractions(mockLogger);
    });

    test('should return no config file when source files do not exist', () {
      final source = BrickSource(
        localPath: localPath,
        fileSystem: MemoryFileSystem(),
      );

      final configFiles = ['file1.dart', 'file2.dart'].map(BrickFile.new);

      verifyNever(() => mockLogger.info(any()));
      verifyNever(() => mockLogger.warn(any()));

      final mergedFiles =
          source.mergeFilesAndConfig(configFiles, logger: mockLogger);

      verify(() => mockLogger.info('')).called(2);
      verify(
        () => mockLogger.warn(
          'The configured file "file1.dart" does not exist within local_path',
        ),
      ).called(1);
      verify(
        () => mockLogger.warn(
          'The configured file "file2.dart" does not exist within local_path',
        ),
      ).called(1);

      expect(mergedFiles, hasLength(0));

      for (final file in mergedFiles) {
        expect(configFiles, isNot(contains(file)));
      }

      verifyNoMoreInteractions(mockLogger);
    });

    test('should return all config files', () {
      late BrickSource source;

      final files = createFakeFiles((fs) {
        source = BrickSource.memory(
          localPath: localPath,
          fileSystem: fs,
        );
      });

      final configFiles = files.map((e) {
        final path = e.replaceFirst('$localPath/', '');
        return BrickFile(path);
      });

      final mergedFiles =
          source.mergeFilesAndConfig(configFiles, logger: mockLogger);

      expect(mergedFiles, hasLength(configFiles.length));

      for (final file in mergedFiles) {
        expect(configFiles, contains(file));
      }

      verifyNoMoreInteractions(mockLogger);
    });

    test('should return merged config files onto source files', () {
      late BrickSource source;

      final fakePaths = createFakeFiles((fs) {
        source = BrickSource.memory(
          localPath: localPath,
          fileSystem: fs,
        );
      });

      final configFiles = <BrickFile>[];

      const variables = [Variable(name: 'name', placeholder: 'placeholder')];

      for (final path in fakePaths) {
        configFiles.add(
          BrickFile.config(
            path.substring('$localPath.'.length),
            variables: variables,
          ),
        );
      }

      final mergedFiles =
          source.mergeFilesAndConfig(configFiles, logger: mockLogger);

      expect(mergedFiles, hasLength(fakePaths.length));

      for (final file in mergedFiles) {
        expect(fakePaths, contains('$localPath$separator${file.path}'));
        // expect(file.prefix, prefix);
        // expect(file.suffix, suffix);
        expect(file.variables.single, variables.single);
      }
    });

    test(
      'should exclude files that match or are children of excluded paths',
      () {
        final excludedPaths = [
          'excluded',
          'other/file.dart',
        ];

        final files = [
          'file1.dart',
          'file2.dart',
          'excluded/file1.dart',
          'excluded/file2.dart',
          'other/file.dart',
        ];

        final fs = MemoryFileSystem();

        for (final file in files) {
          fs.file(file).createSync(recursive: true);
        }

        final source = BrickSource.memory(
          localPath: '.',
          fileSystem: fs,
        );

        final brickFiles = source.mergeFilesAndConfig(
          [],
          excludedPaths: excludedPaths,
          logger: mockLogger,
        ).toList();

        expect(brickFiles.length, 2);
        expect(brickFiles[0].path, 'file1.dart');
        expect(brickFiles[1].path, 'file2.dart');

        verifyNoMoreInteractions(mockLogger);
      },
    );
  });

  group('#fromSourcePath', () {
    test('should join source dir with files path', () {
      final source = BrickSource(
        localPath: localPath,
        fileSystem: MemoryFileSystem(),
      );
      const fileName = 'file.dart';

      const file = BrickFile(fileName);

      expect(
        source.fromSourcePath(file.path),
        join(localPath, fileName),
      );
    });
  });
}
