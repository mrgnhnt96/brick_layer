import 'package:autoequal/autoequal.dart';
import 'package:brick_oven/src/exception.dart';
import 'package:equatable/equatable.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'package:brick_oven/domain/brick_file.dart';
import 'package:brick_oven/domain/brick_path.dart';
import 'package:brick_oven/domain/brick_source.dart';
import 'package:brick_oven/domain/yaml_value.dart';
import 'package:brick_oven/utils/extensions.dart';

part 'brick.g.dart';

/// {@template brick}
/// Represents the brick configured in the `brick_oven.yaml` file
/// {@endtemplate}
@autoequal
class Brick extends Equatable {
  /// {@macro brick}
  Brick({
    required this.name,
    required this.source,
    required this.configuredDirs,
    required this.configuredFiles,
    this.excludePaths = const [],
    Logger? logger,
  })  : _fileSystem = const LocalFileSystem(),
        _logger = logger ?? Logger();

  /// provide
  @visibleForTesting
  const Brick.memory({
    required this.name,
    required this.source,
    required this.configuredDirs,
    required this.configuredFiles,
    required FileSystem fileSystem,
    this.excludePaths = const [],
    required Logger logger,
  })  : _fileSystem = fileSystem,
        _logger = logger;

  Brick._fromYaml({
    required this.name,
    required this.source,
    required this.configuredFiles,
    required this.configuredDirs,
    this.excludePaths = const [],
  })  : _fileSystem = const LocalFileSystem(),
        _logger = Logger();

  /// parses [yaml]
  factory Brick.fromYaml(String name, YamlMap? yaml) {
    final data = yaml?.data ?? <String, dynamic>{};
    late final BrickSource source;
    try {
      source = BrickSource.fromYaml(YamlValue.from(data.remove('source')));
    } on DirectoryException catch (e) {
      throw BrickException(brick: name, reason: e.message);
    } catch (_) {
      rethrow;
    }

    final filesData = YamlValue.from(data.remove('files'));

    Iterable<BrickFile> files() sync* {
      if (filesData.isNone()) {
        return;
      }

      if (!filesData.isYaml()) {
        throw FileException(
          file: name,
          reason: '`files` must be of type `Map`',
        );
      }

      for (final entry in filesData.asYaml().value.entries) {
        final path = entry.key as String;
        final yaml = YamlValue.from(entry.value);

        yield BrickFile.fromYaml(yaml, path: path);
      }
    }

    final pathsData = YamlValue.from(data.remove('dirs'));

    Iterable<BrickPath> paths() sync* {
      if (pathsData.isNone()) {
        return;
      }

      if (!pathsData.isYaml()) {
        throw BrickException(
          brick: name,
          reason: '`dirs` must be a of type `Map`',
        );
      }

      for (final entry in pathsData.asYaml().value.entries) {
        final path = entry.key as String;

        yield BrickPath.fromYaml(path, YamlValue.from(entry.value));
      }
    }

    final excludedPaths = YamlValue.from(data.remove('exclude'));

    Iterable<String> exclude() sync* {
      if (excludedPaths.isNone()) {
        return;
      }

      if (!excludedPaths.isList() && !excludedPaths.isString()) {
        throw BrickException(
          brick: name,
          reason: '`exclude` must be a of type `List`or `String`',
        );
      }

      final paths = <YamlValue>[];

      if (excludedPaths.isList()) {
        paths.addAll(excludedPaths.asList().value.map(YamlValue.from));
      } else {
        paths.add(excludedPaths.asString());
      }

      for (final path in paths) {
        if (path.isString()) {
          yield path.asString().value;
        } else {
          final variableError = VariableException(
            variable: 'exclude',
            reason: 'Expected a `String`, got `${path.value}` '
                // ignore: avoid_dynamic_calls
                '(${path.value.runtimeType})',
          );

          throw BrickException(
            brick: name,
            reason: variableError.message,
          );
        }
      }
    }

    if (data.isNotEmpty) {
      throw BrickException(
        brick: name,
        reason: 'Unknown keys: "${data.keys.join('", "')}"',
      );
    }

    return Brick._fromYaml(
      configuredFiles: files().toList(),
      source: source,
      name: name,
      configuredDirs: paths().toList(),
      excludePaths: exclude().toList(),
    );
  }

  /// the name of the brick
  final String name;

  /// the source of the content that the brick will create
  final BrickSource source;

  /// the configured files that will alter/update the [source] files
  final List<BrickFile> configuredFiles;

  /// the configured directories that will alter/update the paths of the [source] files
  final List<BrickPath> configuredDirs;

  /// paths to be excluded from the [source]
  final List<String> excludePaths;

  @ignoreAutoequal
  final FileSystem _fileSystem;

  @ignoreAutoequal
  final Logger _logger;

  /// writes the brick's files, from the [source]'s files.
  ///
  /// targets: [output] (bricks) -> [name] -> __brick__
  void cook({String output = 'bricks', bool watch = false}) {
    final done = _logger.progress('Writing Brick: $name');

    void putInTheOven() {
      final targetDir = join(
        output,
        name,
        '__brick__',
      );

      final directory = _fileSystem.directory(targetDir);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }

      final files = source.mergeFilesAndConfig(
        configuredFiles,
        excludedPaths: excludePaths,
      );
      final count = files.length;

      for (final file in files) {
        file.writeTargetFile(
          targetDir: targetDir,
          sourceFile: _fileSystem.file(source.fromSourcePath(file)),
          configuredDirs: configuredDirs,
          fileSystem: _fileSystem,
        );
      }

      done.complete('$name: $count file${count == 1 ? '' : 's'}');
    }

    final watcher = source.watcher;

    if (watch && watcher != null) {
      watcher
        ..addEvent(putInTheOven)
        ..start();

      if (watcher.hasRun) {
        return;
      }
    }

    putInTheOven();
  }

  @override
  List<Object?> get props => _$props;
}
