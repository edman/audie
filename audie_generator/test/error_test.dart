import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Error when', () {
    test('@inject class has multiple constructors', () async {
      final generated = await generate('''
      @inject
      class MyType {
        MyType();

        MyType(String nothing) {}
      }
      ''');
      print('HERE: generated="$generated"');
      expect(generated, contains('Move the @inject annotation'));
    });
  });
}
