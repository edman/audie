import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
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

class UnknownType extends InvalidGenerationSourceError {
  UnknownType(this.missing, [this.abstract])
      : super(_unknownTypeMessage(missing, abstract));

  DartType missing;
  FunctionTypedElement abstract;

  UnknownType withAbstract(FunctionTypedElement abstract) =>
      UnknownType(missing, abstract);
}

String _unknownTypeMessage(DartType missing, FunctionTypedElement abstract) {
  String msg =
      'An instance of "$missing" is needed but we don\'t know how to make it.';
  if (abstract != null)
    msg += '\n\nNeeded to implement the "${abstract.enclosingElement.name}" '
        'component, specifically the method below...'
        '\n${spanForElement(abstract).highlight()}';

  final element = missing.element;
  if (element is ClassElement && element.isAbstract) {
    msg += '\n\n* Consider adding a "$missing" provider to your component. '
        'For example...\n\n\t$missing provide$missing() => TODO';
  } else if (element is ClassElement && element.constructors.length <= 1) {
    msg += '\n\n* Consider adding @inject to the "$missing" class...'
        '\n${spanForElement(element).highlight()}';
  } else if (element is ClassElement && element.constructors.length > 1) {
    msg += '\n\n* Consider adding an @inject annotation to one of the '
        'constructors of "$missing"...\n';
    msg += element.constructors
        .map((c) => spanForElement(c).highlight())
        .join('\n');
  }
  return msg + '\n';
}
