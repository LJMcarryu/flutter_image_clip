import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _snapshotPath = 'tool/api_snapshot.json';
const _entrypoints = <String>[
  'lib/flutter_image_clip.dart',
  'lib/image_processing/image_processor.dart',
];

void main(List<String> args) {
  final snapshotFile = File(_snapshotPath);
  final snapshot = _buildSnapshot();

  if (args.contains('--update')) {
    snapshotFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(snapshot)}\n',
    );
    stdout.writeln('API snapshot updated.');
    return;
  }

  if (!snapshotFile.existsSync()) {
    stderr.writeln(
      'API snapshot missing. Run: dart run $_snapshotPath --update',
    );
    exitCode = 1;
    return;
  }

  final expected =
      jsonDecode(snapshotFile.readAsStringSync()) as Map<String, Object?>;
  final expectedJson = const JsonEncoder.withIndent('  ').convert(expected);
  final actualJson = const JsonEncoder.withIndent('  ').convert(snapshot);

  if (expectedJson == actualJson) {
    stdout.writeln('API snapshot check passed.');
    return;
  }

  stderr.writeln('API snapshot check failed.');
  stderr.writeln('Run this command after intentional public API changes:');
  stderr.writeln('  dart run tool/check_api_snapshot.dart --update');
  exitCode = 1;
}

Map<String, Object?> _buildSnapshot() {
  final files = collectPublicApiFiles();

  final libraries = <Map<String, Object?>>[];
  for (final file in files.toList()..sort()) {
    final declarations = _publicDeclarationsFor(file);
    if (declarations.isEmpty) {
      continue;
    }
    libraries.add(<String, Object?>{
      'file': file,
      'declarations': declarations,
    });
  }

  return <String, Object?>{'entrypoints': _entrypoints, 'libraries': libraries};
}

Set<String> collectPublicApiFiles() {
  final files = <String>{};
  for (final entrypoint in _entrypoints) {
    _collectLibraryFiles(entrypoint, files);
  }
  return files;
}

void _collectLibraryFiles(String path, Set<String> files) {
  if (!files.add(path)) {
    return;
  }

  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Public API file is missing: $path');
  }

  final unit = parseApiFile(path);
  final baseUri = file.parent.uri;
  for (final directive in unit.directives) {
    if (directive is ExportDirective || directive is PartDirective) {
      final uri = switch (directive) {
        ExportDirective() => directive.uri.stringValue,
        PartDirective() => directive.uri.stringValue,
        _ => null,
      };
      if (uri == null ||
          uri.startsWith('dart:') ||
          uri.startsWith('package:')) {
        continue;
      }
      final resolved = baseUri.resolve(uri).toFilePath();
      _collectLibraryFiles(_relativePath(resolved), files);
    }
  }
}

List<String> _publicDeclarationsFor(String path) {
  final unit = parseApiFile(path);
  final declarations = <String>[];

  for (final declaration in unit.declarations) {
    switch (declaration) {
      case ClassDeclaration():
        if (isPrivateName(declaration.name.lexeme)) {
          continue;
        }
        declarations.add(_classSignature(declaration));
        declarations.addAll(_classMembers(declaration));
      case EnumDeclaration():
        if (isPrivateName(declaration.name.lexeme)) {
          continue;
        }
        declarations.add(_enumSignature(declaration));
        final enumName = declaration.name.lexeme;
        declarations.addAll(
          declaration.constants
              .where((constant) => !isPrivateName(constant.name.lexeme))
              .map(
                (constant) => '  enumValue $enumName.${constant.name.lexeme}',
              ),
        );
      case FunctionDeclaration():
        if (isPrivateName(declaration.name.lexeme)) {
          continue;
        }
        declarations.add(_functionSignature(declaration));
      case TopLevelVariableDeclaration():
        declarations.addAll(_variableSignatures(declaration, 'topLevel '));
      case ExtensionDeclaration():
        final name = declaration.name?.lexeme;
        if (name == null || isPrivateName(name)) {
          continue;
        }
        declarations.add('extension $name');
    }
  }

  return declarations..sort();
}

String _classSignature(ClassDeclaration declaration) {
  final abstractKeyword = declaration.abstractKeyword == null
      ? ''
      : 'abstract ';
  final typeParameters = declaration.typeParameters?.toSource() ?? '';
  return '${abstractKeyword}class ${declaration.name.lexeme}$typeParameters';
}

Iterable<String> _classMembers(ClassDeclaration declaration) sync* {
  final className = declaration.name.lexeme;
  for (final member in declaration.members) {
    switch (member) {
      case ConstructorDeclaration():
        final name = member.name?.lexeme;
        if (name != null && isPrivateName(name)) {
          continue;
        }
        final suffix = name == null ? '' : '.$name';
        yield '  constructor $className$suffix${_parameterList(member.parameters)}';
      case MethodDeclaration():
        if (isPrivateName(member.name.lexeme)) {
          continue;
        }
        final kind = member.isGetter
            ? 'getter'
            : member.isSetter
            ? 'setter'
            : 'method';
        yield '  $kind $className.${member.name.lexeme}${member.isGetter ? '' : _parameterList(member.parameters)}';
      case FieldDeclaration():
        yield* _variableSignatures(
          member,
          'field $className.',
        ).map((signature) => '  $signature');
    }
  }
}

String _enumSignature(EnumDeclaration declaration) {
  return 'enum ${declaration.name.lexeme}';
}

String _functionSignature(FunctionDeclaration declaration) {
  return 'function ${declaration.name.lexeme}${_parameterList(declaration.functionExpression.parameters)}';
}

Iterable<String> _variableSignatures(
  AnnotatedNode declaration,
  String prefix,
) sync* {
  final variables = switch (declaration) {
    TopLevelVariableDeclaration() => declaration.variables.variables,
    FieldDeclaration() => declaration.fields.variables,
    _ => const <VariableDeclaration>[],
  };
  for (final variable in variables) {
    if (isPrivateName(variable.name.lexeme)) {
      continue;
    }
    yield '$prefix${variable.name.lexeme}';
  }
}

String _parameterList(FormalParameterList? parameters) {
  if (parameters == null) {
    return '()';
  }
  final normalized = parameters.parameters
      .map((parameter) {
        final source = parameter.toSource();
        return source
            .replaceAll(RegExp(r'\s*=.*$'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      })
      .join(', ');
  return '($normalized)';
}

bool isPrivateName(String name) => name.startsWith('_');

String _relativePath(String absolutePath) {
  final root = Directory.current.absolute.path;
  final separator = Platform.pathSeparator;
  final prefix = root.endsWith(separator) ? root : '$root$separator';
  if (absolutePath.startsWith(prefix)) {
    return absolutePath.substring(prefix.length);
  }
  return absolutePath;
}

CompilationUnit parseApiFile(String path) {
  return parseFile(
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
}
