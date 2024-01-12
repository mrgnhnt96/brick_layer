import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import 'package:brick_oven/src/runner.dart';
import 'package:brick_oven/utils/extensions/logger_extensions.dart';
import '../../test_utils/mocks.dart';

/// [brickName] will be used for
/// - Accessing fixture files
///   - test/integration/fixtures/[brickName]
/// - Accessing source files
///   - test/integration/sources/[brickName]
/// - Accessing running command
///   - brick_oven cook [brickName]
///
/// WARNING: it is expected to only have 1 brick configured within the brick_oven.yaml
Future<void> cook({
  required String brickName,
  required String command,
  required int numberOfFiles,
}) async {
  final mockLogger = MockLogger();
  final mockProgress = MockProgress();
  final mockPubUpdater = MockPubUpdater()..stubMethods();

  when(() => mockLogger.progress(any())).thenReturn(mockProgress);

  final testPath = join('test', 'e2e');
  final fixturePath = join(testPath, 'fixtures');
  final sourcePath = join(testPath, 'sources');

  const localFileSystem = LocalFileSystem();
  final memoryFileSystem = MemoryFileSystem();

  final brickFixturePath = join(fixturePath, brickName);
  final brickSourcePath = join(sourcePath, brickName);

  final source = localFileSystem.directory(brickSourcePath);

  final files =
      source.listSync(recursive: true, followLinks: false).whereType<File>();

  for (final file in files) {
    final relativePath = relative(file.path, from: brickSourcePath);

    final memoryFile = memoryFileSystem.file(relativePath)
      ..createSync(recursive: true);
    try {
      memoryFile.writeAsStringSync(file.readAsStringSync());
    } catch (_) {
      memoryFile.writeAsBytesSync(file.readAsBytesSync());
    }
  }

  final brickYamlContent = localFileSystem
      .file(join(brickFixturePath, 'brick.yaml'))
      .readAsStringSync();

  memoryFileSystem.file(join('brick.yaml')).writeAsStringSync(brickYamlContent);

  final brickOven = BrickOvenRunner(
    fileSystem: memoryFileSystem,
    logger: mockLogger,
    pubUpdater: mockPubUpdater,
  );

  final result = await brickOven.run(['cook', command]);

  verifyInOrder([
    mockLogger.preheat,
    () => mockLogger.progress('Writing Brick: $brickName'),
    () => mockProgress.complete(
          '$brickName: cooked $numberOfFiles file${numberOfFiles > 1 ? 's' : ''}',
        ),
    () => mockLogger.info('brick.yaml is in sync'),
    mockLogger.dingDing,
    () => mockPubUpdater.getLatestVersion(packageName),
  ]);

  expect(result, ExitCode.success.code);

  final brickFixtureFiles = localFileSystem
      .directory(join(brickFixturePath, '__brick__'))
      .listSync(recursive: true)
      .whereType<File>();

  final brickResultPath = join('bricks', brickName, '__brick__');

  for (final file in brickFixtureFiles) {
    final relativePath = relative(
      file.path,
      from: join(brickFixturePath, '__brick__'),
    );
    final expectedFile =
        memoryFileSystem.file(join(brickResultPath, relativePath));

    expect(expectedFile.existsSync(), isTrue);

    dynamic content;
    dynamic expected;
    try {
      content = expectedFile.readAsStringSync();
      expected = file.readAsStringSync();
    } catch (_) {
      content = expectedFile.readAsBytesSync();
      expected = file.readAsBytesSync();
    }

    expect(content, expected);
  }

  verifyNoMoreInteractions(mockLogger);
  verifyNoMoreInteractions(mockProgress);
  verifyNoMoreInteractions(mockPubUpdater);
}
