import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';

/// Creators represent nodes in the object graph. They are function-like
/// elements that can be called, with or without parameters, to create a new
/// object.
///
/// Currently a creator can be added to the graph with `@inject` annotations
/// in concrete class constructors, or with provider methods in classes
/// annotated with `@component`.
@immutable
abstract class Creator {
  Creator(this.function, this.dependencies);
  final FunctionTypedElement function;
  final Iterable<DartType> dependencies;

  /// A creation method is said to be simple if it takes no parameters.
  bool get isSimple => function.parameters.isEmpty;

  /// The name of this creator as it should be invoked.
  String get name;

  /// Name of the helper function that initializes the dependencies of this
  /// creator.
  ///
  /// If this creator has no dependencies, it doesn't need a helper.
  String get helperName => isSimple ? name : '_create${function.returnType}';

  @override
  String toString() => '$name${dependencies}';
}

/// Simple creator for constructors.
///
/// Constructor creators are registered in the object graph through `@inject`
/// annotations.
class Constructor extends Creator {
  Constructor(FunctionTypedElement function, Iterable<DartType> dependencies)
      : super(function, dependencies);

  @override
  String get name => '${function.returnType}';
}

/// Creator for provider methods.
///
/// Provider methods are registered in the object graph through in classes
/// annotated with `@component`.
class Provider extends Creator {
  Provider(
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
