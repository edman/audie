import 'package:audie/audie.dart';

import 'heater.dart';
import 'pump.dart';

part 'coffee.g.dart';

@component
abstract class CoffeeShop {
  CoffeeMaker maker();

  Pump providePump(Thermosiphon pump) => pump;

  CoffeeShop._();
  factory CoffeeShop() = _$CoffeeShop;
}

@inject
class CoffeeMaker {
  CoffeeMaker(this.heater, this.pump);
  final ElectricHeater heater;
  final Pump pump;
}
