library deact;

import 'dart:async';
import 'package:universal_html/html.dart' as html;
import 'dart:math' as math;

import 'src/deact/inc_dom.dart'
    if (dart.library.html) 'package:incremental_dom_bindings/incremental_dom_bindings.dart'
    as inc_dom;
import 'package:logging/logging.dart';

part 'src/deact/component.dart';
part 'src/deact/deact_instance.dart';
part 'src/deact/element.dart';
part 'src/deact/fragment.dart';
part 'src/deact/global_ref_provider.dart';
part 'src/deact/global_state_provider.dart';
part 'src/deact/node.dart';
part 'src/deact/render.dart';
part 'src/deact/text.dart';
part 'src/deact/tree_location.dart';
part 'src/deact/renderer.dart';
part 'src/deact/scope.dart';

/// A function to provide the root node to the [deact]
/// function.
typedef RootNodeProvider = DeactNode Function(Deact);

/// The entrypoint to mount a Deact application to the DOM.
///
/// The application will be mounted beneath the elements
/// selected by the given [selector]. All node beneath
/// that element will be deleted and replaced by the
/// [root] node.
Deact deact(
  String selector,
  RootNodeProvider root, {
  Renderer renderer = const IncDomRenderer(),
  List<RenderWrapper> wrappers = const [],
}) {
  final hostElement = html.querySelector(selector);
  if (hostElement == null) {
    throw ArgumentError(
      'no element found for selector $selector',
    );
  }
  return deactInNode(
    hostElement,
    root,
    renderer: renderer,
    wrappers: wrappers,
  );
}

/// The entrypoint to mount a Deact application to the DOM.
///
/// The application will be mounted beneath the elements
/// selected by the given [selector]. All node beneath
/// that element will be deleted and replaced by the
/// [root] node.
Deact deactInNode(
  html.Element selector,
  RootNodeProvider root, {
  Renderer renderer = const IncDomRenderer(),
  List<RenderWrapper> wrappers = const [],
}) {
  // Input elements have attributes and properties with
  // the same name. The Deact element API usually sets the
  // the attribute. If an user interaction updates the value
  // of a property with one of those names, the attribute with
  // that name is ignored. For those properties/attributes
  // it is required to set the attribute and the properties.
  inc_dom.attributes['checked'] = _applyAttrAndPropBool;
  inc_dom.attributes['selected'] = _applyAttrAndPropBool;

  // create the deact instance
  final deact = _DeactInstance(selector, renderer, wrappers: wrappers);
  deact.rootNode = root(deact);

  // Initial render of the Deact node hierarchy.
  _renderInstance(deact, null);

  return deact;
}

void _applyAttrAndPropBool(html.Element element, String name, Object? value) {
  inc_dom.applyAttr(element, name, value);
  inc_dom.applyProp(element, name, value != null);
}
