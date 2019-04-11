import 'package:test/test.dart';

class Bla {
  Bla(this.x) : assert(x == 1);

  final int x;
}

void main() {
  group('blaing', () {
    test('at inject assert', () async {
      final a = Bla(1);
      expect(a.x, 1);
      expect(() => Bla(0), throws);

      expect(Bla(0).x, 0);
    });
  });
}
