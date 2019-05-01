import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:diversion_generator/diversion_generator.dart';
import 'package:diversion_generator/src/creator2.dart';
import 'package:rxdart/rxdart.dart';

class Source {
  Source(this.id) {
    Observable.combineLatest2(
      _components.startWith([]),
      _injects.startWith([]),
      (cs, ins) => SourceData(id, cs, ins),
    ).forEach((s) => _sourceData.add(s));
  }
  final String id;

  Sink<ConstructorElement> get onInject => _onInject;
  final _onInject = PublishSubject<ConstructorElement>();

  Sink<ClassElement> get onComponent => _onComponent;
  final _onComponent = PublishSubject<ClassElement>();

  Observable<List<Creator>> get _injects =>
      _onInject.map((c) => Constructor(c)).scan((acc, c, _) => acc + [c], []);

  Observable<List<ComponentData>> get _components => _onComponent
      .map((c) => ComponentData(id, c))
      .scan((acc, c, _) => acc + [c], []);

  Stream<SourceData> get sourceData => _sourceData;
  final _sourceData = BehaviorSubject<SourceData>();

  void done() {
    _onInject.close();
    _onComponent.close();
    _sourceData.close();
  }
}

class SourceData {
  const SourceData(this.sourceId, this.componentData, this.globalCreators);
  final String sourceId;
  final List<ComponentData> componentData;
  final List<Creator> globalCreators;

  Map<String, Object> toMap() => {
        'sourceId': sourceId,
        'componentData': componentData.map((c) => c.toMap()).toList(),
        'globalCreators': globalCreators.map((c) => c.toString()).toList()
      };

  @override
  String toString() {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toMap());
  }
}

class ComponentData {
  const ComponentData(this.sourceId, this.cls);

  /// May be [null] for sub components.
  final String sourceId;
  final ClassElement cls;

  Iterable<MethodElement> get _providers =>
      cls.methods.where((m) => !m.isAbstract);

  List<Creator> get localCreators =>
      _providers.map<Creator>((p) => Provider(cls, p)).toList();

  List<Creator> get reachableCreators =>
      localCreators +
      subComponentData.expand((s) => s.reachableCreators).toList();

  List<AbstractData> get abstracts => cls.methods
      .where((m) => m.isAbstract)
      .map((m) => AbstractData(m))
      .toList();

  List<DartType> get providerDependencies =>
      localCreators.expand((c) => c.dependencies).toList();

  List<DartType> get abstractDependencies =>
      abstracts.map((a) => a.returnType).toList();

  List<DartType> get dependencies =>
      providerDependencies + abstractDependencies;

  List<ComponentData> get subComponentData => cls.methods
      .map((m) => m.returnType.element)
      .whereType<ClassElement>()
      // .where((c) => c.metadata.map((m) => m.constantValue).contains(component))
      .where((c) => componentType.hasAnnotationOf(c))
      .map((c) => ComponentData(null, c))
      .toList();

  @override
  bool operator ==(Object other) =>
      other is ComponentData && cls.type == other.cls.type;

  int get hashCode => cls.type.hashCode;

  Map<String, Object> toMap() => {
        'sourceId': sourceId,
        'class': cls.toString(),
        'localCreators': localCreators.map((c) => c.toString()).toList(),
        'abstracts': abstracts.map((c) => c.toMap()).toList(),
        'dependencies': dependencies.map((c) => c.toString()).toList(),
        'subComponents': subComponentData.map((c) => c.toMap()).toList(),
      };

  @override
  String toString() {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toMap());
  }
}

class AbstractData {
  const AbstractData(this.method);

  final FunctionTypedElement method;

  DartType get returnType => method.returnType;

  // List<DartType> get dependencies => method.parameters
  //     .where((p) => p.isNotOptional)
  //     .map((p) => p.type)
  //     .toList();

  List<DartType> get optionals =>
      method.parameters.where((p) => p.isOptional).map((p) => p.type).toList();

  Map<String, Object> toMap() => {
        'method': method.toString(),
        // 'dependencies': dependencies.map((d) => d.toString()).toList(),
        'optionals': optionals.map((o) => o.toString()).toList(),
      };

  @override
  String toString() {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toMap());
  }
}
