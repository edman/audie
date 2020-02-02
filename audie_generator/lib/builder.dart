import 'dart:async';

import 'package:audie_generator/src/errors.dart';
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
      // Check preconditions.
      checkErrors(library);

      // Generate code.
      final solution = await state.putLibrary(library);
      if (solution.isNotEmpty)
        log.info('solved "${library.element.identifier}":\n$solution');
      else
        log.info('solved "${library.element.identifier}": no code gen');

      return solution;
    } on InvalidGenerationSourceError catch (e, st) {
      final outs = _error(e.message);
      log.info('error "${library.element.identifier}": ${e.message}');
      log.severe(
          'Error in AudieGenerator for '
          '${library.element.source.fullName}.',
          e,
          st);
      return outs;
    } catch(e, st) {
      log.severe('Error: $e\n$st\n${e.runtimeType}');
    }
    return '// Probably should not reach here';
  }
}

String _error(String message) {
  final lines = message.split('\n');
  final indented = lines.skip(1).map((l) => '//        $l'.trim()).join('\n');
  return '// Error: ${lines.first}\n$indented';
}
