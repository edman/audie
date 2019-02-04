import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

/// Describe the signature of an injectable entity.
@immutable
class Signature {
  Signature(this.type, this.parameters);

  final DartType type;
  final Iterable<DartType> parameters;

  @override
  int get hashCode => type.hashCode;

  @override
  bool operator ==(other) => other is Signature && type == other.type;

  @override
  String toString() => '$type:[$parameters]';
}

abstract class CreationMethod {
  CreationMethod(this.function, this.dependencies);
  final FunctionTypedElement function;
  final Iterable<DartType> dependencies;

  @override
  String toString() => '[${dependencies}]';
}

class Constructor extends CreationMethod {
  Constructor(FunctionTypedElement function, Iterable<DartType> dependencies)
      : super(function, dependencies);
}

class ProviderFunction extends CreationMethod {
  final ClassElement scope;

  ProviderFunction(this.scope, FunctionTypedElement function,
      Iterable<DartType> dependencies)
      : super(function, dependencies);
}

class DepEngine {
  final _registry = Map<DartType, CreationMethod>();
  Map<DartType, CreationMethod> get registry => _registry;

  final _blockers = Map<DartType, Completer<DartType>>();

  void registerConstructor(ConstructorElement function) {
    final sig = function.returnType;
    _registry[sig] =
        Constructor(function, function.parameters.map((p) => p.type));
    if (_blockers.containsKey(sig)) _blockers[sig].complete(sig);
  }

  void registerProvider(ClassElement scope, FunctionTypedElement function) {
    final sig = function.returnType;
    _registry[sig] = ProviderFunction(
        scope, function, function.parameters.map((p) => p.type));
    if (_blockers.containsKey(sig)) _blockers[sig].complete(sig);
  }

  Stream<Signature> recipe(DartType type) async* {
    if (!_registry.containsKey(type))
      await _blockers.putIfAbsent(type, () => Completer<DartType>()).future;
    final deps = _registry[type].dependencies;
    final seen = Set<Signature>();
    for (final dep in deps) {
      await for (final d in recipe(dep)) {
        if (!seen.contains(d)) {
          yield d;
          seen.add(d);
        }
      }
    }
    yield Signature(type, deps);
  }

  bool contains(DartType type) {
    return _registry.containsKey(type) &&
        _registry[type].dependencies.every((dep) => contains(dep));
  }

  @override
  String toString() => '$_registry';
}
