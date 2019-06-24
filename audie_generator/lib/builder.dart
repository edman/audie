import 'package:build/build.dart';
import 'package:audie_generator/audie_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder builderFactory(BuilderOptions _) =>
    SharedPartBuilder([AudieGenerator()], 'audie_generator');
