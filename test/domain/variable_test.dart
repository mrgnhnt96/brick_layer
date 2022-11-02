import 'package:brick_oven/domain/variable.dart';
import 'package:brick_oven/domain/yaml_value.dart';
import 'package:brick_oven/enums/mustache_format.dart';
import 'package:brick_oven/src/exception.dart';
import 'package:test/test.dart';

import '../utils/fakes.dart';

void main() {
  const name = 'scooby-doo';
  const placeholder = 'dog';

  test('can be instanciated', () {
    const instance = Variable(name: name, placeholder: 'placeholder');

    expect(instance, isNotNull);
  });

  group('#fromYaml', () {
    test('parses everything when provided', () {
      final result =
          Variable.fromYaml(name, const YamlValue.string(placeholder));

      expect(result, const Variable(name: name, placeholder: placeholder));
    });

    test('parses everything except for placeholder', () {
      final result = Variable.fromYaml(name, null);

      expect(result, const Variable(name: name));
    });

    test('throws arguement error when name is missing', () {
      expect(
        () => Variable.fromYaml(name, const YamlValue.none()),
        throwsA(isA<ConfigException>()),
      );
    });

    test('throws argument error when extra keys are provided', () {
      expect(
        () => Variable.fromYaml(
          name,
          YamlValue.yaml(FakeYamlMap(<String, dynamic>{'extra': 'key'})),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('#from', () {
    test('can parse null when provided', () {
      expect(() => Variable.from('', null), returnsNormally);
    });

    test('can parse String when provided', () {
      expect(() => Variable.from('', 'value'), returnsNormally);
    });

    test('can parse yamlMap when provided', () {
      expect(
        () => Variable.from(
          '',
          'placeholder',
        ),
        returnsNormally,
      );
    });

    test('throws when yaml is map', () {
      expect(
        () => Variable.from(
          '',
          FakeYamlMap(<String, dynamic>{'key': 'value'}),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('#formatName', () {
    test('returns the formatted name', () {
      const variable = Variable(name: name);

      expect(
        variable.formatName(MustacheFormat.camelCase),
        '{{#camelCase}}{{{$name}}}{{/camelCase}}',
      );
    });
  });
}
