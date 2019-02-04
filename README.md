
# Diversion

Developer-centric dependency injection library for dart.

----

## Introduction

Diversion is a minimalist, lightweight, compile time dependency injection
library based on source generation.

It analyses your code with the help of a few simple annotations, and generates
only the necessary factory methods for the objects you're interested in.

The generation soruce is designed to be readable, and easily understandable by
humans. Much like as if you had written the code by hand (except you haven't).

## Dependency injection?

Dependency injection leverages ideas of inversion of control, where your
constructors take all objects it needs to set itself up by parameter, as
opposed to trying to create or find these objects inside the constructor body.

This has many advantages. Your code becomes more *modular*, less *decoupled*,
more *testable*, and more *extensible*.

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

Diversion will look for `@inject`, `@module`, and `@component` annotations.

- `@inject` - Indicates the classes and constructors that should be used by
  Diversion to generate source code. Can be used on concrete classes that have
  exactly one constructor, or in a constructor.
- `@module` - Modules are abstract classes with static methods that provide new
  objects to the Diversion graph. There are usually objects of classes that you
  don't control, and can't annotate with `@inject` yourself.
- `@component` - This is what triggers the actual code generatio. Components
  are the interface between the code you write, and the code Diversion
  generates.
