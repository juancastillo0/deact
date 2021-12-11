part of deact;

abstract class Renderer {
  void patch(
    html.Node node,
    void Function(Object?) description, [
    Object? data,
  ]);

  html.Element elementOpen(
    String tagname, [
    String? key,
    List<Object>? staticPropertyValuePairs,
    List<Object>? propertyValuePairs,
  ]);

  html.Element elementClose(String tagname);

  void skip();

  html.Text text(String value, {List<String Function(Object)>? formatters});

  // void applyProp(html.Element element, String name, Object? value);

  // void applyAttr(html.Element element, String name, Object? value);
}

class IncDomRenderer implements Renderer {
  const IncDomRenderer();

  @override
  html.Element elementClose(String tagname) {
    return inc_dom.elementClose(tagname);
  }

  @override
  html.Element elementOpen(
    String tagname, [
    String? key,
    List<Object>? staticPropertyValuePairs,
    List<Object>? propertyValuePairs,
  ]) {
    return inc_dom.elementOpen(
      tagname,
      key,
      staticPropertyValuePairs,
      propertyValuePairs,
    );
  }

  @override
  void patch(
    html.Node node,
    void Function(Object? p1) description, [
    Object? data,
  ]) {
    inc_dom.patch(node, description, data);
  }

  @override
  void skip() {
    inc_dom.skip();
  }

  @override
  html.Text text(String value, {List<String Function(Object)>? formatters}) {
    return inc_dom.text(value, formatters: formatters);
  }

  void applyProp(html.Element element, String name, Object? value) {
    inc_dom.applyProp(element, name, value);
  }

  void applyAttr(html.Element element, String name, Object? value) {
    inc_dom.applyAttr(element, name, value);
  }
}
