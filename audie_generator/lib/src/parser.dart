import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:audie/audie.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:source_gen/source_gen.dart';

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
final componentType = TypeChecker.fromRuntime(component.runtimeType);

List<AtInject> injectsOf(LibraryReader library) {
  final classes = library.classes
      .where((clazz) => injectType.hasAnnotationOf(clazz))
      .map((clazz) => AtInject.fromClass(clazz));
  final constructors = library.classes
      .expand((clazz) => clazz.constructors)
      .where((ctor) => injectType.hasAnnotationOf(ctor))
      .map((ctor) => AtInject.fromConstructor(ctor));
  return classes.followedBy(constructors).toList();
}

Iterable<AtComponent> componentsOf(LibraryReader library) => library.classes
    .where((clazz) => componentType.hasAnnotationOf(clazz))
    .map((clazz) => AtComponent(clazz));

class StateStreamed {
  StateStreamed() {
    injectsPerLibrary = _libraries.scan((acc, library, index) {
      acc[library.element.identifier] = injectsOf(library);
      return acc;
    }, <String, List<AtInject>>{});

    _injects =
        injectsPerLibrary.map((ipl) => ipl.values.expand((i) => i).toList());
  }

  Sink<LibraryReader> get libraries => _libraries;
  final _libraries = ReplaySubject<LibraryReader>();

  Stream<Map<String, List<AtInject>>> injectsPerLibrary;
  Stream<List<AtInject>> _injects;

  Future<String> solveLibrary(LibraryReader library) async {
    final components = componentsOf(library);

    if (components.isEmpty) return Future.value('');

    final classes =
        await Future.wait<Class>(components.map((c) => solveComponent(c)));

    final lib = Library((b) => b..body.addAll(classes));
    return DartFormatter().format(lib.accept(DartEmitter()).toString());
  }

  Future<Class> solveComponent(AtComponent component) {
    Object error;
    return _injects
        .timeout(Duration(seconds: 5))
        .doOnError((error, st) => '// Error: $error\n$st')
        .switchMap((latestInjects) =>
            solveComponentWithInjects(component, latestInjects)
                .asStream()
                .handleError((error, st) =>
                    print('componentWithInjects error: $error\n$st')))
        .doOnData((output) => print('output=$output'))
        .first;
  }

  Future<Class> solveComponentWithInjects(
      AtComponent component, List<AtInject> injects) async {
    final allCreators = providersAndConstructors(component, injects);

    final methods = await Future.wait<Method>(
        component.abstracts.map((a) => solveAbstract(a, allCreators)));

    return Class((b) => b
      ..name = '_\$${component.clazz.name}'
      ..extend = refer(component.clazz.name)
      ..constructors
          .add(Constructor((b) => b..initializers.add(const Code('super._()'))))
      ..methods.addAll(methods));
  }

  Future<Method> solveAbstract(FunctionTypedElement abstract,
      List<FunctionTypedElement> allCreators) async {
    final a =
        await ObjectGraph(allCreators).traverse(abstract.returnType).toList();

    final deps = a.sublist(0, a.length - 1);
    final Map<DartType, String> vars = Map.fromIterable(deps,
        key: (d) => d.returnType, value: (d) => _variableName(d.returnType));
    final ret = a.last;

    final assignments =
        deps.map((d) => 'final ${vars[d.returnType]} = ${_invokedName(d)}'
            '(${d.parameters.map((p) => vars[p.type]).join(', ')});');
    final returnLine = 'return ${_invokedName(ret)}'
        '(${ret.parameters.map((p) => vars[p.type]).join(', ')});';
    final body = assignments.followedBy([returnLine]);

    return Method((b) => b
      ..annotations.add(refer('override'))
      ..name = abstract.name
      ..returns = refer(abstract.returnType.name)
      ..body = Code(body.join('\n')));
  }
}

String _invokedName(FunctionTypedElement f) {
  if (f is ConstructorElement && f.name.isNotEmpty)
    return '${f.returnType.name}.${f.name}';
  else if (f is ConstructorElement)
    return f.returnType.name;
  else if (f is MethodElement && f.isStatic)
    return '${f.enclosingElement.name}.${f.name}';
  return f.name;
}

String _variableName(DartType type) =>
    type.name[0].toLowerCase() + type.name.substring(1);

class ObjectGraph {
  Map<DartType, FunctionTypedElement> graph;

  ObjectGraph(List<FunctionTypedElement> creators)
      : graph = Map.fromIterable(creators, key: (c) => c.returnType) {
    print('object graph: $graph');
  }

  Stream<FunctionTypedElement> traverse(DartType type) {
    if (!graph.containsKey(type)) return Stream.error('unknown type $type');

    final creator = graph[type];
    if (creator.parameters.isEmpty) return Stream.value(creator);

    return creator.parameters
        .map((param) => traverse(param.type))
        .reduce((p1, p2) => p1.concatWith([p2]))
        .concatWith([Stream.value(creator)]).distinctUnique();
  }
}

List<FunctionTypedElement> providersAndConstructors(
    AtComponent component, List<AtInject> injects) {
  return component.providers + injects.map((i) => i.constructor).toList();
}

@immutable
class AtComponent {
  AtComponent(this.clazz)
      : providers = clazz.methods
            .where((m) => !m.isAbstract)
            .cast<FunctionTypedElement>()
            .toList(),
        abstracts = clazz.methods
            .where((m) => m.isAbstract)
            .cast<FunctionTypedElement>()
            .toList();
  final ClassElement clazz;
  final List<FunctionTypedElement> providers;
  final List<FunctionTypedElement> abstracts;

  Iterable<DartType> get requiredTypes => abstracts.map((a) => a.returnType);

  Iterable<DartType> get possibleTypes => providers.map((a) => a.returnType);

  @override
  String toString() => 'AtComponent{${clazz.name}}';
}

@immutable
class AtInject {
  AtInject._(this.clazz, this.constructor)
      : assert(clazz != null),
        assert(constructor != null);

  factory AtInject.fromClass(ClassElement clazz) {
    assert(clazz.constructors.length == 1);
    return AtInject._(clazz, clazz.constructors.first);
  }

  factory AtInject.fromConstructor(ConstructorElement constructor) {
    assert(injectType.hasAnnotationOf(constructor));
    return AtInject._(constructor.enclosingElement, constructor);
  }

  final ClassElement clazz;
  final FunctionTypedElement constructor;

  @override
  String toString() => 'AtInject{${clazz.name}}';
}
