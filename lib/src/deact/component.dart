part of deact;

class _TypeLiteral<T> {
  Type type() => T;
}

/// A combination of a [GlobalStateProvider]
/// and a [GlobalRefProvider].
abstract class GlobalProvider
    implements GlobalStateProvider, GlobalRefProvider {}

/// A reference to a value.
///
/// The reference will persist the component is removed
/// from the node hierarchy.
///
/// Changing the value of the reference does not force a
/// rerender of the component. But it is possible to add
/// a listener to the stream of change events.
///
/// If the initial value of the reference is not null,
/// then this value will be added to the stream of change
/// events.
class Ref<T> {
  final _TypeLiteral<T> _type;
  final StreamController<T> _streamController = StreamController<T>.broadcast();
  final bool _global;
  T? _value;

  Ref._(this._global, this._value) : _type = _TypeLiteral<T>() {
    if (_value != null) {
      _streamController.add(_value as T);
    }
  }

  T get value => _value as T;

  set value(T value) {
    _value = value;
    _streamController.add(_value as T);
  }

  /// Returns a stream of events of changes to the value
  /// of the reference.
  Stream<T> get onChange => _streamController.stream;
}

/// A state for a component or a state provider.
///
/// If a state of a component changes, the component and
/// its children will be rerendered. If the state of a
/// state provider changes, all children of the state
/// provider will be rerendered.
///
/// Important: State changes has to executed using the
/// [update] or [set] functions, otherwise Deact will
/// not recognize, that the state has changed.
class State<T> {
  final _DeactInstance _instance;
  final ComponentContext context;
  final _TypeLiteral<T> _type;
  final bool _global;
  T? _value;
  bool _valueChanged = true;

  State._(this._instance, this.context, this._global, this._value)
      : _type = _TypeLiteral<T>();

  void _rebuild() {
    if (_global) {
      _renderInstance(_instance, null);
    } else {
      if (!context.rendering) {
        context.scheduleRerender();
      }
    }
  }

  /// Executes to provided [updater] function to update
  /// a part of the state. This function is useful for
  /// complex mutable state objects. After the [updater]
  /// function was executed, the component and its children
  /// will be rerendered using the new state.
  void update(void Function(T state) updater) {
    updater(_value as T);
    _valueChanged = true;
    _rebuild();
  }

  /// Executes to provided [setter] function to replace
  /// the complete state. This function is useful for
  /// immutable state objects. After the [setter] function
  /// was executed, the component and its children will
  /// be rerendered using the new state.
  void set(T Function(T state) setter) {
    final prev = _value;
    _value = setter(_value as T);

    final changed = _value != prev;
    if (changed) {
      _valueChanged = true;
      _rebuild();
    }
  }

  /// Sets a new state. After the new state is applied,
  /// the component and its children will be rerendered
  /// using the new state.
  set value(T value) {
    final changed = value != this._value;
    if (changed) {
      _value = value;
      _valueChanged = true;
      _rebuild();
    }
  }

  /// Returns the actual state object.
  T get value => _value as T;
}

/// A function to be called to cleanup an effect.
typedef Cleanup = void Function();

/// An [Effect] is a function to be called when a
/// compoenent was (re)rendered.
typedef Effect = Cleanup? Function();

typedef KeysEquals = bool Function(Object?, Object?);

bool defaultKeysEquals(Object? a, Object? b) => a == b;

class HookEffect {
  final Effect effect;
  final List<Object?>? keys;
  final KeysEquals isEqual;
  Cleanup? cleanup;

  HookEffect({
    required this.effect,
    required this.keys,
    required this.isEqual,
  });
}

/// A function to provide an intial value.
typedef InitialValueProvider<T> = T Function();

/// A [ComponentContext] is the interface for
/// component to the Deact API. It is provied to the
/// component, when it is rendered.
class ComponentContext {
  final _DeactInstance _instance;
  final ComponentContext? _parent;
  final _TreeLocation _location;
  final Map<String, Ref> _refs = {};
  final Map<String, State> _states = {};
  final Map<String, Effect> _effects = {};
  final Map<String, Cleanup> _cleanups = {};
  final Map<String, Iterable<State>?> _effectStateDependencies = {};

