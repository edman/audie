import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:audie_generator/audie_generator.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';

const pkgName = 'pkg';
const fileName = 'file';

final builder = PartBuilder([AudieGenerator()], '.g.dart');

Future<String> generate(String source) async {
  final srcs = <String, String>{
    'audie|lib/audie.dart': audieSource,
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
  import 'package:audie/audie.dart';
  part '$fileName.g.dart';

  @component
  abstract class Component {
    $body
    ${componentBoilerplate()}
  }
  ''';

String componentBoilerplate([String className = 'Component']) =>
    '$className._();\nfactory $className() = _\$$className;';

const audieSource = r'''
library audie;

const inject = _Inject();
const component = _Component();

class _Inject {
  const _Inject();
}

class _Component {
  const _Component();
}
''';
