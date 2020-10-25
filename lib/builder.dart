import 'package:build/build.dart';
import 'package:flutter_assets_codegen/source_gen.dart';
import 'package:source_gen/source_gen.dart';

Builder handleRenBuilder(BuilderOptions options) => PartBuilder(
      [R4Annotation()],
      ".r.dart",
    );
