import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

/// Creators represent nodes in the object graph. They are funtion-like
/// elements that can be called, with or without parameters, to create a new
/// object.
///
/// Currently a creator can be added to the graph with `@inject` annotations
/// in concrete class constructors, or with provider methods in classes
/// annotated with `@component`.
@immutable
abstract class Creator {
  const Creator(this.function);
  final FunctionTypedElement function;

  DartType get createdType => function.returnType;

  Iterable<ParameterElement> get _params => function.parameters;

  Iterable<DartType> get dependencies =>
      _params.where((p) => p.isNotOptional).map((p) => p.type);

  Iterable<DartType> get optionalPositionals =>
      _params.where((p) => p.isOptionalPositional).map((p) => p.type);

  Iterable<ParameterElement> get optionalNamed =>
      _params.where((p) => p.isNamed);

  /// A creation method is said to be simple if it takes no parameters.
  bool get isSimple => _params.isEmpty;

  /// The name of this creator as it should be invoked.
  String get name;

  /// Name of the helper function that initializes the dependencies of this
  /// creator.
  ///
  /// If this creator has no dependencies, it doesn't need a helper.
  String get helperName => isSimple ? name : '_create${function.returnType}';

  @override
  String toString() =>
      '$name($dependencies,[$optionalPositionals],$optionalNamed)';
}

/// Simple creator for constructors.
///
/// Constructor creators are registered in the object graph through `@inject`
/// annotations.
class Constructor extends Creator {
  const Constructor(FunctionTypedElement function) : super(function);

  @override
  String get name => '${function.returnType}';
}

/// Creator for provider methods.
///
/// Provider methods are registered in the object graph through classes
/// annotated with `@component`.
class Provider extends Creator {
  const Provider(this.scope, MethodElement function) : super(function);
  final ClassElement scope;

  @override
  MethodElement get function => super.function;

  @override
  String get name =>
      function.isStatic ? '${scope.name}.${function.name}' : '${function.name}';
}
