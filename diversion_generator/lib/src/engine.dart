import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

@immutable
abstract class CreationMethod {
  CreationMethod(this.function, this.dependencies);
  final FunctionTypedElement function;
  final Iterable<DartType> dependencies;

  /// A creation method is said to be simple if it takes no parameters.
  bool get isSimple => function.parameters.isEmpty;

  String get name;
  String get helperName => isSimple ? name : '_create${function.returnType}';

  @override
  String toString() => '$name${dependencies}';
}

class Constructor extends CreationMethod {
  Constructor(FunctionTypedElement function, Iterable<DartType> dependencies)
      : super(function, dependencies);
  @override
  String get name => '${function.returnType}';
}

class ProviderFunction extends CreationMethod {
  ProviderFunction(
    this.scope,
    MethodElement function,
    Iterable<DartType> dependencies,
  ) : super(function, dependencies);

  final ClassElement scope;
  @override
  MethodElement get function => super.function;
  @override
  String get name =>
      function.isStatic ? '${scope.name}.${function.name}' : '${function.name}';
}

class DepEngine {
  final _registry = Map<DartType, CreationMethod>();
  Map<DartType, CreationMethod> get registry => _registry;

  final _blockers = Map<DartType, Completer<CreationMethod>>();

  Future<CreationMethod> _block(DartType type) => _registry.containsKey(type)
      ? Future.value(_registry[type])
      : _blockers.putIfAbsent(type, () => Completer<CreationMethod>()).future;

  void _unblock(DartType type, CreationMethod creator) =>
      _blockers[type]?.complete(creator);

  void _register(DartType type, CreationMethod creator) {
    _registry[type] = creator;
    _unblock(type, creator);
  }

  void registerConstructor(ConstructorElement function) => _register(
        function.returnType,
        Constructor(
          function,
          function.parameters.map((p) => p.type),
        ),
      );

  void registerProvider(ClassElement scope, MethodElement function) =>
      _register(
        function.returnType,
        ProviderFunction(
          scope,
          function,
          function.parameters.map((p) => p.type),
        ),
      );

  Stream<CreationMethod> recipe(DartType type) async* {
    final creator = await _block(type);
    final seen = Set<CreationMethod>();
    for (final dep in creator.dependencies)
      await for (final d in recipe(dep)) if (seen.add(d)) yield d;
    yield creator;
  }

  bool contains(DartType type) {
    return _registry.containsKey(type) &&
        _registry[type].dependencies.every((dep) => contains(dep));
  }

  @override
  String toString() => '$_registry';
}
