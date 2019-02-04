import 'package:diversion/diversion.dart';

import 'heater.dart';
import 'pump.dart';

part 'coffee.g.dart';

@component
abstract class CoffeeShop {
  CoffeeMaker maker();

  CoffeeShop._();
  factory CoffeeShop() => _$CoffeeShop();
}

@module
abstract class DripCoffeeModule {
  static Pump providePump(Thermosiphon pump) => pump;
}

@inject
class CoffeeMaker {
  CoffeeMaker(this.heater, this.pump);
  final ElectricHeater heater;
  final Pump pump;
}
