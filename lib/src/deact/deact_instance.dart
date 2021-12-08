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
  final String selector;
  final Logger logger;
  final Map<_TreeLocation, ComponentContext> contexts = {};
  DeactNode? rootNode;
  @override
  num lastRenderTimeMs = -1;
  @override
  AfterRender? afterRender;
  final List<RenderWrapper> wrappers;
  final Set<PrevElem?> _dirty = {};
  Future<void>? _rerenderFuture;

  @override
  Future<void> waitScheduledRender() {
    if (_rerenderFuture == null) {
      return Future.delayed(Duration.zero, () => _rerenderFuture);
    }
    return _rerenderFuture!;
  }

  _DeactInstance(
    this.selector, {
    this.wrappers = const [],
  }) : logger = Logger('deact.$selector');
}

typedef RenderWrapper = DeactNode Function(
  ComponentContext ctx,
  DeactNode Function(ComponentContext) wrap,
);
