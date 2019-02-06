import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:diversion_generator/src/creator.dart';

class DepEngine {
  final _registry = Map<DartType, Creator>();
  Map<DartType, Creator> get registry => _registry;

  final _blockers = Map<DartType, Completer<Creator>>();

  Future<Creator> _block(DartType type) => _registry.containsKey(type)
      ? Future.value(_registry[type])
      : _blockers.putIfAbsent(type, () => Completer<Creator>()).future;

  void _unblock(DartType type, Creator creator) =>
      _blockers[type]?.complete(creator);

  void _register(DartType type, Creator creator) {
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
        Provider(
          scope,
          function,
          function.parameters.map((p) => p.type),
        ),
      );

  Stream<Creator> recipe(DartType type) async* {
    final creator = await _block(type);
    final seen = Set<Creator>();
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
