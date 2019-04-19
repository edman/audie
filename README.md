
# Diversion

Developer-centric dependency injection library for dart.

----

## Warning, this package is still in alpha

It works, I encourage you try it out and let me know of any problems or feature
requests by filing an issue. See the known caveats section below.

## Introduction

Diversion is a minimalist, lightweight, compile time dependency injection
library based on source generation.

It analyses your code with the help of a few simple annotations, and generates
only the methods necessary to construct the objects you're interested in.

The generated source is designed to be understandable by humans. Much like the
code you'd write by hand.

Diversion is a pure dart package. It works with Flutter, Angular, or any
project using dart really.

## Installation

You'll need `diversion` as a regular dependency in your pubspec, as well as
`diversion_generator` and `build_runner` under dev dependencies.

```yaml
dependencies:
  # diversion contains the two annotations we use.
  diversion: ^0.0.1

dev_dependencies:
  # diversion_generator is the package that generates source for you.
  diversion_generator: ^0.0.1
  # build_runner is neeeded to trigger source generation.
  build_runner: ^1.0.0
```

Then you can trigger source generation as usual, with this command for regular
dart apps.

```sh
$ pub run build_runner build
```

Or this one if you're using Flutter.

```sh
$ flutter packages pub run build_runner watch
```

## Usage

Diversion interacts with your project in three ways:

- `@inject` annotations in constructors. They tell Diversion how to create
  objects of that class. In the example below, the `CoffeeMaker` class has only
one constructor, so we can use inject on the class as well.
- Abstract methods in a class annotated with `@component`. These specify what
  objects you want to access. Diversion will extend this class and implement
its abstract methods based on the types your marked with inject.
- Concrete methods in `@component` classes. Sometimes your classes will depend
  on types you can't mark with inject. Diversion will also look into concrete
methods to learn how to create new types.

That's all. Two annotations. Period. The code below shows a complete sample of
how these concepts come together.

```dart
// Abstract component will be extended in generated sources.
@component
abstract class CoffeeShop {
  // Abstract method tells what types will be surfaced.
  CoffeeMaker maker();

  // Concrete method, says we can use this when needing a Pump.
  Pump providePump(Thermosiphon pump) => pump;

  // This is the boilerplate.
  CoffeeShop._();
  factory CoffeeShop() = _$CoffeeShop;
}

class CoffeeMaker {
  // Diversion will know to use this constructor.
  @inject
  CoffeeMaker(this.pump);
  final Pump pump;
}

abstract class Pump {}

// Class with a single constructor, can annotate at the class level.
@inject
class Thermosiphon implements Pump {}
```

And then from the code above, Diversion generates the following source.

```dart
class _$CoffeeShop extends CoffeeShop {
  @override
  CoffeeMaker maker() => _createCoffeeMaker();

  Pump _createPump() {
    final thermosiphon = Thermosiphon();
    return providePump(thermosiphon);
  }

  CoffeeMaker _createCoffeeMaker() {
    final pump = _createPump();
    return CoffeeMaker(pump);
  }

  _$CoffeeShop() : super._();
}
```

Finally, this can be used to create an instance of `CoffeeMaker` as easily as:

```dart
final maker = CoffeeShop().maker();
```

## Dependency injection

Dependency injection leverages ideas of inversion of control, where your
constructors take all objects it needs to set itself up by parameter, as
opposed to trying to create or find these objects inside the constructor body.
This has many advantages. Your code becomes more *modular*, less *decoupled*,
more *testable*, and more *extensible*.

The downside of dependency injection is that constructing classes becomes more
difficult. If `CofeeMaker` took no arguments and just figured out how to create
a `Pump` by itself, creating it would be as easy as `CoffeeMaker()`.  While now
with dependency injection you need to find a `Pump` first by yourself, and then
it pass it to `CofeeMaker` constructor. This kind of code is mostly mindless
boilerplate, and your time as a developer could be better spent.

That's where an automatic dependency injection library, like Diversion, comes
in. You configure the library by letting it know what your class structure
looks like. In Diversion you do that through `@inject` annotations and provider
methods in `@components`. From that Diversion is able to create all the
mindless boilerplate for you.

It unites the best of both worlds, since now you can enjoy the advantages of
decoupling and testability provided by dependency inversion, while at the same
time creating objects easily through the generated source.

## Design

Diversion was designed to be
- *Simple*: Easy to use in both small and large projects.
- *Understandable*:  No reflection dark magic, you're always welcome to read
  the generated source.
- *Helpful*: When things go wrong, you should be given actionable feedback
  along with a comprehensive explanation of the problem.
- *Useful*: Saves time and improves code organization,

In order to fulfil these objective Diversion purposely drops support to many
features you might be used to from elsewhere.

## Useful snippets

There's some boilerplate you need to write for your components. Luckily you can automate
them with code snippets like this one for IntelliJ and Android Studio:

```dart
@component
abstract class $NAME$ {
  $NAME$._();
  factory $NAME$() = _$$$NAME$;
}
```

And this one for vscode:

```json
  "Diversion component class": {
    "prefix": "component",
    "body": [
      "@component",
      "abstract class ${1:Name} {",
      "\t$2\n",
      "\t${1:Name}._();",
      "\tfactory ${1:Name}() = _$${1:Name};",
      "}"
    ]
  }
```

## Known caveats

- Source generation hangs and never finishes.
  - Reason: Diversion doesn't know how to build one of the types you need due
    to a missing `@inject` or provider method in the `@component`.
  - Workaround: See the source gen logs to figure out what type is missing.

## TODO

- Bug: provider named after return type
  - Firestore firestore() => Firestore.instance;
- Bug: sometimes gened code does not update when changing a constructor
- Runtime parameters
- Find a better solution to optional parameters
- Error on @inject in class with multiple constructors
- Error on @inject in multiple constructors
- Ignore void provider methods in components.
- Error on void provider methods in components.
- Error on dynamic provider methods in components.
- Error on dynamic parameters to inject constructors or provider methods.
- Error on missing boilerplate in components.
- Sample showcasing testability.
- Some tests?
- Configure CI.

## TODO tests

- Two classes with the same dependency

### Next features..
- Field injection
