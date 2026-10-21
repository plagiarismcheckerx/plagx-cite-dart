import 'apa.dart' as apa;
import 'formatter.dart';
import 'mla.dart' as mla;
import 'names.dart';
import 'util.dart';

typedef _Reference = String Function(Ref ref, Formatter f);
typedef _InText = String Function(Ref ref, {String? page, bool narrative});

final Map<String, (_Reference, _InText)> _styles = {
  'apa': (apa.reference, apa.inText),
  'mla': (mla.reference, mla.inText),
};

/// Names of the built-in citation styles.
final List<String> styles = List.unmodifiable(_styles.keys);

(_Reference, _InText) _style(String name) =>
    _styles[name.toLowerCase()] ??
    (throw ArgumentError(
        'Unknown citation style "$name". Available: ${styles.join(', ')}.'));

/// Formats one CSL-JSON reference as a reference-list entry.
///
/// [style] is `"apa"` (default) or `"mla"`; [format] is `"text"` (default),
/// `"html"` (titles in `<i>`, text escaped) or `"markdown"` (titles in `*…*`).
String formatReference(Map<String, dynamic> ref,
        {String style = 'apa', String format = 'text'}) =>
    _style(style).$1(ref, Formatter(format));

/// Sorts references and formats each one.
List<String> formatBibliography(List<Map<String, dynamic>> refs,
        {String style = 'apa', String format = 'text'}) =>
    sortReferences(refs)
        .map((ref) => formatReference(ref, style: style, format: format))
        .toList();

/// In-text citation, e.g. "(Smith & Lee, 2020, p. 4)" or "Smith and Lee (2020)".
String citeInText(Map<String, dynamic> ref,
        {String style = 'apa', String? page, bool narrative = false}) =>
    _style(style).$2(ref, page: page, narrative: narrative);

final _article = RegExp(r'^(a|an|the)\s+', caseSensitive: false);

String _sortKey(Ref ref) {
  final lead = filled(ref['author'])
      ? familyName(list(ref['author'])[0])
      : text(ref, 'title').replaceFirst(_article, '');
  return '${normalizeText(lead)} ${getYear(ref) ?? '0000'} ${normalizeText(text(ref, 'title'))}';
}

/// Returns a new list sorted by first author (or title), year, then title.
List<Map<String, dynamic>> sortReferences(List<Map<String, dynamic>> refs) {
  // List.sort is not stable; the index keeps equal keys in their original order.
  final keyed = [
    for (var i = 0; i < refs.length; i++)
      (key: _sortKey(refs[i]), index: i, ref: refs[i])
  ];
  keyed.sort((a, b) {
    final c = a.key.compareTo(b.key);
    return c != 0 ? c : a.index.compareTo(b.index);
  });
  return [for (final k in keyed) k.ref];
}