  int? _hookRefIndex;
  final List<Ref> _hookRefs = [];
  int? _hookStateIndex;
  final List<State> _hookStates = [];

  List<HookEffect> _hookEffects = [];
  List<HookEffect> _previousHookEffects = [];
  PrevElem _prevElem;
  ScopedMap? _scopedMap;
  bool _disposed = false;
  bool get disposed => _disposed;
  bool _rendering = false;
  bool get rendering => _rendering;

  ComponentContext._(
      this._parent, this._instance, this._location, this._prevElem);

  Iterable<ComponentContext> _parents() sync* {
    ComponentContext? parent = _parent;
    while (parent != null) {
      yield parent;
      parent = parent._parent;
    }
  }

  /// Creates a reference with the given [name] and
  /// [intialValue].
  ///
  /// If no reference is registered with the given
  /// [name], a new reference is created with
  /// [initialValue] as initial value. The next time the
  /// reference is accessed, this value will be returned.
  /// A reference will persist until the component is
  /// removed from the node hierarchy.
  ///
  /// Setting [global] to `true` makes the reference
  /// accessible for all children of the component.
  Ref<T> ref<T>(String name, T initialValue, {bool global = false}) {
    return _refs.putIfAbsent(name, () {
      final ref = Ref<T>._(global, initialValue);
      //_instance.logger.fine('${_location}: created ref with name ${name} with initial value ${initialValue}');
      return ref;
    }) as Ref<T>;
  }

  /// Creates a reference with the given [name] and
  /// the result of a call to [initialValueProvider].
  ///
  /// If no reference is registered with the given
  /// [name], a new reference is created with by calling
  /// [initialValueProvider]. The next time the
  /// reference is accessed, this value will be returned.
  /// A reference will persist until the component is
  /// removed from the node hierarchy.
  ///
  /// Use this method if the initial value is expensive
  /// to compute, because the function will only be
  /// called once to create the initial value.
  ///
  /// Setting [global] to `true` makes the reference
  /// accessible for all children of the component.
  Ref<T> refProvided<T>(
    String name,
    InitialValueProvider<T> initialValueProvider, {
    bool global = false,
  }) {
    return _refs.putIfAbsent(name, () {
      final initialValue = initialValueProvider.call();
      final ref = Ref<T>._(global, initialValue);
      //_instance.logger.fine('${_location}: created ref with name ${name} with initial value ${initialValue}');
      return ref;
    }) as Ref<T>;
  }

  /// Returns a state provided by a [GlobalRefProvider].
  ///
  /// If no reference with the given [name] and type [R] is
  /// found, an [StateError] is thrown. The search starts
  /// at the nearest state provider of the compoent and
  /// proceeds in direction to the root of the node
  /// hierarchy.
  Ref<R> globalRef<R>(String name) {
    ComponentContext? ctx = this;
    while (ctx != null) {
      final ref = ctx._refs[name];
      if (ref != null && ref._global && ref._type.type() == R) {
        return ref as Ref<R>;
      }
      ctx = ctx._parent;
    }
    return throw StateError('no global ref with name $name and type $R found!');
  }

  /// Creates a state with the given [name] and
  /// [intialValue]. This state is local to the component.
  ///
  /// If no state is registered with the given
  /// [name], a new state is created with [initialValue]
  /// as initial state. The next time the state is
  /// accessed, this state will be returned. A
  /// state will persist until the component is removed
  /// from the node hierarchy.
  ///
  /// If the initial value is expensive to compute, it is
  /// possible to provide `null` as the initial value
  /// and a function as an additional parameter. That
  /// function will only be called once to create the
  /// initial value.
  ///
  /// Setting [global] to `true` makes the state accessible
  /// for all children of the component.
  State<T> state<T>(String name, T initialValue, {bool global = false}) {
    return _states.putIfAbsent(name, () {
      final state = State<T>._(_instance, this, global, initialValue);
      //_instance.logger.fine('${_location}: created state with name ${name} with initial value ${initialValue}');
      return state;
    }) as State<T>;
  }

