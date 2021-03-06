import 'package:audie/audie.dart';
import 'heater.dart';

abstract class Pump {}

class Thermosiphon implements Pump {
  @inject
  Thermosiphon(this.heater);

  final ElectricHeater heater;
}
