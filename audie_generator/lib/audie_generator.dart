import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:async/async.dart';
import 'package:audie/audie.dart';
import 'package:audie_generator/src/creator.dart';
import 'package:audie_generator/src/engine.dart';
import 'package:audie_generator/src/errors.dart';
import 'package:audie_generator/src/parser.dart';
import 'package:audie_generator/src/solver.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

final engine = DepEngine();
final eng = Engine();

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
final componentType = TypeChecker.fromRuntime(component.runtimeType);

final stateblabs = StateStreamed();

class AudieGenerator extends Generator {
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final outs = StringBuffer();
    log.info('HERE: starting on "${library.element.identifier}"');

    // Check preconditions.
    try {
      checkErrors(library);
    } on InvalidGenerationSourceError catch (e, st) {
      outs.writeln(_error(e.message));
      logs('HIER did try to log');
      log.severe(
          'Error in AudieGenerator for '
          '${library.element.source.fullName}.',
          e,
          st);
      return outs.toString();
    }
    // Visit all constructors annotated with @inject.
    for (final clazz in library.classes)
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

//     String out = '';
//     for (final annotated in components)
//     out += await _generateComponent(annotated.element as ClassElement);
//     outs.writeln(await _generateComponent(annotated.element as ClassElement));

    // log('\n$out');
    // return out;
    // logs('\n$outs');

    eng.states[library.element.identifier] = State.fromLibrary(library);
    final state = eng.state;
    logs('\n\nidentifier=${library.element.identifier}');
    logs('\n\n${state}');
    logs('\n\nsolvable=${state.solvable}');

    logs('\n\nwill call solve');
    for (final annotated in components.map((c) => c.element).whereType<ClassElement>())
      outs.writeln(solve(state, AtComponent(annotated)));
    logs('\nWOW\n$outs');

    stateblabs.libraries.add(library);
    logs('solving "${library.element.identifier}": ${await stateblabs.solveLibrary(library)}');
    return outs.toString();
  }
}

Future<String> _generateComponent(ClassElement component) async {
  logs('COMPONENT_GENERATE: component=${component}');
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
  logs('METHOD_GENERATE: method=${creator}');
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
  logs('INJECT: class=${element.name} ');
  element.constructors.forEach((constructor) {
    _processInjectConstructor(constructor);
  });
}

void _processInjectConstructor(ConstructorElement constructor) {
  logs('INJECT_CONSTRUCTOR: constructor=$constructor ');
  engine.registerConstructor(constructor);
}

Stream<Creator> _processComponentClass(ClassElement element) {
  logs(
      'COMPONENT: name=${element.name} kind=${element.kind}\nmethods=${element.methods}');
  // Concrete methods in components are considered providers.
  for (final method in element.methods.where((m) => !m.isAbstract))
    _processProviderMethod(element, method);
  // Abstract methods in components need to be implemented by audie.
  return StreamGroup.merge(element.methods
      .where((m) => m.isAbstract)
      .map((m) => _processComponentFunction(m)));
}

void _processProviderMethod(ClassElement scope, MethodElement method) {
  logs('PROVIDER_METHOD: method=$method ');
  engine.registerProvider(scope, method);
}

Stream<Creator> _processComponentFunction(FunctionTypedElement function) {
  logs('COMPONENT_METHOD: method=${function}');
  return engine.recipe(function.returnType);
}

void pre(bool condition, String message) {
  if (!condition) throw ArgumentError('precondition error: $message');
}

void logs(msg) {
  if (msg.toString().trim().isEmpty) return;
  final div = '----------------------------------';
  print('$div\n$msg\n$div');
}

String _error(String message) {
  final lines = '$message'.split('\n');
  final indented = lines.skip(1).map((l) => '//        $l'.trim()).join('\n');
  return '// Error: ${lines.first}\n$indented';
}
