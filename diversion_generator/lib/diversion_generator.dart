import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:diversion/diversion.dart';
import 'package:diversion_generator/src/engine.dart';
import 'package:source_gen/source_gen.dart';

final engine = DepEngine();

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
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
  log('COMPONENT_GENERATE: name=${component}');
  String makers = '';
  await for (final method in _processComponentClass(component))
    makers += _generateMethod(method);
  for (final method in component.methods.where((m) => m.isAbstract))
    out += '@override\n' +
        '${method.returnType} ${method.name}() => ' +
        '${_makerName(method.returnType)}();\n\n';
  out += makers;
  out += "}\n";
  return out;
}

String _makerName(DartType type) =>
    engine.registry[type].isSimple ? type.name : '_make${type.name}';

String _variableName(DartType type) =>
    type.name[0].toLowerCase() + type.name.substring(1);

String _generateMethod(Signature method) {
  log('METHOD_GENERATE: method=${method}');
  // Noop if maker is a simple function call.
  if (engine.registry[method.type].isSimple) return '';
  String out = '${method.type} ${_makerName(method.type)}() {\n';
  final variables = List<String>();
  for (final param in method.parameters) {
    final name = _variableName(param);
    variables.add(name);
    out += 'final $name = ${_makerName(param)}();\n';
  }

  final create = engine.registry[method.type];
  String function = '';
  if (create is ProviderFunction && create.function.isStatic)
    function = '${create.scope.name}.${create.function.name}';
  else if (create is ProviderFunction)
    function = '${create.function.name}';
  else
    function = '${create.function.returnType}';

  out += 'return ${function}(${variables.join(', ')});\n';
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

Stream<Signature> _processComponentClass(ClassElement element) async* {
  log('COMPONENT: name=${element.name} kind=${element.kind}\nmethods=${element.methods}');
  // Concrete methods in components are considered providers.
  for (final method in element.methods.where((m) => !m.isAbstract))
    _processProviderMethod(element, method);
  // Abstract methods in components need to be implemented by diversion.
  for (final method in element.methods.where((m) => m.isAbstract))
    await for (final signature in _processComponentFunction(method))
      yield signature;
}

void _processProviderMethod(ClassElement scope, MethodElement method) {
  log('PROVIDER_METHOD: method=$method ');
  engine.registerProvider(scope, method);
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
