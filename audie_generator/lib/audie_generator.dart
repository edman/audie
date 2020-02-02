import 'dart:async';

import 'package:audie_generator/src/errors.dart';
import 'package:audie_generator/src/parser.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

final stateblabs = StateStreamed();

class AudieGenerator extends Generator {
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    // Check preconditions.
    try {
      checkErrors(library);
    } on InvalidGenerationSourceError catch (e, st) {
      final outs = _error(e.message);
      log.severe(
          'Error in AudieGenerator for '
          '${library.element.source.fullName}.',
          e,
          st);
      return outs;
    }

    stateblabs.libraries.add(library);
    final solution = await stateblabs.solveLibrary(library);
    if (solution.isNotEmpty)
      log.info('solved "${library.element.identifier}":\n$solution');
    else
      log.info('solved "${library.element.identifier}": no code gen');
    return solution;
  }
}

String _error(String message) {
  final lines = message.split('\n');
  final indented = lines.skip(1).map((l) => '//        $l'.trim()).join('\n');
  return '// Error: ${lines.first}\n$indented';
}
