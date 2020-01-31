import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:audie/audie.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
final componentType = TypeChecker.fromRuntime(component.runtimeType);

class StateS {
  final Iterable<AtInject> injects;
  final Iterable<AtComponent> components;

  Iterable<FunctionTypedElement> get providers =>
      components.expand((c) => c.providers);

  Iterable<FunctionTypedElement> get abstracts =>
      components.expand((c) => c.abstracts);

  StateS._(this.injects, this.components);

  factory StateS.fromLibrary(LibraryReader library) {
    // All classes annotated with @inject.
    final injectClases = library
        .annotatedWith(injectType)
        .map((a) => a.element)
        .whereType<ClassElement>()
        .map((e) => AtInject.fromClass(e));
    // All constructors annotated with @inject.
    final injectConstructors = <AtInject>[];
    // for (final clazz in library.allElements.whereType<ClassElement>())
    for (final clazz in library.classes)
      for (final constructor in clazz.constructors)
        if (injectType.hasAnnotationOf(constructor))
          injectConstructors.add(AtInject.fromConstructor(clazz, constructor));
    // All classes annotated with @component.
    final componentClases = library
        .annotatedWith(componentType)
        .map((a) => a.element)
        .whereType<ClassElement>()
        .map((e) => AtComponent(e));
    // Gather relevant elements into a state object.
    return StateS._(
      injectClases.followedBy(injectConstructors),
      componentClases,
    );
  }

  factory StateS.fromStates(Iterable<StateS> states) {
    final injects = states.expand((s) => s.injects);
    final components = states.expand((s) => s.components);
    return StateS._(injects, components);
  }

//  FunctionTypedElement creatorFor(DartType type) {
//
//  }

  // TODO this needs to receive atcomponent by parameter.
  // TODO in general components shouldn't be part of the state.
  Iterable<DartType> get requiredTypes {
    final returnTypes = abstracts.map((a) => a.returnType);
    final injectParameters =
    injects.expand((i) => i.constructor.parameters.map((p) => p.type));
    final providerParameters =
    providers.expand((p) => p.parameters.map((p) => p.type));
    return returnTypes
        .followedBy(injectParameters)
        .followedBy(providerParameters);
  }

  Set<DartType> get possibleTypes {
//    final injectTypes = injects.map((i) => i.constructor.returnType);
//    final providerTypes = providers.map((p) => p.returnType);
//    return injectTypes.followedBy(providerTypes).toSet();
    return injects.map((i) => i.constructor.returnType).toSet();
  }

  bool get solvable {
    final required = requiredTypes;
    final possible = possibleTypes;

    return possible.containsAll(required);
  }

  @override
  String toString() => 'StateS:\n--injects: $injects\n--components: $components';
}

class State {
  final Iterable<AtInject> injects;
  final Iterable<AtComponent> components;

  Iterable<FunctionTypedElement> get providers =>
      components.expand((c) => c.providers);

  Iterable<FunctionTypedElement> get abstracts =>
      components.expand((c) => c.abstracts);

  State._(this.injects, this.components);

  factory State.fromLibrary(LibraryReader library) {
    // All classes annotated with @inject.
    final injectClases = library
        .annotatedWith(injectType)
        .map((a) => a.element)
        .whereType<ClassElement>()
        .map((e) => AtInject.fromClass(e));
    // All constructors annotated with @inject.
    final injectConstructors = <AtInject>[];
    // for (final clazz in library.allElements.whereType<ClassElement>())
    for (final clazz in library.classes)
      for (final constructor in clazz.constructors)
        if (injectType.hasAnnotationOf(constructor))
          injectConstructors.add(AtInject.fromConstructor(clazz, constructor));
    // All classes annotated with @component.
    final componentClases = library
        .annotatedWith(componentType)
        .map((a) => a.element)
        .whereType<ClassElement>()
        .map((e) => AtComponent(e));
    // Gather relevant elements into a state object.
    return State._(
      injectClases.followedBy(injectConstructors),
      componentClases,
    );
  }

  factory State.fromStates(Iterable<State> states) {
    final injects = states.expand((s) => s.injects);
    final components = states.expand((s) => s.components);
    return State._(injects, components);
  }

  Iterable<DartType> get requiredTypes {
    final returnTypes = abstracts.map((a) => a.returnType);
    final injectParameters =
        injects.expand((i) => i.constructor.parameters.map((p) => p.type));
    final providerParameters =
        providers.expand((p) => p.parameters.map((p) => p.type));
    return returnTypes
        .followedBy(injectParameters)
        .followedBy(providerParameters);
  }

  Set<DartType> get possibleTypes {
    final injectTypes = injects.map((i) => i.constructor.returnType);
    final providerTypes = providers.map((p) => p.returnType);
    return Set.of(injectTypes.followedBy(providerTypes));
  }

  bool get solvable {
    final required = requiredTypes;
    final possible = possibleTypes;

    return possible.containsAll(required);
  }

  @override
  String toString() => 'State:\n--injects: $injects\n--components: $components';
}

@immutable
class AtComponent {
  AtComponent(this.clazz)
      : providers = clazz.methods.where((m) => !m.isAbstract).toList(),
        abstracts = clazz.methods.where((m) => m.isAbstract).toList();
  final ClassElement clazz;
  final List<FunctionTypedElement> providers;
  final List<FunctionTypedElement> abstracts;

  Iterable<DartType> get requiredTypes => abstracts.map((a) => a.returnType);

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

  factory AtInject.fromConstructor(
      ClassElement clazz, ConstructorElement constructor) {
    assert(injectType.hasAnnotationOf(constructor));
    return AtInject._(clazz, constructor);
  }

  final ClassElement clazz;
  final FunctionTypedElement constructor;

  @override
  String toString() => 'AtInject{${clazz.name}}';
}
