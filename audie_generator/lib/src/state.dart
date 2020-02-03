import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:audie_generator/src/annotation_utils.dart';
import 'package:audie_generator/src/errors.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:rxdart/rxdart.dart';
import 'package:source_gen/source_gen.dart';

/// State is the "brain" of this package. It maintains all information necessary
class State {
  State() {
    _librariesById = _libraries.scan((acc, library, index) {
      acc[library.element.identifier] = library;
      return acc;
    }, <String, LibraryReader>{});

    _injects = _librariesById
        .debounceTime(Duration(milliseconds: 100))
        .map((libs) => libs.values.map(injectsOf).expand((i) => i));
  }

  /// Receives all libraries in the project. ReplaySubject is used to make sure
  /// we remember libraries seen before someone begins to listen on the stream.
  final _libraries = ReplaySubject<LibraryReader>();

  /// Aggregates the current libraries in a project.
  Stream<Map<String, LibraryReader>> _librariesById;

  /// Enumerates all @inject annotated elements in all libraries.
  Stream<Iterable<AtInject>> _injects;

  /// Introduces the given library into the current state, possibly replacing a
  /// previous version if it already existed.
  ///
  /// Returns the code generated for this library, or empty string if there is
  /// no output.
  Future<String> putLibrary(LibraryReader library) {
    _libraries.add(library);
    return _solveLibrary(library);
  }

  Future<String> _solveLibrary(LibraryReader library) async {
    final components = componentsOf(library);

    if (components.isEmpty) return Future.value('');

    final classes =
        await Future.wait<Class>(components.map((c) => _solveComponent(c)));

    final lib = Library((b) => b..body.addAll(classes));
    return DartFormatter().format(lib.accept(DartEmitter()).toString());
  }

  Future<Class> _solveComponent(AtComponent component) {
    Object latestError; // TODO change to Error instead of Object.
    return _injects
        .switchMap((latestInjects) =>
            _solveComponentWithInjects(component, latestInjects).asStream())
//        .doOnData((output) => log.info('output=$output'))
        .handleError((e) => latestError = e)
        .timeout(Duration(seconds: 1), onTimeout: (sink) {
      sink.addError(latestError ?? TimeoutException('Something went wrong'));
      latestError = null;
    }).first;
  }
}

Future<Class> _solveComponentWithInjects(
    AtComponent component, Iterable<AtInject> injects) async {
  final allCreators = providersAndConstructors(component, injects);

  final methods = await Future.wait<Method>(component.abstracts.map((a) =>
      _solveAbstract(a, allCreators).catchError((e) => throw e.withAbstract(a),
          test: (e) => e is UnknownType)));

  return Class((b) => b
    ..name = '_\$${component.clazz.name}'
    ..extend = refer(component.clazz.name)
    ..constructors
        .add(Constructor((b) => b..initializers.add(const Code('super._()'))))
    ..methods.addAll(methods));
}

Future<Method> _solveAbstract(FunctionTypedElement abstract,
    Iterable<FunctionTypedElement> allCreators) async {
  final recipe =
      await ObjectGraph(allCreators).recipeFor(abstract.returnType).toList();

  return Method((b) => b
    ..annotations.add(refer('override'))
    ..name = abstract.name
    ..returns = refer(abstract.returnType.name)
    ..body = Code(_codeForRecipe(recipe)));
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

String _variableName(FunctionTypedElement e) =>
    e.returnType.name[0].toLowerCase() + e.returnType.name.substring(1);

String _codeForRecipe(List<FunctionTypedElement> recipe) {
  String assignment(variable, function, params) =>
      'final $variable = $function(${params.join(', ')});';
  String returnLine(function, params) =>
      'return $function(${params.join(', ')});';

  // First entries in recipe are dependencies. Create variables for those.
  final depCreators = recipe.length > 1
      ? recipe.sublist(0, recipe.length - 1)
      : <FunctionTypedElement>[];
  final Map<DartType, String> variables = Map.fromIterable(depCreators,
      key: (d) => d.returnType, value: (d) => _variableName(d));
  // Last entry in recipe is the return creator.
  final returnCreator = recipe.last;

  final assignments = depCreators.map((d) => assignment(
        variables[d.returnType],
        _invokedName(d),
        d.parameters.map((p) => variables[p.type]),
      ));
  final returnCall = returnLine(
    _invokedName(returnCreator),
    returnCreator.parameters.map((p) => variables[p.type]),
  );

  return assignments.followedBy([returnCall]).join('\n');
}

/// ObjectGraph receives the list of all known object creators, and uses it to
/// decide the steps needed to produce an object of any given type in the list.
class ObjectGraph {
  Map<DartType, FunctionTypedElement> _graph;

  ObjectGraph(Iterable<FunctionTypedElement> creators)
      : _graph = Map.fromIterable(creators, key: (c) => c.returnType) {
    log.info('object graph: $_graph');
  }

  /// Returns a stream with the creators needed to instantiate an object of the
  /// given type. The creators are returned in the order they should be called.
  Stream<FunctionTypedElement> recipeFor(DartType type) {
    if (!_graph.containsKey(type)) return Stream.error(UnknownType(type));

    final creator = _graph[type];
    if (creator.parameters.isEmpty) return Stream.value(creator);

    return creator.parameters
        .map((param) => recipeFor(param.type))
        .reduce((p1, p2) => p1.concatWith([p2]))
        .concatWith([Stream.value(creator)]).distinctUnique();
  }
}
