import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

class TooManyConstructors extends InvalidGenerationSourceError {
  TooManyConstructors(ClassElement clazz)
      : super(_tooManyConstructorsMessage(clazz));
}

String _tooManyConstructorsMessage(ClassElement clazz) {
  String msg =
      'The class "${clazz.name}" is annotated with @inject but has more'
      ' than one constructor/factory.\n\n';

  msg +=
      clazz.constructors.map((c) => spanForElement(c).highlight()).join('\n');

  msg += '\n\nClasses with @inject should have exactly one constructor. '
      '''Possible solutions are:

* Move the @inject annotation to one of the constructors/factories.

* Remove unnecessary constructors/factories until there is only one left.
''';
  return msg;
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