  /// Creates a state with the given [name] and the result
  /// of a call to  [initialValueProvider]. This state is
  /// local to the component.
  ///
  /// If no state is registered with the given [name], a
  /// new state is created with by calling
  /// [initialValueProvider]. The next time the state is
  /// accessed, this state will be returned. A state will
  /// persist until the component is removed from the
  /// node hierarchy.
  ///
  /// Use this method if the initial value is expensive
  /// to compute, because the function will only be
  /// called once to create the initial value.
  ///
  /// Setting [global] to `true` makes the state accessible
  /// for all children of the component.
  State<T> stateProvided<T>(
    String name,
    InitialValueProvider<T> initialValueProvider, {
    bool global = false,
  }) {
    return _states.putIfAbsent(name, () {
      final initialValue = initialValueProvider();
      final state = State<T>._(_instance, this, global, initialValue);
      //_instance.logger.fine('${_location}: created state with name ${name} with initial value ${initialValue}');
      return state;
    }) as State<T>;
  }

  /// Returns a state provided by a [GlobalStateProvider].
  ///
  /// If no state with the given [name] and type [S] is
  /// found, an [StateError] is thrown. The search starts
  /// at the nearest state provider of the compoent and
  /// proceeds in direction to the root of the node
  /// hierarchy.
  State<S> globalState<S>(String name) {
    ComponentContext? ctx = this;
    while (ctx != null) {
      final state = ctx._states[name];
      if (state != null && state._global && state._type.type() == S) {
        return state as State<S>;
      }
      ctx = ctx._parent;
    }
    return throw StateError(
      'no global state with name $name and type $S found!',
    );
  }

  /// Introduces an effect that will be called, if the
  /// component mounts (first time rendered) and if one
  /// of the states in [dependsOn] has changed.
  ///
  /// If [dependsOn] is [null], the effect is executed
  /// every time, the component is rerendered. If
  /// [dependsOn] is an empty list, the component is only
  /// rendered after it was mounted (first rendered). If
  /// [dependsOn] is not empty, the effect is only executed
  /// when one of the states in the list has changed since
  /// the last time the component was renderer and when the
  /// components mounts.
  ///
  /// If the effect return a [Cleanup] function, the
  /// cleanup will be executed when the component is
  /// removed from the DOM and before the effect is
  /// executed the next time.
  void effect(String name, Effect effect, {Iterable<State>? dependsOn}) {
    _effects[name] = effect;
    _effectStateDependencies[name] = dependsOn;
  }

  ScopedMap get scopedMap => _scopedMap ??= ScopedMap(this);

  T setUpScoped<T>(Scoped<T> scoped, T value) {
    final ref = hookRef(() {
      // final v = value(scopedMap);
      final it = ScopedItem<T>(value, {this});
      scopedMap._set(scoped, it);
      return it;
    });
    if (ref.value.value != value) {
      ref.value._value = value;
      for (final c in ref.value.dependents) {
        if (c != this) _instance._childDirty.add(c);
      }
    }
    hookEffect(() {
      return () => scopedMap._removeDep(scoped, this);
    }, const []);

    return value;
  }

  T scoped<T>(Scoped<T> scoped) {
    final _it = scopedMap._getInfo(scoped);
    final ScopedItem<T> it;
    if (_it != null) {
      it = _it;
      it.dependents.add(this);
    } else {
      final value = scoped.create(scopedMap);
      it = ScopedItem(value, {this});
      scopedMap._set(scoped, it);
    }

    hookEffect(() {
      return () => scopedMap._removeDep(scoped, this);
    }, const []);

    return it.value;
  }

  void hookEffect(
    Effect effect, [
    List<Object?>? keys,
    KeysEquals isEqual = defaultKeysEquals,
  ]) {
    final _hook = HookEffect(
      effect: effect,
      keys: keys,
      isEqual: isEqual,
    );
    _hookEffects.add(_hook);
  }

  static bool areKeysDifferent(
    List<Object?>? prevKeys,
    List<Object?>? newKeys,
    KeysEquals isEqual,
  ) {
    int i = 0;
    return newKeys == null ||
        prevKeys == null ||
        (prevKeys.length != newKeys.length ||
            prevKeys.any((e) => !isEqual(e, newKeys[i++])));
  }

