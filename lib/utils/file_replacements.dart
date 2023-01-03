import 'package:brick_oven/domain/partial.dart';
import 'package:brick_oven/domain/file_write_result.dart';
import 'package:brick_oven/domain/content_replacement.dart';
import 'package:brick_oven/domain/variable.dart';
import 'package:brick_oven/enums/mustache_tag.dart';
import 'package:brick_oven/enums/mustache_section.dart';
import 'package:brick_oven/src/exception.dart';
import 'package:brick_oven/utils/constants.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

/// {@template file_replacements}
/// the methods to replace variables and partials in a file
/// {@endtemplate}
mixin FileReplacements {
  /// the placeholder when replacing sections
  @visibleForTesting
  static const sectionSetUp = '---set-up-section---';

  /// writes the [targetFile] content using the [sourceFile]'s content and
  /// replacing the [variables] and [partials] with their configured values
  ///
  /// [outOfFileVariables] are variables that are not configured in the
  /// brick_oven.yaml file, they are variables from the brick_oven project\
  /// [outOfFileVariables] are not included in the sync
  /// (brick.yaml or brick_oven.yaml) list
  FileWriteResult writeFile({
    required File targetFile,
    required File sourceFile,
    required List<Variable> variables,
    required List<Variable> outOfFileVariables,
    required List<Partial> partials,
    required FileSystem? fileSystem,
    required Logger logger,
  }) {
    if (variables.isEmpty && partials.isEmpty) {
      sourceFile.copySync(targetFile.path);

      return const FileWriteResult.empty();
    }

    // ignore: parameter_assignments
    variables = [...variables, ...outOfFileVariables];

    /// used to check if variable/partials is goes unused
    final usedVariables = <String>{};
    final usedPartials = <String>{};

    if (!sourceFile.existsSync()) {
      logger.warn('source file does not exist: ${sourceFile.path}');
      return const FileWriteResult.empty();
    }

    var content = sourceFile.readAsStringSync();

    for (final variable in variables) {
      // formats the content
      final sectionResult = checkForSections(content, variable);
      content = sectionResult.content;
      if (sectionResult.used.isNotEmpty) {
        usedVariables.addAll(sectionResult.used);
      }

      final variableResult = checkForVariables(content, variable);
      content = variableResult.content;
      usedVariables.addAll(variableResult.used);
    }

    final partialsResult =
        checkForPartials(partials: partials, content: content);
    content = partialsResult.content;
    usedPartials.addAll(partialsResult.used);

    final ignoreVariables = {
      ...outOfFileVariables.map((v) => v.name),
      kIndexValue,
    };

    final variableNames = variables.map((v) => v.name).toSet();
    final unusedVariables =
        variableNames.difference({...usedVariables, ...ignoreVariables});

    if (unusedVariables.isNotEmpty) {
      final vars = '"${unusedVariables.map((e) => e).join('", "')}"';
      logger.warn(
        'Unused variables ($vars) in `${sourceFile.path}`',
      );
    }

    targetFile.writeAsStringSync(content);

    return FileWriteResult(
      usedVariables: usedVariables.toSet(),
      usedPartials: usedPartials.toSet(),
    );
  }

  /// writes the [partials] to the [content]
  @visibleForTesting
  ContentReplacement checkForPartials({
    required String content,
    required Iterable<Partial> partials,
  }) {
    var newContent = content;

    final partialsUsed = <String>{};

    for (final partial in partials) {
      final partialPattern =
          RegExp(r'.*\bpartials\.' '${partial.name}' r'\b.*');
      final compareContent = newContent;
      newContent =
          newContent.replaceAll(partialPattern, partial.toPartialInput());

      if (compareContent != newContent) {
        partialsUsed.add(partial.path);
      }
    }

    return ContentReplacement(content: newContent, used: partialsUsed);
  }

  /// the pattern to find sections (sections) within the content
  @visibleForTesting
  RegExp get sectionSetupPattern =>
      RegExp('.*$sectionSetUp' r'({{[\^#/]\S+}}).*');

  /// the pattern to find sections within the content
  @visibleForTesting
  RegExp sectionPattern(Variable variable) =>
      RegExp(r'(\w+)' '${variable.placeholder}');

  /// checks the [content] for sections (sections) and replaces them with the
  /// [variable]'s value
  @visibleForTesting
  ContentReplacement checkForSections(String content, Variable variable) {
    var isVariableUsed = false;

    final setUpSections = content.replaceAllMapped(
      sectionPattern(variable),
      (match) {
        final possibleSection = match.group(1);
        final section = MustacheSection.values.findFrom(possibleSection);

        // if section is found, then replace the content
        if (section == null) {
          return match.group(0)!;
        }

        isVariableUsed = true;

        final formattedSection = section.format(variable.name);

        return '$sectionSetUp$formattedSection';
      },
    );

    // remove the section setup and all pre/post content
    final sectioned = setUpSections.replaceAllMapped(
      sectionSetupPattern,
      (match) {
        return match.group(1)!;
      },
    );

    // remove all extra line breaks before & after the section
    final _ = sectioned.replaceAllMapped(
      RegExp(r'(\n*)({{[#^/][\w-]+}})$(\n*)', multiLine: true),
      (match) {
        var before = '';
        var after = '';

        final beforeMatch = match.group(1);
        if (beforeMatch != null && beforeMatch.isNotEmpty) {
          before = '\n';
        }

        final afterMatch = match.group(3);
        if (afterMatch != null && afterMatch.isNotEmpty) {
          after = '\n';
        }

        isVariableUsed = true;
        return '$before${match.group(2)!}$after';
      },
    );

    return ContentReplacement(
      content: sectioned,
      used: {
        if (isVariableUsed) variable.name,
      },
    );
  }

  /// the pattern to find variables within the content
  @visibleForTesting
  RegExp variablePattern(Variable variable) => RegExp(
        r'(\{*\S*)'
        '${variable.placeholder}'
        r'(?:b(?:race)?(\d+))?(\w*\}*)',
      );

  /// replaces the [variable] in the [content]
  @visibleForTesting
  ContentReplacement checkForVariables(
    String content,
    Variable variable,
  ) {
    var isVariableUsed = false;

    final newContent = content.replaceAllMapped(
      variablePattern(variable),
      (match) {
        final completeMatch = match.group(0) ?? '';

        final braceCount = int.tryParse(match.group(2) ?? '');
        final wrapWithBraces = braceCount != null;

        if (wrapWithBraces && (braceCount < 2 || braceCount > 3)) {
          throw VariableException(
            variable: completeMatch,
            reason: 'Wrap with braces must be 2 or 3, '
                'but was $braceCount',
          );
        }

        final startsWithBracket =
            RegExp(r'^\{+(?![/^#])$').hasMatch(match.group(1) ?? '');
        final isTag = RegExp(r'^\{+[/^#]').hasMatch(match.group(1) ?? '');
        final endsWithBracket = RegExp(r'\}+$').hasMatch(match.group(3) ?? '');

        if (isTag && endsWithBracket) {
          return completeMatch;
        }

        var startDeliminator = '{';
        var endDeliminator = '}';
        var totalBraceCount = braceCount ?? 2;

        var startDeliminatorSection = '';
        var endDeliminatorSection = '';

        if (startsWithBracket || endsWithBracket) {
          startDeliminatorSection = '{{=<< >>=}}';
          endDeliminatorSection = '<<={{ }}=>>';

          startDeliminator = '<';
          endDeliminator = '>';
          totalBraceCount = 2;
        }

        String result;
        var suffix = '';
        final prefixResult = checkForVariables(match.group(1)!, variable);
        final prefix = prefixResult.content;
        if (prefixResult.used.isNotEmpty) {
          isVariableUsed = true;
        }

        final possibleTag = match.group(3);

        final tag = MustacheTag.values.findFrom(possibleTag);

        if (tag == null) {
          if (possibleTag != null) {
            suffix = possibleTag;
          }

          // the `kDefaultBraces` is not used here to allow unescaping
          final startBraces = startDeliminator * totalBraceCount;
          final endBraces = endDeliminator * totalBraceCount;

          result = '$startBraces${variable.name}$endBraces';
        } else {
          // format the variable
          suffix = MustacheTag.values.suffixFrom(possibleTag) ?? '';
          result = tag.wrap(
            variable.name,
            braceCount: braceCount,
            startDeliminator: startDeliminator,
            endDeliminator: endDeliminator,
          );
        }

        isVariableUsed = true;

        return '$startDeliminatorSection'
            '$prefix'
            '$result'
            '$suffix'
            '$endDeliminatorSection';
      },
    );

    return ContentReplacement(
      content: newContent,
      used: {
        if (isVariableUsed) variable.name,
      },
    );
  }
}
