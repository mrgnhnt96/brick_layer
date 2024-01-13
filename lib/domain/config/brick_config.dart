import 'package:brick_oven/domain/config/brick_config_entry.dart';
import 'package:brick_oven/domain/config/directory_config.dart';
import 'package:brick_oven/domain/config/file_config.dart';
import 'package:brick_oven/domain/config/mason_brick_config.dart';
import 'package:brick_oven/domain/config/partial_config.dart';
import 'package:brick_oven/domain/config/string_or_entry.dart';
import 'package:brick_oven/domain/config/url_config.dart';
import 'package:brick_oven/utils/vars_mixin.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

part 'brick_config.g.dart';

@JsonSerializable()
class BrickConfig extends BrickConfigEntry with EquatableMixin, VarsMixin {
  BrickConfig({
    required String sourcePath,
    required StringOr<MasonBrickConfig>? masonBrickConfig,
    required this.fileConfigs,
    required this.directoryConfigs,
    required this.urlConfigs,
    required this.partialConfigs,
    required this.exclude,
    required this.configPath,
  })  : sourcePath = configPath == null
            ? sourcePath
            : p.join(p.dirname(configPath), sourcePath),
        masonBrickConfig = configPath == null
            ? masonBrickConfig
            : masonBrickConfig == null
                ? null
                : masonBrickConfig.isString == true
                    ? StringOr(
                        string: p.join(
                          p.dirname(configPath),
                          masonBrickConfig.string,
                        ),
                      )
                    : StringOr(
                        object: MasonBrickConfig(
                          path: p.join(
                            p.dirname(configPath),
                            masonBrickConfig.object!.path,
                          ),
                          ignoreVars: masonBrickConfig.object!.ignoreVars,
                        ),
                      ),
        assert(
          configPath == null || configPath.endsWith('brick_oven.yaml'),
          'configPath must end with brick_oven.yaml',
        );

  BrickConfig.self(BrickConfig self)
      : this(
          sourcePath: self.sourcePath,
          masonBrickConfig: self.masonBrickConfig,
          fileConfigs: self.fileConfigs,
          directoryConfigs: self.directoryConfigs,
          urlConfigs: self.urlConfigs,
          partialConfigs: self.partialConfigs,
          exclude: self.exclude,
          configPath: self.configPath,
        );

  factory BrickConfig.fromJson(
    Map json, {
    required String? configPath,
  }) {
    json['config_path'] = configPath;

    return _$BrickConfigFromJson(json);
  }

  @JsonKey(name: 'source')
  final String sourcePath;
  @JsonKey(name: 'brick_config')
  final StringOr<MasonBrickConfig>? masonBrickConfig;
  @JsonKey(name: 'files')
  final Map<String, FileConfig>? fileConfigs;
  @JsonKey(name: 'dirs')
  final Map<String, DirectoryConfig>? directoryConfigs;
  @JsonKey(name: 'urls')
  final Map<String, UrlConfig>? urlConfigs;
  @JsonKey(name: 'partials')
  final Map<String, PartialConfig?>? partialConfigs;
  final List<String>? exclude;
  final String? configPath;

  @override
  List<Iterable<(String, String)>> get combine => [
        ...?fileConfigs?.values.map((e) => e.varsMap),
        ...?directoryConfigs?.values.map((e) => e.varsMap),
        ...?urlConfigs?.values.map((e) => e.varsMap),
        ...?partialConfigs?.values.map((e) => e?.varsMap ?? []),
      ];

  @override
  @override
  Map<String, dynamic> toJson() => _$BrickConfigToJson(this);

  @override
  List<Object?> get props => _$props;
}
