part of deact;

typedef AfterRender = void Function(Deact);

/// This interface provides an API to the Deact application.
abstract class Deact {
  /// Returns the render time of the last update to the
  /// DOM in milliseconds. -1 means not rendered yet.
  num get lastRenderTimeMs;

  /// A function to be called after the node hierarchy was
  /// rendered.
  AfterRender? afterRender;

  Future<void> waitScheduledRender();
}

class _DeactInstance implements Deact {
  final html.Element rootElement;
  final Logger logger;
  final Map<_TreeLocation, ComponentContext> contexts = {};
  final Map<_TreeLocation, _NodeUsage> nodes = {};
  DeactNode? rootNode;
  @override
  num lastRenderTimeMs = -1;
  @override
  AfterRender? afterRender;
  final List<RenderWrapper> wrappers;
  final Set<PrevElem?> _dirty = {};
  Future<void>? _rerenderFuture;
  final Renderer renderer;

  @override
  Future<void> waitScheduledRender() {
    if (_rerenderFuture == null) {
      return Future.delayed(Duration.zero, () => _rerenderFuture);
    }
    return _rerenderFuture!;
  }

  _DeactInstance(
    this.rootElement,
    this.renderer, {
    this.wrappers = const [],
  }) : logger = Logger('deact.${rootElement.hashCode}');
}

class _NodeUsage {
  final Set<_TreeLocation> usedComponentLocations;
  final DeactNode node;

  _NodeUsage(this.node, this.usedComponentLocations);
}

typedef RenderWrapper = DeactNode Function(
  ComponentContext ctx,
  DeactNode Function(ComponentContext) wrap,
);
