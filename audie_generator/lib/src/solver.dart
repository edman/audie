import 'package:analyzer/dart/element/element.dart';
import 'package:audie_generator/src/parser.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

String solve(State state, AtComponent component) {
  print('WOW solving for component=${component.clazz.name}');
  final possibleTypes = state.possibleTypes;
  final requiredTypes = component.requiredTypes;
  if (!possibleTypes.containsAll(requiredTypes))
    return '// Error, missing some types: ${requiredTypes.toSet().difference(possibleTypes)}';

  final methods = component.abstracts.map((a) => Method((b) => b
    ..annotations.add(refer('override'))
    ..name = a.name
    ..returns = refer(a.returnType.name)
    ..body = const Code('')));

  final clazz = Class((b) => b
    ..name = '_\$${component.clazz.name}'
    ..extend = refer(component.clazz.name)
    ..methods.addAll(methods));

  return DartFormatter().format(clazz.accept(DartEmitter()).toString());
}

//Code solveBody(FunctionTypedElement abstract, State state, AtComponent component) {
//  abstract.parameters.map((parameter) {
//    'final _${parameter.type.name} = ';
//  });
//}
