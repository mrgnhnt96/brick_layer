import 'package:autoequal/autoequal.dart';
import 'package:equatable/equatable.dart';

import 'package:brick_oven/domain/yaml_value.dart';
import 'package:brick_oven/src/exception.dart';
import 'package:brick_oven/utils/extensions/string_extensions.dart';

part 'variable.g.dart';

/// {@template variable}
/// Represents the variable values provided in the `brick_oven.yaml` file
/// {@endtemplate}
@autoequal
class Variable extends Equatable {
  /// {@macro variable}
  const Variable({
    required this.name,
    String? placeholder,
  }) : placeholder = placeholder ?? name;

  /// parses the [yaml] to [Variable]
  ///
  /// [yaml] must be a string and is the [placeholder] value
  factory Variable.fromYaml(YamlValue yaml, String name) {
    if (yaml.isError()) {
      throw VariableException(
        variable: name,
        reason: 'Invalid configuration',
      );
    }

    if (yaml.isNone()) {
      return Variable(name: name, placeholder: name);
    }

    if (!yaml.isString()) {
      throw VariableException(
        variable: name,
        reason: 'Expected type `String` or `null`',
      );
    }

    final placeholder = yaml.asString().value.trim();

    if (placeholder.isNotEmpty && placeholder.containsWhitespace()) {
      throw VariableException(
        variable: name,
        reason: 'Placeholder cannot contain whitespace',
      );
    }

    if (name.isNotEmpty && name.containsWhitespace()) {
      throw VariableException(
        variable: name,
        reason: 'Name cannot contain whitespace',
      );
    }

    return Variable(
      name: name,
      placeholder: placeholder,
    );
  }

  /// the name of variable to replace [placeholder]
  ///
  /// Will be wrapped as `{{#someCase}}{{{name}}}{{/someCase}}`
  final String name;

  /// the placeholder that currently lives in a file
  /// that will be replaced by [name]
  final String placeholder;

  @override
  List<Object?> get props => _$props;
}
