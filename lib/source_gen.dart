import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:flutter_assets_codegen/annotation.dart';
import 'package:flutter_assets_codegen/templates.dart';
import 'package:generic_reader/generic_reader.dart';
import 'package:logging/logging.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart' as path;
import 'package:recase/recase.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';

const Symbol logKey = #buildLog;

final _default = Logger('build.fallback');

/// The log instance for the currently running BuildStep.
///
/// Will be `null` when not running within a build.
Logger get log => Zone.current[logKey] as Logger ?? _default;

class R4Annotation extends GeneratorForAnnotation<Ren> {
  final GenericReader _reader = GenericReader();
  final String _projectPath = path.current + Platform.pathSeparator;
  Ren _ren;

  Ren _renDecoder(ConstantReader cr) {
    final String dir = cr.peek("dir")?.stringValue;
    final String extensionName = cr.peek("aliasClassName")?.stringValue;
    final int deep = cr.peek("deep")?.intValue;
    final RenMode renMode = _reader.getEnum<RenMode>(cr.peek("renMode"));
    final AssetNameStyle assetNameStyle =
        _reader.getEnum<AssetNameStyle>(cr.peek("assetNameStyle"));
    final PubspecStyle pubspecStyle =
        _reader.getEnum<PubspecStyle>(cr.peek("pubspecStyle"));
    return Ren(
      aliasClassName: extensionName,
      deep: deep ?? 1,
      dir: dir,
      renMode: renMode ?? RenMode.all,
      assetNameStyle: assetNameStyle ?? AssetNameStyle.camelCase,
      pubspecStyle: pubspecStyle ?? PubspecStyle.dir,
    );
  }

  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader cr,
    BuildStep buildStep,
  ) async {
    _reader.addDecoder<Ren>(_renDecoder);
    _ren = _reader.get<Ren>(cr);
    log.info("============================================================>\n");
    log.info(" <> annotation <>");
    log.info(" => aliasClassName  : ${_ren.aliasClassName}");
    log.info(" => dir             : ${_ren.dir}");
    log.info(" => deep            : ${_ren.deep}");
    log.info(" => renMode         : ${_ren.renMode}");
    log.info(" => assetNameStyle  : ${_ren.assetNameStyle}");
    log.info(" <> annotation <>\n");
    final Directory directory = Directory(_projectPath + _ren.dir);
    if (!directory.existsSync()) {
      log.info(" => directory[${_ren.dir}] not found. ignore...\n");
      return null;
    }
    if ([RenMode.all, RenMode.onlyPubspec].contains(_ren.renMode)) {
      _generatePubspec(directory);
    }
    String output;
    if ([RenMode.all, RenMode.onlyRClass].contains(_ren.renMode)) {
      output = _generateRClass(directory, element);
    }
    log.info("<============================================================");
    return output;
  }

  void _generatePubspec(Directory directory) {
    final File pubspecFile = File(_projectPath + "pubspec.yaml");
    if (pubspecFile.existsSync()) {
      final String pubspecStr = pubspecFile.readAsStringSync();
      final YamlMap oldSource = loadYaml(pubspecStr);
      // flutter:
      //   assets:
      //     - xxxx/
      log.info(" <> pubspec.yaml <>");
      final List<String> paths = directory
          .listSync(recursive: true)
          .where((e) => PubspecStyle.dir == _ren.pubspecStyle
              ? FileSystemEntity.isDirectorySync(e.path)
              : FileSystemEntity.isFileSync(e.path))
          .map((e) => _transformFile2AssetPath(e))
          .toList();
      log.info(" <> pubspec.yaml <>\n");
      if (!oldSource.containsKey("flutter") || oldSource["flutter"] == null) {
        final Template tpl = Template(pubspecEmptyTemplate);
        final String output = tpl.renderString({"paths": paths});
        if (oldSource.containsKey("flutter")) {
          return pubspecFile.writeAsStringSync(
            pubspecStr.replaceAll(RegExp("^flutter:.*", multiLine: true), "") +
                output,
          );
        }
        return pubspecFile.writeAsStringSync(output, mode: FileMode.append);
      }
      final YamlMap flutterNodeYamlMap = oldSource["flutter"];
      final String firstNodeKey =
          flutterNodeYamlMap?.nodes?.keys?.getOrNull(0)?.value as String;
      String indentStr;
      if (firstNodeKey.isNotBlank) {
        final RegExpMatch matched = RegExp(
          "flutter:.*\n+(.+?)$firstNodeKey",
          multiLine: true,
        ).firstMatch(pubspecStr);
        indentStr = matched.group(1);
      }
      final String indent =
          indentStr.isNullOrBlank ? "  " : indentStr.replaceAll("\n", "");
      final Template tpl = Template(pubspecAssetsTemplate);
      final String output = tpl.renderString({
        "paths": paths,
        "indent": indent,
      });
      if (flutterNodeYamlMap?.containsKey("assets") != true) {
        final int endOffset = flutterNodeYamlMap.span.end.offset;
        return pubspecFile.writeAsStringSync(
          pubspecStr.replaceRange(endOffset, endOffset, output),
        );
      }
      final YamlNode assetsNode = flutterNodeYamlMap["assets"];
      if (assetsNode is YamlList) {
        final RegExpMatch matched = RegExp(
          "(.*assets:(.*\n+.*)+?)- ${assetsNode.nodes.first.value}",
          multiLine: true,
        ).firstMatch(pubspecStr);
        final String offsetStr = matched.group(1);
        final int startOffset = assetsNode.span.start.offset - offsetStr.length;
        final int endOffset = assetsNode.span.end.offset;
        pubspecFile.writeAsStringSync(
          pubspecStr.replaceRange(startOffset, endOffset, output),
        );
      }
    }
  }

  String _transformFile2AssetPath(final FileSystemEntity file) {
    final path = file.path
        .replaceAll(_projectPath, "")
        .replaceAll(Platform.pathSeparator, "/");
    log.info(" <= $path");
    if (PubspecStyle.dir == _ren.pubspecStyle) {
      return "$path/";
    }
    return path;
  }

  String _generateRClass(final Directory directory, final Element element) {
    log.info(" <> R class <>");
    final _Asset asset = _Asset();
    final String relativePath = directory.path.replaceAll(_projectPath, "");
    asset
      ..isDir = true
      ..className =
          "_" + relativePath.replaceAll(Platform.pathSeparator, "_").pascalCase
      ..fieldName = path.basename(directory.path).camelCase
      ..path = relativePath.replaceAll(Platform.pathSeparator, "/") + "/"
      ..filePath = relativePath.replaceAll(Platform.pathSeparator, "/");
    _readFileTree(directory, asset);
    asset.assets.sort((a, b) {
      if (a.isDir) return -1;
      if (b.isDir) return 1;
      return 0;
    });
    log.info(" <> R class <>\n");
    final _Extension extension = _Extension();
    extension
      ..extensionName = _ren.aliasClassName ?? element.name.substring(1)
      ..className = element.name
      ..asset = asset;
    final Template at = Template(assetsTemplate, name: "assetsLayout");
    final resolver = (String name) {
      if (name == 'assetsLayout') {
        return at;
      }
    };
    final Template et = Template(extensionTemplate, partialResolver: resolver);
    return et.renderString(extension.toJson());
  }

  void _readFileTree(final Directory directory, final _Asset parent) {
    final List<FileSystemEntity> files = directory.listSync();
    final List<_Asset> assets = [];
    _Asset asset;
    String relativePath;
    for (final FileSystemEntity file in files) {
      asset = _Asset();
      relativePath = file.path.replaceAll(_projectPath, "");
      final String fieldName = _getFieldName(path.basename(file.path));
      final String filePath =
          relativePath.replaceAll(Platform.pathSeparator, "/");
      log.info(" <= ${parent.className}.$fieldName [ $filePath ]");
      if (FileSystemEntity.isFileSync(file.path)) {
        asset
          ..isDir = false
          ..baseName = path.basename(file.path)
          ..fieldName = fieldName
          ..path = filePath
          ..filePath = filePath;
      } else {
        asset
          ..isDir = true
          ..baseName = path.basename(file.path)
          ..className = "_" +
              relativePath.replaceAll(Platform.pathSeparator, "_").pascalCase
          ..fieldName = fieldName
          ..path = filePath + "/"
          ..filePath = filePath;
        _readFileTree(file, asset);
      }
      assets.add(asset);
    }
    assets.sort((a, b) {
      if (a.isDir) return -1;
      if (b.isDir) return 1;
      return 0;
    });
    parent.assets = assets;
  }

  String _getFieldName(final String str) {
    switch (_ren.assetNameStyle) {
      case AssetNameStyle.snakeCase:
        return str?.snakeCase;
        break;
      case AssetNameStyle.camelCase:
        return str?.camelCase;
        break;
      case AssetNameStyle.screamingSnakeCase:
        return str?.constantCase;
        break;
    }
    return str?.camelCase;
  }
}

