part of deact;

class _TreeLocation {
  final _TreeLocation? parent;
  final String token;
  final int? position;
  final Object? key;
  String? _cachedString;

  _TreeLocation(
    this.parent,
    this.token,
    this.position, {
    required this.key,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _TreeLocation &&
            runtimeType == other.runtimeType &&
            toString() == other.toString();
  }

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    if (_cachedString != null) return _cachedString!;
    final key = this.key != null ? '@${this.key}' : null;
    final position = this.position != null ? '#${this.position}' : '';
    final parent = this.parent?.toString() ?? '';
    _cachedString = '$parent[$token${key ?? position}]';
    return _cachedString!;
  }
}
