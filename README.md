
# Audie

Automatic dependency injection engine for dart.

----

## Warning, this package is still in alpha

It works** but see the known caveats section below.

## Introduction

Audie is a minimalist, lightweight, compile time dependency injection engine
based on source generation.

It understands your code with the help of a few simple annotations, and
generates only the methods necessary to construct the objects you're interested
in.

The generated source is designed to be understandable by humans. Much like the
code you'd write by hand.

Audie is a pure dart package. It works with Flutter, Angular, or any
project using dart.

## Installation

You'll need `audie` as a regular dependency in your pubspec, as well as
`audie_generator` and `build_runner` under dev dependencies.

```yaml
dependencies:
  # audie contains the two annotations we use.
  audie: ^0.0.1

dev_dependencies:
  # audie_generator is the package that generates source for you.
  audie_generator: ^0.0.1
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

Audie interacts with your project in three ways:

- `@inject` annotations in constructors. They tell Audie how to create
  objects of that class. In the example below, the `CoffeeMaker` class has only
one constructor, so we can use inject on the class as well.
- Abstract methods in a class annotated with `@component`. These specify what
  objects you want to access. Audie will extend this class and implement
its abstract methods based on the types you marked with inject.
- Concrete methods in `@component` classes. Sometimes your classes will depend
  on types you can't mark with inject. Audie will also look into concrete
methods to learn how to create new types.

That is all. Two annotations. Period. The code below shows a complete sample of
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
  // Audie will know to use this constructor.
  @inject
  CoffeeMaker(this.pump);
  final Pump pump;
}

abstract class Pump {}

// Class with a single constructor, can annotate at the class level.
@inject
class Thermosiphon implements Pump {}
```

And then from the code above, Audie generates the following source.

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
  "Audie component class": {
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
  - Reason: Audie doesn't know how to build one of the types you need due
    to a missing `@inject` or provider method in the `@component`.
    - Workaround: Make sure all necessary types are either annotated with
    `@inject` or have a provider method. The source gen logs may help figure
    out what type is missing.
  - Reason: A constructor has changed or moved to a different file and audie's
  internal data structures are out of sync.
    - Workaround: Clean the build runner and generate sources again.
    ```sh
    $ flutter packages pub run build_runner clean
    $ flutter packages pub run build_runner watch
    ```

- Audie finishes source generation but the outputs have errors: a function is
  not implemented, or implemented multiple times.
  - Reason: Same as above, audie's internal data structures are out of sync.
    - Workaround: As above, clean and generate sources again.

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
- Configure CI.

## TODO tests

- Two classes with the same dependency

### Next features..
- Field injection
