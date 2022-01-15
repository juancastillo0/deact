part of deact;

void _renderInstance(
  _DeactInstance instance,
  ComponentContext? dirtyComponent,
) {
  instance._dirty.add(dirtyComponent);

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
              _TreeLocation(null, 's:${hostElement.hashCode}', null, key: null);
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
      instance._dirty.removeWhere((ctx) => ctx!.disposed);
      instance._childDirty.clear();
      instance._rendered.clear();

      /// [instance._dirt] elements need to be rebuilt.
      /// Only rebuild dirty parents, if an element is dirty and one
      /// of its parents is also dirty, then the element does not need to
      /// be rebuilt since its parent will rebuild all its children
      final dirtyElements = instance._dirty.map((e) => e!._prevElem).toSet();
      final dirty = instance._dirty.length;
      final dirtyParents = dirtyElements
          .where((elem) => !elem.parents().any(dirtyElements.contains));
      for (final elem in dirtyParents) {
        elem.rebuild();
      }
      if (dirty != instance._dirty.length) {
        throw Exception("Can't schedule rerender while rendering.");
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
      ctx._disposed = true;
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
  _TreeLocation? location;
  if (node is ElementNode) {
    location = _TreeLocation(parentLocation, 'e:${node.name}', nodePosition,
        key: node.key);
    final prevNode = instance.nodes[location];
    if (skip || prevNode?.node == node) {
      instance.renderer.skipNode();
      // TODO: verify when rendering children in scoped
      _usedComponentLocations.addAll(prevNode!.usedComponentLocations);
      return;
    }

    instance.logger.finest('$location: processing node');
    final props = <Object>[];
    String? idKey;
    String? valueProp;
    node.attributes?.forEach((name, value) {
      if (name == 'id' && value is String) idKey = value;
      if (name == 'value' && value is String) valueProp = value;
      props.addAll([name, value]);
    });
    node.listeners?.forEach(
      (event, listener) => props.addAll([event, listener]),
    );

    late final PrevElem prev;
    void _renderChildren(Set<_TreeLocation> _usedComponentLocations) {
      var i = 0;
      for (var child in node._children) {
        _renderNode(instance, child, i, parentContext, location!,
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
      node.key?.toString() ?? idKey,
      null,
      props,
    );
    if (valueProp != null && el is html.InputElement) {
      el.value = valueProp;
    }

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
    final toRender = [...node._children];
    while (toRender.length > i) {
      final child = toRender[i];
      if (child is FragmentNode) {
        toRender.insertAll(i + 1, child._children);
      } else {
        _renderNode(instance, child, i, parentContext, parentLocation,
            usedComponentLocations, previous,
            skip: skip);
      }
      i++;
    }
  } else if (node is TextNode) {
    location = _TreeLocation(parentLocation, 't', nodePosition, key: null);
    //instance.logger.finest('${node._location}: processing node');
    instance.renderer.text(node.text);
  } else if (node is ComponentNode) {
    location = _TreeLocation(
        parentLocation, 'c:${node.runtimeType}', nodePosition,
        key: node.key);

    usedComponentLocations.add(location);
    //instance.logger.finest('${node._location}: processing node');
    bool newContext = false;
    ComponentContext? context = instance.contexts[location];
    if (context == null) {
      context = ComponentContext._(parentContext, instance, location, previous);
      instance.contexts[location] = context;
      //instance.logger.fine('${node._location}: created context');
      newContext = true;
    } else {
      context._prevElem = previous;
    }
    instance._rendered.add(context);
    context._effects.clear();
    context._rendering = true;

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
    context._rendering = false;

    final shouldSkip = instance._dirty.contains(context) == false &&
        (skip || instance.nodes[location]?.node == node);
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
  if (node != null && location != null) {
    instance.nodes[location] = _NodeUsage(node, usedComponentLocations);
  }
}
