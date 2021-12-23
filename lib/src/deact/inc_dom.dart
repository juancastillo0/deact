import 'package:universal_html/html.dart' as html;

final _unsupportedException = UnsupportedError(
  'Incremental dom can only be used when compiling to JavaScript',
);

void patch(
  html.Node node,
  void Function(Object?) description, [
  Object? data,
]) =>
    throw _unsupportedException;

html.Element elementOpen(
  String tagname, [
  String? key,
  List<Object>? staticPropertyValuePairs,
  List<Object>? propertyValuePairs,
]) =>
    throw _unsupportedException;

html.Element elementClose(String tagname) => throw _unsupportedException;

void skip() => throw _unsupportedException;
void skipNode() => throw _unsupportedException;

html.Text text(String value, {List<String Function(Object)>? formatters}) =>
    throw _unsupportedException;

void applyProp(html.Element element, String name, Object? value) =>
    throw _unsupportedException;

void applyAttr(html.Element element, String name, Object? value) =>
    throw _unsupportedException;

/// A function to set a value as a property
/// or attribute for an element.
typedef ValueSetter = void Function(
    html.Element element, String name, Object? value);

final attributes = Attributes._();

/// See [attributes].
class Attributes {
  Attributes._();

  /// If no function is specified for a given name, a
  /// default function is used that applies values as
  /// described in Attributes and Properties. This can
  /// be changed by specifying the default function.
  ///
  /// FIXME: not yet working
  void setDefault(ValueSetter? setter) {
    this['__default'] = setter;
  }

  /// Sets a [ValueSetter] for a property/attribute
  /// identified by a [name].
  void operator []=(String name, ValueSetter? setter) {
    // TODO:
    // _attributes[name] = setter;
  }
}
