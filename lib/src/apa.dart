// APA 7th edition (common reference types).
import 'formatter.dart';
import 'names.dart';
import 'util.dart';

const _journalTypes = [
  'article-journal',
  'article-magazine',
  'article-newspaper',
  'article'
];
const _containerTypes = [
  'chapter',
  'paper-conference',
  'entry-encyclopedia',
  'entry-dictionary'
];
const _datedTypes = [
  'webpage',
  'article-newspaper',
  'article-magazine',
  'post',
  'post-weblog'
];

String _authorName(Object? name) {
  final n = nameParts(name);
  if (n.literal != null) return n.literal!;
  var s = n.family;
  if (n.given.isNotEmpty) s += ', ${initials(n.given)}';
  if (n.suffix != null) s += ', ${n.suffix}';
  return s;
}

String _authorList(List<dynamic> list) {
  final names = list.map(_authorName).toList();
  if (names.length == 1) return names[0];
  if (names.length <= 20) {
    return '${names.sublist(0, names.length - 1).join(', ')}, & ${names.last}';
  }
  return '${names.sublist(0, 19).join(', ')}, . . . ${names.last}';
}

String _editorList(List<dynamic> list) {
  final names = list.map((name) {
    final n = nameParts(name);
    if (n.literal != null) return n.literal!;
    return n.given.isNotEmpty ? '${initials(n.given)} ${n.family}' : n.family;
  }).toList();
  final String s;
  if (names.length == 1) {
    s = names[0];
  } else if (names.length == 2) {
    s = names.join(' & ');
  } else {
    s = '${names.sublist(0, names.length - 1).join(', ')}, & ${names.last}';
  }
  return '$s (${names.length > 1 ? 'Eds.' : 'Ed.'})';
}

String _dateText(Ref ref) {
  final d = getDate(ref);
  if (d.year == null || d.year == 0) return 'n.d.';
  var s = '${d.year}';
  if (_datedTypes.contains(text(ref, 'type')) &&
      d.month != null &&
      d.month != 0) {
    s += ', ${months[d.month! - 1]}';
    if (d.day != null && d.day != 0) s += ' ${d.day}';
  }
  return s;
}

String _titleText(Ref ref, Formatter f) {
  final title = text(ref, 'title');
  if (title.isEmpty) return '';
  final type = text(ref, 'type');
  final italic =
      !_journalTypes.contains(type) && !_containerTypes.contains(type);
  final s = italic ? f.i(title) : f.t(title);
  var note = '';
  if (filled(ref['edition'])) note = ' (${ordinal(ref['edition'])} ed.)';
  if (type == 'thesis') {
    final publisher =
        filled(ref['publisher']) ? ', ${str(ref['publisher'])}' : '';
    note =
        ' [${filled(ref['genre']) ? str(ref['genre']) : 'Thesis'}$publisher]';
  }
  if (note.isNotEmpty) return s + f.t('$note.');
  return s + f.t(dot(title));
}

String _sourceText(Ref ref, Formatter f, String authors) {
  final type = text(ref, 'type');
  final container = text(ref, 'container-title');
  final publisher = text(ref, 'publisher');

  if (_journalTypes.contains(type)) {
    // Preprints and similar have no journal; name the repository instead (e.g. arXiv).
    if (container.isEmpty) {
      return publisher.isNotEmpty && publisher != authors
          ? f.t(publisher + dot(publisher))
          : '';
    }
    var s = f.i(container);
    if (filled(ref['volume'])) s += f.t(', ') + f.i(str(ref['volume']));
    if (filled(ref['issue'])) s += f.t('(${str(ref['issue'])})');
    if (filled(ref['page'])) s += f.t(', ${pageRange(ref['page'])}');
    return s + f.t('.');
  }

  if (_containerTypes.contains(type)) {
    var s = f.t('In ');
    if (filled(ref['editor'])) {
      s += f.t('${_editorList(list(ref['editor']))}, ');
    }
    if (container.isNotEmpty) s += f.i(container);
    if (filled(ref['page'])) {
      s += f.t(
          ' (${isPageRange(ref['page']) ? 'pp.' : 'p.'} ${pageRange(ref['page'])})');
    }
    s += f.t('.');
    if (publisher.isNotEmpty) s += f.t(' $publisher${dot(publisher)}');
    return s;
  }

  if (type == 'thesis') return '';

  // Webpage: site name; book, report and others: publisher. Omitted when it repeats the author.
  final source = type == 'webpage' ? container : publisher;
  if (source.isEmpty || source == authors) return '';
  return f.t(source + dot(source));
}

String reference(Ref ref, Formatter f) {
  final authors = filled(ref['author']) ? _authorList(list(ref['author'])) : '';
  final date = f.t('(${_dateText(ref)}).');
  final title = _titleText(ref, f);
  final parts = authors.isNotEmpty
      ? [f.t(authors + dot(authors)), date, title]
      : [title, date];
  parts.addAll([_sourceText(ref, f, authors), f.t(link(ref))]);
  return parts.where((p) => p.isNotEmpty).join(' ');
}

String inText(Ref ref, {String? page, bool narrative = false}) {
  final names = list(ref['author']).map(familyName).toList();
  final conj = narrative ? 'and' : '&';

  var detail = getYear(ref) ?? 'n.d.';
  if (filled(page)) {
    detail += ', ${isPageRange(page) ? 'pp.' : 'p.'} ${pageRange(page)}';
  }

  // No author: the title stands in, and APA puts the comma inside the quotation marks.
  if (names.isEmpty) {
    final title = filled(ref['title']) ? str(ref['title']) : 'Untitled';
    return narrative ? '“$title” ($detail)' : '(“$title,” $detail)';
  }

  final String who;
  if (names.length == 1) {
    who = names[0];
  } else if (names.length == 2) {
    who = '${names[0]} $conj ${names[1]}';
  } else {
    who = '${names[0]} et al.';
  }
  return narrative ? '$who ($detail)' : '($who, $detail)';
}
