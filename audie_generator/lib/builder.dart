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
      return await state.putLibrary(library);
    } on InvalidGenerationSourceError catch (e, st) {
      log.warning(
          'Error in AudieGenerator for ${library.element.source.fullName}.\n',
          e,
          st);
      return _commented(e);
    }
    return null;
  }
}

String _commented(Error error) =>
    '$error'.split('\n').map((l) => '//        $l'.trim()).join('\n');
