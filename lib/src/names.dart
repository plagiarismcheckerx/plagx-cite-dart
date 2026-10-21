// Name parsing and initials.
import 'util.dart';

class Name {
  final String? literal;
  final String family;
  final String given;
  final String? suffix;
  const Name({this.literal, this.family = '', this.given = '', this.suffix});
}

/// Accepts a CSL name ({family, given, suffix} or {literal}) or a string
/// ("Smith, John" / "John Smith").
Name nameParts(Object? name) {
  if (name is String) return _parseNameString(name);
  if (name is! Map) return const Name();
  if (filled(name['literal'])) return Name(literal: str(name['literal']));
  return Name(
    family: filled(name['family']) ? str(name['family']) : '',
    given: filled(name['given']) ? str(name['given']) : '',
    suffix: filled(name['suffix']) ? str(name['suffix']) : null,
  );
}

Name _parseNameString(String value) {
  final s = value.trim();
  final comma = s.indexOf(',');
  if (comma >= 0) {
    return Name(
        family: s.substring(0, comma).trim(),
        given: s.substring(comma + 1).trim());
  }
  final parts = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length <= 1) return Name(family: s);
  return Name(
      family: parts.last, given: parts.sublist(0, parts.length - 1).join(' '));
}

final _dottedLetter = RegExp(r'\p{L}\.', unicode: true);

/// "John Ronald" -> "J. R.", "J.R.R." -> "J. R. R.", "Jean-Paul" -> "J.-P."
String initials(String given) =>
    given.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((part) {
      final dotted = _dottedLetter.allMatches(part).map((m) => m[0]!).toList();
      if (dotted.isNotEmpty && dotted.join() == part) {
        return dotted.map((d) => d.toUpperCase()).join(' ');
      }
      return part
          .split('-')
          .where((seg) => seg.isNotEmpty)
          .map((seg) => '${seg[0].toUpperCase()}.')
          .join('-');
    }).join(' ');

/// Family name (or literal) used for in-text citations and sorting.
String familyName(Object? name) {
  final n = nameParts(name);
  return n.literal ?? n.family;
}
