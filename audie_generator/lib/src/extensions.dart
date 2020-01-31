import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

Iterable<ClassElement> allClasses(LibraryReader library) =>
    library.allElements.whereType<ClassElement>();
