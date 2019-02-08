import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:diversion_generator/diversion_generator.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';

const pkgName = 'pkg';
const fileName = 'file';

final builder = PartBuilder([DiversionGenerator()], '.g.dart');

Future<String> generate(String source) async {
  final srcs = <String, String>{
    'diversion|lib/diversion.dart': diversionSource,
    '$pkgName|lib/$fileName.dart': source,
  };

  // Capture any error from generation; if there is one, return that instead of
  // the generated output.
  String error;
  void captureError(LogRecord logRecord) {
    if (logRecord.error is InvalidGenerationSourceError) {
      if (error != null) throw StateError('Expected at most one error.');
      error = logRecord.error.toString();
    }
  }

  final writer = InMemoryAssetWriter();
  await testBuilder(builder, srcs,
      rootPackage: pkgName, writer: writer, onLog: captureError);
  return error ??
      String.fromCharCodes(
          writer.assets[AssetId(pkgName, 'lib/$fileName.g.dart')] ?? []);
}

String component([String body = '']) => '''
  import 'package:diversion/diversion.dart';
  part '$fileName.g.dart';

  @component
  abstract class Component {
    $body
    ${componentBoilerplate()}
  }
  ''';

String componentBoilerplate([String className = 'Component']) =>
    '$className._();\nfactory $className() = _\$$className;';

const diversionSource = r'''
library diversion;

const inject = _Inject();
const component = _Component();

class _Inject {
  const _Inject();
}

class _Component {
  const _Component();
}
''';
