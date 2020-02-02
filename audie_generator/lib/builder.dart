import 'dart:async';

import 'package:audie_generator/src/state.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

Builder builderFactory(BuilderOptions _) =>
    SharedPartBuilder([AudieGenerator()], 'audie_generator');

// Global variable holds a single state across multiple libraries.
final state = State();

class AudieGenerator extends Generator {
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    try {
      // Generate code.
      final solution = await state.putLibrary(library);
      if (solution.isNotEmpty)
        log.info('solved "${library.element.identifier}":\n$solution');
      else
        log.info('solved "${library.element.identifier}": no code gen');

      return solution;
    } on InvalidGenerationSourceError catch (e, st) {
      log.warning(
          'Error in AudieGenerator for ${library.element.source.fullName}.',
          e,
          st);
      return _commented(e);
    }
    return null;
  }
}

String _commented(Error error) =>
    '$error'.split('\n').map((l) => '//        $l'.trim()).join('\n');
