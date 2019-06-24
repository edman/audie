import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('generator', () {
    test('extends component', () async {
      final generated = await generate(component());
      expect(generated, contains('_\$Component extends Component'));
    });
    test('uses provider method', () async {
      final generated = await generate(component('''
        String make();
        String provide() => 'use me';'''));
      expect(generated, contains('String make() => provide()'));
    });
    test('uses static provider method', () async {
      final generated = await generate(component('''
        String make();
        static String provide() => 'use me';'''));
      expect(generated, contains('String make() => Component.provide()'));
    });

    test('uses injected class', () async {
      final generated = await generate('''${component('MyType make();')}
      @inject
      class MyType {}
      ''');
      expect(generated, contains('MyType make() => MyType()'));
    });
    test('uses injected constructor', () async {
      final generated = await generate('''${component('MyType make();')}
      class MyType {
        @inject
        MyType();

        MyType(String nothing) {}
      }
      ''');
      expect(generated, contains('MyType make() => MyType()'));
    });
    test('uses provider for interface', () async {
      final c = component('''
      MyInterface make();
      MyInterface provide(MyType m) => m;
      ''');
      final generated = await generate('''$c

      abstract class MyInterface {}

      @inject
      class MyType implements MyInterface {}
      ''');
      expect(generated, contains('MyInterface make() => _createMyInterface()'));
    });
  });
}
