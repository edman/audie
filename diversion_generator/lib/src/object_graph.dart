import 'package:analyzer/dart/element/type.dart';
import 'package:diversion_generator/src/creator2.dart';

class ErrorOr<T> {
  const ErrorOr._(this._value, this._error)
      : assert(_value == null || _error == null);
  final T _value;
  final Error _error;

  factory ErrorOr.of(T val, [Error err]) => val == null
      ? ErrorOr._(null, err ?? StateError('Null value'))
      : ErrorOr._(val, null);
  factory ErrorOr.ofError(Error err) => ErrorOr._(null, err);
  factory ErrorOr.stateError(String msg) => ErrorOr._(null, StateError(msg));

  bool get isPresent => _value != null;
  bool get isNotPresent => _value == null;

  T get value {
    if (isNotPresent) throw StateError('Value called in error context.');
    return _value;
  }

  ErrorOr<R> map<R>(R Function(T val) mapper) =>
      isPresent ? ErrorOr<R>.of(mapper(_value)) : this;

  ErrorOr<R> merge<S, R>(
          ErrorOr<S> other, R Function(T some, S other) merger) =>
      isPresent
          ? (other.isPresent
              ? ErrorOr<R>.of(merger(_value, other._value))
              : other)
          : this;

  void onError(void Function() onError) {
    if (isNotPresent) onError();
  }
}

class ObjectGraph {
  const ObjectGraph(this.targetTypes, this.reachableCreators);
  final Set<DartType> targetTypes;
  final Set<Creator> reachableCreators;

  bool get isSatisfiable => enumerateDependencies.isPresent;

  Map<DartType, Creator> get _registry =>
      Map<DartType, Creator>.fromIterable(reachableCreators,
          key: (c) => c.createdType, value: (c) => c);

  /// Enumerate all creators needed to satisfy the [targetTypes] of this graph.
  ErrorOr<Set<Creator>> get enumerateDependencies =>
      targetTypes.map((t) => _enumerateDependenciesHelper(t)).fold(
          ErrorOr.of(Set.of([])),
          (acc, s) => acc.merge(s, (a, s) => a..addAll(s)));

  ErrorOr<Set<Creator>> _enumerateDependenciesHelper(DartType target) {
    if (!_registry.containsKey(target))
      return ErrorOr.stateError('No known creator for $target');
    return _registry[target]
        .dependencies
        .map((d) => _enumerateDependenciesHelper(d))
        .fold(ErrorOr.of(Set.of([])),
            (acc, s) => acc.merge(s, (a, s) => a..addAll(s)));
  }

  @override
  String toString() => '$_registry';
}
