part of deact;

void _renderInstance(
  _DeactInstance instance,
  ComponentContext? dirtyComponent,
) {
  instance._dirty.add(dirtyComponent?._prevElem);

  instance._rerenderFuture ??= Future(() {
    final sw = Stopwatch();
    sw.start();

    /// `null` is the root element, if it's dirty
    /// then render the whole tree
    if (instance._dirty.contains(null)) {
      final hostElement = instance.rootElement;

      late final PrevElem _prevElem;
      _prevElem = PrevElem._(
        hostElement,
        null,
        () {
          final usedComponentLocations = <_TreeLocation>{};
          final location =
              _TreeLocation(null, 's:${hostElement.hashCode}', null);
          instance.renderer.patch(
            hostElement,
            (_) => _renderNode(
              instance,
              instance.rootNode,
              0,
              ComponentContext._(null, instance, location, _prevElem),
              location,
              usedComponentLocations,
              _prevElem,
            ),
          );
          _removeLocations(
              instance, instance.contexts.keys, usedComponentLocations);
        },
      );
      final dirty = instance._dirty.length;
      _prevElem.rebuild();
      if (dirty != instance._dirty.length) {
        throw Exception("Can't schedule rerender while rendering.");
      }
      instance._dirty.remove(null);
    }

    do {
      instance._dirty.addAll(instance._childDirty);
      instance._dirty.removeAll(instance._rendered);
      instance._childDirty.clear();
      instance._rendered.clear();

      /// [instance._dirt] elements need to be rebuilt.
      /// Only rebuild dirty parents, if an element is dirty and one
      /// of its parents is also dirty, then the element does not need to
      /// be rebuilt since its parent will rebuild all its children
      final dirtyParents = instance._dirty
          .whereType<PrevElem>()
          .where((elem) => !elem.parents().any(instance._dirty.contains));
      for (final elem in dirtyParents) {
        elem.rebuild();
      }
    } while (instance._dirty.isNotEmpty);

    /// Clean Up
    instance._rerenderFuture = null;
    instance.lastRenderTimeMs = sw.elapsedMilliseconds;
    instance.afterRender?.call(instance);
  });
}

void _removeLocations(
  _DeactInstance instance,
  Iterable<_TreeLocation> previousComponentLocations,
  Set<_TreeLocation> usedComponentLocations,
) {
  final locationsToRemove = <_TreeLocation>{};
  for (var location in previousComponentLocations) {
    if (usedComponentLocations.contains(location) == false) {
      locationsToRemove.add(location);
    }
  }
  for (var location in locationsToRemove) {
    final ctx = instance.contexts[location];
    if (ctx != null) {
      for (var cleanup in ctx._cleanups.values) {
        cleanup();
      }
      for (final hook in ctx._previousHookEffects) {
        hook.cleanup?.call();
      }
    } else {
      //instance.logger.warning('${location}: no context found. this looks like a bug!');
    }
    instance.contexts.remove(location);
    instance.nodes.remove(location);
    //instance.logger.fine('${location}: removed context');
  }
}

class PrevElem {
  final html.Element elem;
  final PrevElem? parent;
  final void Function() rebuild;

  PrevElem._(this.elem, this.parent, this.rebuild);

  Iterable<PrevElem> parents() sync* {
    PrevElem? _parent = parent;
    while (_parent != null) {
      yield _parent;
      _parent = _parent.parent;
    }
  }
}

