import 'package:analyzer/dart/element/element.dart';
import 'package:audie_generator/src/state.dart';
import 'package:source_gen/source_gen.dart';

void checkErrors(LibraryReader library) {
  final errors = <String>[];

  final injects = library
      .annotatedWith(injectType)
      .map((a) => a.element)
      .whereType<ClassElement>();

  injects.where((c) => c.constructors.length != 1).forEach((c) => errors.add(
      '''The class ${c.name} is annotated with @inject but does not have exactly one
constructor/factory. Possible solutions are:
- Move the @inject annotation to one of the constructors/factories.
- Remove unnecessary constructors/factories until there is only one left.
'''));

  if (errors.isNotEmpty) {
    final message = StringBuffer();
    errors.asMap().forEach((i, e) => message.writeln('$i. $e'));
    throw InvalidGenerationSourceError('$message');
  }
}
