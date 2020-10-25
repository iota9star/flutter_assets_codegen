import 'package:flutter_assets_codegen/annotation.dart';
part 'r.r.dart';

@Ren(
  dir: "assets",
  deep: 1,
  renMode: RenMode.all,
  assetNameStyle: AssetNameStyle.camelCase,
  pubspecStyle: PubspecStyle.dir,
)
class _R {
  const _R._();
}
