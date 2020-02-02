import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Error when', () {
    test('@inject class has multiple constructors', () async {
      final generated = await generate('''
      ${component('SomeType make();')}
      
      @inject
      class SomeType {
        SomeType();

        SomeType(String nothing) {}
      }
      ''');
      expect(generated, contains('has more than one constructor'));
    });
    test('class is needed but has not @inject nor provider', () async {
      final generated = await generate('''
      ${component('SomeType make();')}
      
      class SomeType {}
      ''');
      expect(generated, contains('needed but we don\'t know how to make it'));
    });
  });
}
