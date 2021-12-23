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

  void skipNode();

  html.Text text(String value, {List<String Function(Object)>? formatters});

  // void applyProp(html.Element element, String name, Object? value);

  // void applyAttr(html.Element element, String name, Object? value);
}

typedef PropsMapper = List<Object>? Function(
  String tagname,
  List<Object>? props,
);

class IncDomRenderer implements Renderer {
  const IncDomRenderer({this.mapProps});

  final PropsMapper? mapProps;

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
      mapProps != null
          ? mapProps!(tagname, staticPropertyValuePairs)
          : staticPropertyValuePairs,
      mapProps != null
          ? mapProps!(tagname, propertyValuePairs)
          : propertyValuePairs,
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
  void skipNode() {
    inc_dom.skipNode();
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
