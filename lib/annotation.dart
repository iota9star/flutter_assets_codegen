library flutter_assets_codegen;

class Ren {
  final String aliasClassName;
  final String dir;
  final int deep;
  final RenMode renMode;
  final AssetNameStyle assetNameStyle;
  final PubspecStyle pubspecStyle;

  const Ren({
    this.aliasClassName,
    this.dir,
    this.deep,
    this.renMode,
    this.assetNameStyle,
    this.pubspecStyle,
  });
}

enum AssetNameStyle {
  /// eg: snack_case
  snakeCase,

  /// eg: camelCase
  camelCase,

  /// eg: SCREAMING_SNAKE_CASE
  screamingSnakeCase,
}

enum RenMode {
  all,
  onlyPubspec,
  onlyRClass,
}

enum PubspecStyle {
  dir,
  file,
}