class _Extension {
  String extensionName;
  String className;
  _Asset asset;

  _Extension({
    this.extensionName,
    this.className,
    this.asset,
  });

  _Extension.fromJson(Map<String, dynamic> json) {
    extensionName = json['extensionName'];
    className = json['className'];
    asset = json['asset'] != null ? new _Asset.fromJson(json['asset']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['extensionName'] = this.extensionName;
    data['className'] = this.className;
    if (this.asset != null) {
      data['asset'] = this.asset.toJson();
    }
    return data;
  }
}

class _Asset {
  String baseName;
  String fieldName;
  String className;
  String path;
  String filePath;
  bool isDir;
  List<_Asset> assets;

  _Asset({
    this.baseName,
    this.fieldName,
    this.className,
    this.path,
    this.filePath,
    this.isDir,
    this.assets,
  });

  _Asset.fromJson(Map<String, dynamic> json) {
    baseName = json['baseName'];
    fieldName = json['fieldName'];
    className = json['className'];
    path = json['path'];
    filePath = json['filePath'];
    isDir = json['isDir'];
    if (json['assets'] != null) {
      assets = new List<_Asset>();
      json['assets'].forEach((v) {
        assets.add(new _Asset.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['baseName'] = this.baseName;
    data['fieldName'] = this.fieldName;
    data['className'] = this.className;
    data['path'] = this.path;
    data['filePath'] = this.filePath;
    data['isDir'] = this.isDir;
    if (this.assets != null) {
      data['assets'] = this.assets.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

extension IterableExt<T> on Iterable<T> {
  bool get isNullOrEmpty => this == null || this.isEmpty;

  bool get isNotEmpty => !this.isNullOrEmpty;

  T getOrNull(final int index) {
    if (this.isNullOrEmpty) return null;
    return this.elementAt(index);
  }
}

extension MapExt<K, V> on Map<K, V> {
  bool get isNullOrEmpty => this == null || this.isEmpty;

  bool get isNotEmpty => !this.isNullOrEmpty;

  V getOrNull(K key) => this == null ? null : this[key];
}

extension StringExt on String {
  bool get isNullOrBlank => this == null || this.isEmpty;

  bool get isNotBlank => !this.isNullOrBlank;
}
