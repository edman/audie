import 'package:build/build.dart';

import 'package:diversion/diversion.dart';
import 'package:source_gen/source_gen.dart';

Builder diversionBuilder(BuilderOptions _) =>
    SharedPartBuilder([DiversionGenerator()], 'diversion');
