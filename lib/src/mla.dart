// MLA 9th edition (common reference types).
import 'formatter.dart';
import 'names.dart';
import 'util.dart';

const _quotedTypes = [
  'article-journal',
  'article-magazine',
  'article-newspaper',
  'article',
  'chapter',
  'paper-conference',
  'webpage',
  'entry-encyclopedia',
  'entry-dictionary',
  'post',
  'post-weblog',
];

String _natural(Name n) =>
    n.literal ?? [n.given, n.family].where((p) => p.isNotEmpty).join(' ');

String _authorList(List<dynamic> list) {
  final names = list.map(nameParts).toList();
  final first = names[0];
  var lead = first.literal ?? first.family;
  if (first.literal == null && first.given.isNotEmpty) {
    lead += ', ${first.given}';
  }
  if (first.literal == null && first.suffix != null) {
    lead += ', ${first.suffix}';
  }
  if (names.length == 1) return lead;
  if (names.length == 2) return '$lead, and ${_natural(names[1])}';
  return '$lead, et al.';
}

String _editorList(List<dynamic> list) {
  final names = list.map((n) => _natural(nameParts(n))).toList();
  if (names.length == 1) return names[0];
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  return '${names[0]} et al.';
}

String _dateText(Ref ref) {
  final d = getDate(ref);
  return [
    if (d.day != null && d.day != 0) '${d.day}',
    if (d.month != null && d.month != 0) monthsMla[d.month! - 1],
    if (d.year != null && d.year != 0) '${d.year}',
  ].join(' ');
}

String _pagesText(Object? page) =>
    '${isPageRange(page) ? 'pp.' : 'p.'} ${pageRange(page, '-')}';

String reference(Ref ref, Formatter f) {
  final type = text(ref, 'type');
  final parts = <String>[];

  if (filled(ref['author'])) {
    final authors = _authorList(list(ref['author']));
    parts.add(f.t(authors + dot(authors)));
  }

  final title = text(ref, 'title');
  if (title.isNotEmpty) {
    parts.add(_quotedTypes.contains(type)
        ? f.t('“$title${dot(title)}”')
        : f.i(title) + f.t(dot(title)));
  }

  // Container elements, separated by commas and closed with a period.
  final container = text(ref, 'container-title');
  final elements = <String>[];
  if (container.isNotEmpty) elements.add(f.i(container));
  if (filled(ref['editor'])) {
    elements.add(f.t('edited by ${_editorList(list(ref['editor']))}'));
  }
  if (filled(ref['edition'])) {
    elements.add(f.t('${ordinal(ref['edition'])} ed.'));
  }
  if (filled(ref['volume'])) elements.add(f.t('vol. ${str(ref['volume'])}'));
  if (filled(ref['issue'])) elements.add(f.t('no. ${str(ref['issue'])}'));
  // Articles name their journal, not the publisher, unless there is no journal (e.g. arXiv preprints).
  if (filled(ref['publisher']) &&
      (!type.startsWith('article') || container.isEmpty)) {
    elements.add(f.t(str(ref['publisher'])));
  }
  final date = _dateText(ref);
  if (date.isNotEmpty) elements.add(f.t(date));
  if (filled(ref['page'])) elements.add(f.t(_pagesText(ref['page'])));
  final url = link(ref);
  if (url.isNotEmpty) elements.add(f.t(url));

  if (elements.isNotEmpty) parts.add(elements.join(f.t(', ')) + f.t('.'));
  return parts.join(' ');
}

String inText(Ref ref, {String? page, bool narrative = false}) {
  final names = list(ref['author']).map(familyName).toList();
  final String who;
  if (names.isEmpty) {
    who = '“${filled(ref['title']) ? str(ref['title']) : 'Untitled'}”';
  } else if (names.length == 1) {
    who = names[0];
  } else if (names.length == 2) {
    who = '${names[0]} and ${names[1]}';
  } else {
    who = '${names[0]} et al.';
  }
  final pages = filled(page) ? pageRange(page, '-') : '';
  if (narrative) return pages.isNotEmpty ? '$who ($pages)' : who;
  return pages.isNotEmpty ? '($who $pages)' : '($who)';
}
