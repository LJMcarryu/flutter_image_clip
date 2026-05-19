import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

import 'check_api_snapshot.dart' as api_snapshot;

void main() {
  final failures = <String>[];
  final files = api_snapshot.collectPublicApiFiles();

  for (final file in files.toList()..sort()) {
    final unit = api_snapshot.parseApiFile(file);
    for (final declaration in unit.declarations) {
      switch (declaration) {
        case ClassDeclaration():
          if (api_snapshot.isPrivateName(declaration.name.lexeme)) {
            continue;
          }
          _requireDoc(failures, file, declaration, 'class');
          for (final member in declaration.members) {
            _checkClassMember(failures, file, declaration.name.lexeme, member);
          }
        case EnumDeclaration():
          if (api_snapshot.isPrivateName(declaration.name.lexeme)) {
            continue;
          }
          _requireDoc(failures, file, declaration, 'enum');
        case FunctionDeclaration():
          if (api_snapshot.isPrivateName(declaration.name.lexeme)) {
            continue;
          }
          _requireDoc(failures, file, declaration, 'function');
        case TopLevelVariableDeclaration():
          for (final variable in declaration.variables.variables) {
            if (!api_snapshot.isPrivateName(variable.name.lexeme)) {
              _requireDoc(failures, file, declaration, 'top-level variable');
            }
          }
      }
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('Public API documentation check passed.');
    return;
  }

  stderr.writeln('Public API documentation check failed:');
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}

void _checkClassMember(
  List<String> failures,
  String file,
  String className,
  ClassMember member,
) {
  switch (member) {
    case ConstructorDeclaration():
      final name = member.name?.lexeme;
      if (name != null && api_snapshot.isPrivateName(name)) {
        return;
      }
      _requireDoc(failures, file, member, '$className constructor');
    case MethodDeclaration():
      if (api_snapshot.isPrivateName(member.name.lexeme)) {
        return;
      }
      _requireDoc(failures, file, member, '$className member');
    case FieldDeclaration():
      for (final variable in member.fields.variables) {
        if (!api_snapshot.isPrivateName(variable.name.lexeme)) {
          _requireDoc(failures, file, member, '$className field');
        }
      }
  }
}

void _requireDoc(
  List<String> failures,
  String file,
  AnnotatedNode node,
  String kind,
) {
  if (_hasOverride(node)) {
    return;
  }
  if (node.documentationComment != null) {
    return;
  }
  final root = node.root;
  final line = root is CompilationUnit
      ? root.lineInfo.getLocation(node.offset).lineNumber
      : 1;
  failures.add('$file:$line missing dartdoc for $kind');
}

bool _hasOverride(AnnotatedNode node) {
  return node.metadata.any((annotation) {
    return annotation.name.name == 'override';
  });
}
