import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:async/async.dart';
import 'package:build/build.dart';
import 'package:audie/audie.dart';
import 'package:audie_generator/src/creator.dart';
import 'package:audie_generator/src/engine.dart';
import 'package:source_gen/source_gen.dart';

final engine = DepEngine();

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
final componentType = TypeChecker.fromRuntime(component.runtimeType);

class AudieGenerator extends Generator {
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    // Visit all constructors annotated with @inject.
    for (final clazz in library.allElements.whereType<ClassElement>())
      for (final constructor in clazz.constructors)
        if (injectType.hasAnnotationOf(constructor))
          _processInjectConstructor(constructor);
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
  String out = 'class _\$${component.name} extends ${component.name} {\n';

  Set<Creator> creators = Set<Creator>();
  await for (final creator in _processComponentClass(component)) {
    creators.add(creator);
  }

  String outCreators = '';
  creators.forEach((creator) {
    outCreators += _generateHelperMethod(creator);
  });

  for (final method in component.methods.where((m) => m.isAbstract)) {
    out += '@override\n' +
        '${method.returnType} ${method.name}() => ' +
        '${engine.registry[method.returnType].helperName}();\n\n';
  }
  out += outCreators;
  out += '_\$${component.name}() : super._();\n';
  out += "}\n";
  return out;
}

String _variableName(DartType type) =>
    type.name[0].toLowerCase() + type.name.substring(1);

String _generateHelperMethod(Creator creator) {
  log('METHOD_GENERATE: method=${creator}');
  // Generate nothing if maker is a simple function call.
  if (creator.isSimple) return '';
  String out = '${creator.function.returnType} ${creator.helperName}() {\n';
  final variables = List<String>();
  for (final param in creator.dependencies) {
    final name = _variableName(param);
    variables.add(name);
    out += 'final $name = ${engine.registry[param].helperName}();\n';
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

Stream<Creator> _processComponentClass(ClassElement element) {
  log('COMPONENT: name=${element.name} kind=${element.kind}\nmethods=${element.methods}');
  // Concrete methods in components are considered providers.
  for (final method in element.methods.where((m) => !m.isAbstract))
    _processProviderMethod(element, method);
  // Abstract methods in components need to be implemented by audie.
  return StreamGroup.merge(element.methods
      .where((m) => m.isAbstract)
      .map((m) => _processComponentFunction(m)));
}

void _processProviderMethod(ClassElement scope, MethodElement method) {
  log('PROVIDER_METHOD: method=$method ');
  engine.registerProvider(scope, method);
}

Stream<Creator> _processComponentFunction(FunctionTypedElement function) {
  log('COMPONENT_METHOD: method=${function}');
  return engine.recipe(function.returnType);
}

void pre(bool condition, String message) {
  if (!condition) throw ArgumentError('precondition error: $message');
}

void log(msg) {
  if (msg.toString().trim().isEmpty) return;
  final div = '----------------------------------';
  print('$div\n$msg\n$div');
}