void _renderNode(
  _DeactInstance instance,
  DeactNode? node,
  int nodePosition,
  ComponentContext parentContext,
  _TreeLocation parentLocation,
  Set<_TreeLocation> _usedComponentLocations,
  PrevElem previous, {
  bool skip = false,
}) {
  final Set<_TreeLocation> usedComponentLocations = {};
  if (node is ElementNode) {
    final location = _TreeLocation(
        parentLocation, 'e:${node.name}', nodePosition,
        key: node.key);
    node._location = location;
    final prevNode = instance.nodes[location];
    if (skip || prevNode?.node == node) {
      instance.renderer.skipNode();
      _usedComponentLocations.addAll(prevNode!.usedComponentLocations);
      return;
    }

    instance.logger.finest('${node._location}: processing node');
    final props = <Object>[];
    final attributes = node.attributes;
    if (attributes != null) {
      attributes.forEach((name, value) => props.addAll([name, value]));
    }
    final listeners = node.listeners;
    if (listeners != null) {
      listeners.forEach((event, listener) => props.addAll([event, listener]));
    }

    late final PrevElem prev;
    void _renderChildren(Set<_TreeLocation> _usedComponentLocations) {
      var i = 0;
      for (var child in node._children) {
        _renderNode(instance, child, i, parentContext, location,
            _usedComponentLocations, prev);
        i++;
      }
    }

    if (node.rawElement != null) {
      final el = instance.renderer.elementOpen('html-blob');
      if (el.nodes.isEmpty || el.nodes.first != node.rawElement) {
        for (final n in el.nodes.toList()) {
          n.remove();
        }
        el.append(node.rawElement!);
      }
      instance.renderer.skip();
      instance.renderer.elementClose('html-blob');
      return;
    }
    final el = instance.renderer.elementOpen(
      node.name,
      null,
      null,
      props,
    );

    Set<_TreeLocation> currentLocations = {};
    bool _building = true;
    prev = PrevElem._(el, previous, () {
      if (_building) return;
      _building = true;
      final Set<_TreeLocation> _newLocations = {};
      instance.renderer.patch(el, (_) {
        _renderChildren(_newLocations);
      });
      _removeLocations(instance, currentLocations, _newLocations);
      currentLocations = _newLocations;
      _building = false;
    });
    _renderChildren(currentLocations);
    _building = false;
    usedComponentLocations.addAll(currentLocations);

    instance.renderer.elementClose(node.name);
    final ref = node.ref;
    if (ref != null && ref.value != el) {
      ref.value = el;
    }
  } else if (node is FragmentNode) {
    var i = 0;
    for (var child in node._children) {
      _renderNode(instance, child, i, parentContext, parentLocation,
          usedComponentLocations, previous,
          skip: skip);
      i++;
    }
  } else if (node is TextNode) {
    node._location = _TreeLocation(parentLocation, 't', nodePosition);
    //instance.logger.finest('${node._location}: processing node');
    instance.renderer.text(node.text);
  } else if (node is ComponentNode) {
    final location = _TreeLocation(
        parentLocation, 'c:${node.runtimeType}', nodePosition,
        key: node.key);

    node._location = location;
    usedComponentLocations.add(location);
    //instance.logger.finest('${node._location}: processing node');
    var newContext = false;
    var context = instance.contexts[node._location];
    if (context == null) {
      context = ComponentContext._(parentContext, instance, location, previous);
      instance.contexts[location] = context;
      //instance.logger.fine('${node._location}: created context');
      newContext = true;
    } else {
      context._prevElem = previous;
    }
    instance._rendered.add(previous);
    context._effects.clear();

    /// execute [node.render] with [instance.wrappers]
    final DeactNode elementNode;
    if (instance.wrappers.isEmpty) {
      elementNode = node.render(context);
    } else {
      DeactNode Function(ComponentContext) next = node.render;
      for (final wrap in instance.wrappers) {
        final _next = next;
        next = (c) => wrap(c, _next);
      }
      elementNode = next(context);
    }
    final shouldSkip = skip ||
        instance._dirty.contains(context._prevElem) == false &&
            instance.nodes[location]?.node == node;
    _renderNode(instance, elementNode, 0, context, location,
        usedComponentLocations, previous,
        skip: shouldSkip);

    /// Clean Up
    for (var name in context._effects.keys) {
      final states = context._effectStateDependencies[name];
      var executeEffect = false;
      if (states == null || newContext) {
        executeEffect = true;
      } else {
        for (final state in states) {
          if (state._valueChanged) {
            executeEffect = true;
            break;
          }
        }
      }

      if (executeEffect) {
        final cleanup = context._cleanups[name];
        if (cleanup != null) {
          cleanup();
        }
        final effect = context._effects[name];
        if (effect != null) {
          final newCleanup = effect();
          if (newCleanup != null) {
            context._cleanups[name] = newCleanup;
          }
        }
      }
    }
    for (var state in context._states.values) {
      state._valueChanged = false;
    }
    context._afterRender();
  } else if (node == null) {
    // null means nothing should be rendered
  } else {
    throw ArgumentError('unsupported type ${node.runtimeType} of node!');
  }
  _usedComponentLocations.addAll(usedComponentLocations);
  if (node != null && node._location != null) {
    instance.nodes[node._location!] = _NodeUsage(node, usedComponentLocations);
  }
}
