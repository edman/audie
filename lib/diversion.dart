import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:diversion/src/annotations.dart';
import 'package:diversion/src/engine.dart';
import 'package:source_gen/source_gen.dart';

export 'src/annotations.dart';

final engine = DepEngine();

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
final moduleType = TypeChecker.fromRuntime(module.runtimeType);
final componentType = TypeChecker.fromRuntime(component.runtimeType);

class DiversionGenerator extends Generator {
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    // Visit all constructors annotated with @inject.
    for (final element in library.allElements.whereType<ClassElement>()) {
      for (final constructor in element.constructors) {
        final annotated = injectType.firstAnnotationOf(constructor);
        if (annotated != null) _processInjectConstructor(constructor);
      }
    }
    // Visit all classes annotated with @inject.
    library
        .annotatedWith(injectType)
        .where((a) => a.element is ClassElement)
        .forEach((annotated) => _processInjectClass(annotated.element));
    // Visit all classes annotated with @module.
    library
        .annotatedWith(moduleType)
        .where((a) => a.element is ClassElement)
        .forEach((annotated) => _processModuleClass(annotated.element));
    // Visit all classes annotated with @component.
    final components = library
        .annotatedWith(componentType)
        .where((a) => a.element is ClassElement);

    String out = '';
    for (final annotated in components) {
      out += await _generateComponent(annotated.element as ClassElement);
    }

    log('engine=$engine');
    log('\n$out');
    return out;
  }
}

Future<String> _generateComponent(ClassElement component) async {
  String out = 'class _\$${component.name} implements ${component.name} {\n';
  for (final method in component.methods) {
    out += '@override\n';
    out += '${method.returnType} ${method.name}() {\n';
    out += 'return _make${method.returnType}();\n';
    out += '}\n';
    method.name;
  }
  await for (final method in _processComponentClass(component))
    out += _generateMethod(method);
  out += "}\n";
  return out;
}

String _variableName(DartType type) =>
    type.name[0].toLowerCase() + type.name.substring(1);

String _generateMethod(Signature method) {
  String out = '${method.type} _make${method.type}() {\n';
  final variableNames = List<String>();
  for (final param in method.parameters) {
    final name = _variableName(param);
    variableNames.add(name);
    out += 'final $name = _make$param();\n';
  }

  final create = engine.registry[method.type];
  String function = '';
  if (create is ProviderFunction)
    function = '${create.scope.name}.${create.function.name}';
  else
    function = '${create.function.returnType}';

  out += 'return ${function}(${variableNames.join(', ')});\n';
  out += '}\n';
  return out;
}

void _processInjectClass(ClassElement element) {
  log('INJECT: class=${element.name} ');
  element.constructors.forEach((constructor) {
    _processInjectConstructor(constructor);
  });
}

void _processInjectConstructor(ConstructorElement constructor) {
  log('INJECT_CONSTRUCTOR: constructor=$constructor ');
  engine.registerConstructor(constructor);
}

void _processModuleClass(ClassElement element) {
  log('MODULE: name=${element.name} kind=${element.kind}');
  element.methods.forEach((method) => _processProviderMethod(element, method));
}

void _processProviderMethod(ClassElement scope, MethodElement method) {
  log('PROVIDER_METHOD: method=$method ');
  engine.registerProvider(scope, method);
}

Stream<Signature> _processComponentClass(ClassElement element) async* {
  log('COMPONENT: name=${element.name} kind=${element.kind}');
  for (final method in element.methods)
    await for (final signature in _processComponentFunction(method))
      yield signature;
}

Stream<Signature> _processComponentFunction(
    FunctionTypedElement function) async* {
  log('COMPONENT_METHOD: method=${function}');
  log('\tengine.contains=${engine.contains(function.returnType)}');
  await for (final signature in engine.recipe(function.returnType)) {
    log('\trecipe=$signature');
    yield signature;
  }
}

void log(msg) {
  print('----------------------------------> $msg');
}
