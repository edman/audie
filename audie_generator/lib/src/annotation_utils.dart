import 'package:analyzer/dart/element/element.dart';
import 'package:audie/audie.dart';
import 'package:audie_generator/src/errors.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

final _injectType = TypeChecker.fromRuntime(inject.runtimeType);
final _componentType = TypeChecker.fromRuntime(component.runtimeType);

bool hasInject(Element element) => _injectType.hasAnnotationOf(element);

bool hasComponent(Element element) => _componentType.hasAnnotationOf(element);

/// Returns all classes or constructors annotated with @inject in this library.
Iterable<AtInject> injectsOf(LibraryReader library) {
  final classes = library.classes
      .where(hasInject)
      .map((clazz) => AtInject.fromClass(clazz));
  final constructors = library.classes
      .expand((clazz) => clazz.constructors)
      .where(hasInject)
      .map((ctor) => AtInject.fromConstructor(ctor));
  return classes.followedBy(constructors);
}

/// Returns all classes annotated with @component in this library.
Iterable<AtComponent> componentsOf(LibraryReader library) => library.classes
    .where((clazz) => hasComponent(clazz))
    .map((clazz) => AtComponent(clazz));

/// Returns all creators in the given component and list of inject constructors.
Iterable<FunctionTypedElement> providersAndConstructors(
        AtComponent component, Iterable<AtInject> injects) =>
    component.providers.followedBy(injects.map((i) => i.constructor));

/// Wrapper for classes annotated with @component.
@immutable
class AtComponent {
  AtComponent(this.clazz);

  final ClassElement clazz;

  Iterable<FunctionTypedElement> get providers =>
      clazz.methods.where((m) => !m.isAbstract).cast<FunctionTypedElement>();

  Iterable<FunctionTypedElement> get abstracts =>
      clazz.methods.where((m) => m.isAbstract).cast<FunctionTypedElement>();

  @override
  String toString() => 'AtComponent{${clazz.name}}';
}

/// Wrapper for classes and constructors annotated with @inject.
@immutable
class AtInject {
  AtInject._(this.clazz, this.constructor)
      : assert(clazz != null),
        assert(constructor != null),
        assert(hasInject(clazz) || hasInject(constructor)),
        assert(!hasInject(clazz) || clazz.constructors.length == 1),
        assert(!hasInject(clazz) || !clazz.constructors.any(hasInject));

  factory AtInject.fromClass(ClassElement clazz) {
    if (hasInject(clazz) && clazz.constructors.length > 1)
      throw TooManyConstructors(clazz);
    return AtInject._(clazz, clazz.constructors.first);
  }

  factory AtInject.fromConstructor(ConstructorElement constructor) {
    if (constructor.enclosingElement.constructors.where(hasInject).length > 1)
      throw TooManyInjects(constructor.enclosingElement);
    return AtInject._(constructor.enclosingElement, constructor);
  }

  final ClassElement clazz;
  final FunctionTypedElement constructor;

  @override
  String toString() => 'AtInject{$constructor}';
}
