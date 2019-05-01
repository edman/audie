import 'package:analyzer/dart/element/type.dart';
import 'package:diversion_generator/src/creator2.dart';
import 'package:diversion_generator/src/model.dart';
import 'package:rxdart/rxdart.dart';

class Engine {
  Engine._() {
    _onSource
        .scan<Map<String, Stream<SourceData>>>(
          (sourceMap, s, _) => sourceMap..[s.id] = s.sourceData,
          {},
        )
        .map((sourceMap) => sourceMap.values)
        .switchMap((sourceSet) =>
            Observable.combineLatest(sourceSet, (sourceSet) => sourceSet))
        .forEach((s) => _sourceSet.add(s));

    Observable(engineData).scan((acc, e, _) => null);
  }
  static final Engine instance = Engine._()
    ..sourceSet.listen((s) => print('sourceSet $s'))
    ..engineData.listen((e) => print('engine $e'))
    ..feasibleComponents.listen((c) => print('HERE! $c'));
  // ..globalCreators.listen(print);

  Sink<Source> get onSource => _onSource;
  final _onSource = PublishSubject<Source>();

  Stream<List<SourceData>> get sourceSet => _sourceSet;
  final _sourceSet = BehaviorSubject<List<SourceData>>();

  Stream<List<Creator>> get globalCreators => sourceSet
      .map((sourceSet) => sourceSet.expand((s) => s.globalCreators).toList());

  Stream<List<ComponentData>> get components => sourceSet
      .map((sourceSet) => sourceSet.expand((s) => s.componentData).toList());

  Stream<EngineData> get engineData => Observable.combineLatest2(
      components, globalCreators, (c, g) => EngineData(c, g));

  // Stream<Map<ComponentData, ComponentStatus>> get componentStatuses =>
  //     engineData.map((e) => Map.fromIterable(e.components,
  //         value: (c) => c.reachableCreators + e.globalCreators));
  Stream<List<ComponentStatus>> get componentStatuses => engineData.map((e) => e
      .components
      .map((c) => ComponentStatus(c, e.globalCreators + c.reachableCreators))
      .toList());

  Stream<List<ComponentData>> get feasibleComponents =>
      componentStatuses.map((statuses) =>
          statuses.where((s) => s.isFeasible).map((s) => s.component).toList());

  // Stream<Map<ComponentData, ComponentGenDescription>> get output;
}

class ComponentGenDescription {
  const ComponentGenDescription(this.component, this.abstractDescriptions);
  final ComponentData component;
  final List<MethodGenDescription> abstractDescriptions;

  @override
  String toString() =>
      'components $component' '\nabstracts: $abstractDescriptions';
}

class MethodGenDescription {
  const MethodGenDescription(this.abstractData, this.dependencies);
  final AbstractData abstractData;
  final List<Creator> dependencies;

  String get description {
    return 'TODO';
  }

  @override
  String toString() => 'abstract: $abstractData';
}

class ComponentStatus {
  const ComponentStatus(this.component, this.reachableCreators);
  final ComponentData component;
  final List<Creator> reachableCreators;

  List<DartType> get _reachableTypes =>
      reachableCreators.map((c) => c.createdType).toList();

  bool get isFeasible =>
      !component.dependencies.any((d) => !_reachableTypes.contains(d));

  ComponentGenDescription describe() {
    if (!isFeasible)
      throw StateError('No known description for component $component');

    return null;
  }
}

class EngineData {
  const EngineData(this.components, this.globalCreators);
  final List<ComponentData> components;
  final List<Creator> globalCreators;

  @override
  String toString() => 'components: $components' '\ncreators: $globalCreators';
}