  void _afterRender() {
    for (int i = 0;
        i < math.max(_hookEffects.length, _previousHookEffects.length);
        i++) {
      final previous =
          _previousHookEffects.length > i ? _previousHookEffects[i] : null;
      final current = _hookEffects.length > i ? _hookEffects[i] : null;
      if (previous != null && current != null) {
        assert(previous.isEqual == current.isEqual);
        final prevKeys = previous.keys;
        final newKeys = current.keys;

        if (areKeysDifferent(prevKeys, newKeys, current.isEqual)) {
          previous.cleanup?.call();
          current.cleanup = current.effect();
        } else {
          current.cleanup = previous.cleanup;
        }
      } else if (current != null) {
        current.cleanup = current.effect();
      } else if (previous != null) {
        previous.cleanup?.call();
      }
    }

    _previousHookEffects = _hookEffects;
    _hookEffects = [];

    _hookRefIndex = 0;
    _hookStateIndex = 0;
  }

  Ref<T> hookRef<T>(T Function() builder) {
    final Ref<T> ref;
    if (_hookRefIndex == null) {
      ref = Ref._(false, builder());
      _hookRefs.add(ref);
    } else {
      final _ref = _hookRefs[_hookRefIndex!];
      ref = _ref as Ref<T>;
      _hookRefIndex = _hookRefIndex! + 1;
    }
    return ref;
  }

  State<T> hookState<T>(T Function() builder) {
    final State<T> state;
    if (_hookStateIndex == null) {
      state = State._(_instance, this, false, builder());
      _hookStates.add(state);
    } else {
      final _state = _hookStates[_hookStateIndex!];
      state = _state as State<T>;
      _hookStateIndex = _hookStateIndex! + 1;
    }
    return state;
  }

  /// Schedules a rerender of the component and all its
  /// children.
  void scheduleRerender() {
    _renderInstance(_instance, this);
  }
}

/// A function that creates a component.
typedef FunctionalComponent = DeactNode Function(ComponentContext ctx);

/// Super class for class-based components.
abstract class ComponentNode extends DeactNode {
  final Object? key;

  /// States and effects are not bound to a component but to
  /// its location the node hierarchy. If no [key] is provided,
  /// the location of a component is compposed of the
  /// location of its parent, the type of the component and
  /// an index per component type that is increased for every
  /// component of the same type beneath the same parent.
  /// Thus, if there are 2 functional components without a
  /// key beneath the same parent, they will have the index 0
  /// and 1. Even is the position are swapped, the first
  /// component will has the index 0 and the second
  /// component will has the index 1. To change this behaviour
  /// you can provided a key to a component (e.g. a technical
  /// id or a name). When a component with a key is moved its
  /// states and effects will also move.
  const ComponentNode({this.key}) : super._(const []);

  /// Override this method to render the content of the
  /// component.
  DeactNode render(ComponentContext ctx);
}

/// Deact internally stores a functional component as a
/// class of this type.
class Functional extends ComponentNode {
  final FunctionalComponent builder;

  Functional._({Object? key, required this.builder}) : super(key: key);

  @override
  DeactNode render(ComponentContext context) {
    return builder(context);
  }
}

/// A helper function to implement functional components.
///
/// This functions creates a [Functional]. The provided
/// [builder function] will be called in the [render]
/// function.
///
/// States and effects are not bound to a component but to
/// its location the node hierarchy. If no [key] is provided,
/// the location of a component is compposed of the
/// location of its parent, the type of the component and
/// an index per component type that is increased for every
/// component of the same type beneath the same parent.
/// Thus, if there are 2 functional components without a
/// key beneath the same parent, they will have the index 0
/// and 1. Even is the position are swapped, the first
/// component will has the index 0 and the second
/// component will has the index 1. To change this behaviour
/// you can provided a key to a component (e.g. a technical
/// id or a name). When a component with a key is moved its
/// states and effects will also move.
DeactNode fc(
  FunctionalComponent builder, {
  Object? key,
}) {
  return Functional._(key: key, builder: builder);
}
