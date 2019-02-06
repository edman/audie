import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:async/async.dart';
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
    for (final annotated in components)
      out += await _generateComponent(annotated.element as ClassElement);

    log('\n$out');
    return out;
  }
}

Future<String> _generateComponent(ClassElement component) async {
  log('COMPONENT_GENERATE: component=${component}');
  String out = 'class _\$${component.name} implements ${component.name} {\n';
  String makers = '';
  await for (final method in _processComponentClass(component)) {
    pre(method != null, 'null method in _generateComponent ');
    makers += _generateHelperMethod(method);
  }
  for (final method in component.methods.where((m) => m.isAbstract)) {
    pre(method != null, 'not null');
    pre(method.returnType != null, 'ret not null');
    pre(engine.registry[method.returnType] != null, 'entry not null');
    out += '@override\n' +
        '${method.returnType} ${method.name}() => ' +
        '${engine.registry[method.returnType].helperName}();\n\n';
  }
  out += makers;
  out += "}\n";
  return out;
}

String _variableName(DartType type) =>
    type.name[0].toLowerCase() + type.name.substring(1);

String _generateHelperMethod(CreationMethod creator) {
  log('METHOD_GENERATE: method=${creator}');
  pre(creator != null, 'null creator in _generateMethod');
  // Generate nothing if maker is a simple function call.
  if (creator.isSimple) return '';
  String out = '${creator.function.returnType} ${creator.helperName}() {\n';
  final variables = List<String>();
  for (final param in creator.function.parameters) {
    final name = _variableName(param.type);
    variables.add(name);
    out += 'final $name = ${engine.registry[param.type].helperName}();\n';
  }
  out += 'return ${creator.name}(${variables.join(', ')});\n';
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

Stream<CreationMethod> _processComponentClass(ClassElement element) {
  log('COMPONENT: name=${element.name} kind=${element.kind}\nmethods=${element.methods}');
  // Concrete methods in components are considered providers.
  for (final method in element.methods.where((m) => !m.isAbstract))
    _processProviderMethod(element, method);
  // Abstract methods in components need to be implemented by diversion.
  return StreamGroup.merge(element.methods
      .where((m) => m.isAbstract)
      .map((m) => _processComponentFunction(m)));
}

void _processProviderMethod(ClassElement scope, MethodElement method) {
  log('PROVIDER_METHOD: method=$method ');
  engine.registerProvider(scope, method);
}

Stream<CreationMethod> _processComponentFunction(
    FunctionTypedElement function) {
  log('COMPONENT_METHOD: method=${function}');
  return engine.recipe(function.returnType);
}

void pre(bool condition, String message) {
  if (!condition) throw ArgumentError('precondition error: $message');
}

void log(msg) {
  final div = '----------------------------------';
  print('$div\n$msg\n$div');
}
