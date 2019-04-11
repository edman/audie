import 'package:analyzer/dart/element/element.dart';
import 'package:audie/audie.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

final injectType = TypeChecker.fromRuntime(inject.runtimeType);
final componentType = TypeChecker.fromRuntime(component.runtimeType);

// class State {
//   final Iterable<AtInject> injects;
//   final Iterable<AtComponent> components;

//   State._(this.injects, this.components);

//   factory State.from(LibraryReader library) {
//     // All classes annotated with @inject.
//     final injectClases = library
//         .annotatedWith(injectType)
//         .map((a) => a.element)
//         .whereType<ClassElement>()
//         .map((e) => AtInject.fromClass(e));
//     // All constructors annotated with @inject.
//     final injectConstructors = <AtInject>[];
//     for (final clazz in library.allElements.whereType<ClassElement>())
//       for (final constructor in clazz.constructors)
//         if (injectType.hasAnnotationOf(constructor))
//           injectConstructors.add(AtInject.fromConstructor(clazz, constructor));
//     // All classes annotated with @inject.
//     final componentClases = library
//         .annotatedWith(componentType)
//         .map((a) => a.element)
//         .whereType<ClassElement>()
//         .map((e) => AtComponent(e));
//     // Gather relevant elements into a state object.
//     return State._(
//       injectClases.followedBy(injectConstructors),
//       componentClases,
//     );
//   }
// }

// @immutable
// class AtComponent {
//   AtComponent(this.clazz)
//       : providers = clazz.methods.where((m) => !m.isAbstract),
//         creators = clazz.methods.where((m) => m.isAbstract);
//   final ClassElement clazz;
//   final List<MethodElement> providers;
//   final List<MethodElement> creators;
// }

// @immutable
// class AtInject {
//   AtInject._(this.clazz, this.constructor)
//       : assert(clazz != null),
//         assert(constructor != null);

//   AtInject.fromClass(ClassElement clazz)
//       : assert(clazz.constructors.length == 1),
//         this._(clazz, clazz.constructors.first);

//   AtInject.fromConstructor(ClassElement clazz, ConstructorElement constructor)
//       : assert(injectType.hasAnnotationOf(constructor)),
//         this._(clazz, constructor);

//   final ClassElement clazz;
//   final ConstructorElement constructor;
// }
