part of deact;

class ScopedItem<T> {
  T _value;
  T get value => _value;
  final Set<ComponentContext> dependents;

  ScopedItem(this._value, this.dependents);
}

class Scoped<T> {
  final T Function(ScopedMap) create;
  final void Function(T)? dispose;

  Scoped(this.create, [this.dispose]);

  T get(ComponentContext context) => context.scoped(this);
}

class ScopedMap {
  final ComponentContext context;
  final Map<Scoped, ScopedItem<Object?>> _map = {};

  ScopedMap(this.context);

  ScopedMap? parent() {
    for (final p in context._parents()) {
      if (p._scopedMap != null) return p._scopedMap;
    }
  }

  T get<T>(Scoped<T> scoped) {
    final _info = _getInfo(scoped);
    return _info == null ? context.scoped(scoped) : _info.value;
  }

  bool contains(Scoped scoped) =>
      _map.containsKey(scoped) || parent()?.contains(scoped) == true;

  void _set<T>(Scoped<T> scoped, ScopedItem<T> value) {
    _map[scoped] = value;
  }

  ScopedItem<T>? _getInfo<T>(Scoped<T> scoped) =>
      _map[scoped] as ScopedItem<T>? ?? parent()?._getInfo(scoped);

  void _removeDep(Scoped scoped, ComponentContext context) {
    final v = _getInfo<Object?>(scoped);
    if (v != null) {
      if (v.dependents.remove(context) && v.dependents.isEmpty) {
        scoped.dispose?.call(v.value);
      }
    }
  }
}
