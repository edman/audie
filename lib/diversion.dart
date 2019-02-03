import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class DiversionGenerator extends Generator {
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    print('HERE: generate was called library=$library step=$buildStep');
    print('HERE: elements=${library.allElements}');

    return 'final String I = "am here?";';
  }
}
