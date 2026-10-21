// BibTeX export and BibTeX/BibLaTeX import.
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'names.dart';
import 'util.dart';

const _toBibTeXType = {
  'article-journal': 'article',
  'article-magazine': 'article',
  'article-newspaper': 'article',
  'article': 'article',
  'book': 'book',
  'chapter': 'incollection',
  'paper-conference': 'inproceedings',
  'report': 'techreport',
  'thesis': 'phdthesis',
};

const _fromBibTeXType = {
  'article': 'article-journal',
  'book': 'book',
  'inbook': 'chapter',
  'incollection': 'chapter',
  'inproceedings': 'paper-conference',
  'conference': 'paper-conference',
  'techreport': 'report',
  'report': 'report',
  'phdthesis': 'thesis',
  'mastersthesis': 'thesis',
  'thesis': 'thesis',
  'online': 'webpage',
};

const _monthNames = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec'
];

const _accents = {
  '"': '\u0308',
  "'": '\u0301',
  '`': '\u0300',
  '^': '\u0302',
  '~': '\u0303',
  '=': '\u0304',
  '.': '\u0307',
  'c': '\u0327',
  'v': '\u030C',
  'u': '\u0306',
  'H': '\u030B',
};

// ------------------------------------------------------------------ export

final _special = RegExp(r'[\\&%$#_{}]');
final _dashes = RegExp(r'\s*[-\u2013\u2014]+\s*');
final _keyChars = RegExp(r'^[A-Za-z0-9_:.-]+$');

String _escapeValue(String value) => value.replaceAllMapped(
    _special, (m) => m[0] == r'\' ? r'\textbackslash{}' : '\\${m[0]}');

String _bibName(Object? name) {
  final n = nameParts(name);
  if (n.literal != null) return '{${n.literal}}';
  return [n.family, n.suffix, n.given]
      .where((p) => p != null && p.isNotEmpty)
      .join(', ');
}

String _baseKey(Ref ref) {
  final lead =
      filled(ref['author']) ? familyName(list(ref['author'])[0]) : 'anon';
  final word = normalizeText(text(ref, 'title')).split(' ').firstWhere(
      (w) =>
          w.length > 3 && !const ['with', 'from', 'that', 'this'].contains(w),
      orElse: () => '');
  final year = getDate(ref).year;
  final key =
      '${normalizeText(lead).replaceAll(' ', '')}${year == null || year == 0 ? '' : year}$word';
  return key.isEmpty ? 'ref' : key;
}

String? _value(Object? value) => filled(value) ? str(value) : null;

String _entry(Ref ref, String key) {
  final type = _toBibTeXType[text(ref, 'type')] ?? 'misc';
  final container = ref['container-title'];
  final d = getDate(ref);
  String names(String field) => list(ref[field]).map(_bibName).join(' and ');

  final publisherField = type == 'phdthesis'
      ? 'school'
      : type == 'techreport'
          ? 'institution'
          : 'publisher';
  final fields = <(String, String?)>[
    ('author', filled(ref['author']) ? names('author') : null),
    ('editor', filled(ref['editor']) ? names('editor') : null),
    ('title', _value(ref['title'])),
    (
      type == 'article' ? 'journal' : 'booktitle',
      const ['article', 'incollection', 'inproceedings'].contains(type)
          ? _value(container)
          : null
    ),
    ('howpublished', type == 'misc' ? _value(container) : null),
    ('year', d.year == null || d.year == 0 ? null : '${d.year}'),
    (
      'month',
      d.month == null || d.month == 0 ? null : _monthNames[d.month! - 1]
    ),
    ('volume', _value(ref['volume'])),
    ('number', _value(ref['issue'])),
    (
      'pages',
      filled(ref['page']) ? str(ref['page']).replaceAll(_dashes, '--') : null
    ),
    ('edition', _value(ref['edition'])),
    (publisherField, _value(ref['publisher'])),
    ('address', _value(ref['publisher-place'])),
    ('isbn', _value(ref['ISBN'])),
    ('doi', _value(ref['DOI'])),
    ('url', _value(ref['URL'])),
  ];
  final body = [
    for (final (name, value) in fields)
      if (value != null && value.isNotEmpty)
        '  $name = {${const [
          'author',
          'editor',
          'url',
          'doi',
          'month'
        ].contains(name) ? value : _escapeValue(value)}}',
  ];
  return '@$type{$key,\n${body.join(',\n')}\n}';
}

/// Converts a list of CSL-JSON references (or a single reference map) to BibTeX.
String toBibTeX(Object refs) {
  final items = refs is List
      ? refs.cast<Map<String, dynamic>>()
      : [refs as Map<String, dynamic>];
  final used = <String>{};
  final out = <String>[];
  for (final ref in items) {
    final id = text(ref, 'id');
    var key = id.isNotEmpty && _keyChars.hasMatch(id) ? id : _baseKey(ref);
    if (used.contains(key)) {
      var n = 0;
      while (used.contains(key + String.fromCharCode(97 + n))) {
        n++;
      }
      key += String.fromCharCode(97 + n);
    }
    used.add(key);
    out.add(_entry(ref, key));
  }
  return out.join('\n\n');
}

// ------------------------------------------------------------------ import

final _accentShort = RegExp(r'''\\([`'^"~=.])\s*\{?\\?([A-Za-z])\}?''');
final _accentLetter = RegExp(r'\\([cvuH])\s*\{\\?([A-Za-z])\}');
final _command = RegExp(r'\\(?:emph|textit|textbf|textsc|mathrm)\{([^{}]*)\}');
final _escaped = RegExp(r'\\([&%$#_{}])');
final _braces = RegExp(r'(?<!\\)[{}]');
final _spaces = RegExp(r'\s+');

/// Converts common LaTeX markup to plain Unicode text.
String _cleanLatex(String value) {
  var s = value.replaceAllMapped(_accentShort, (m) => m[2]! + _accents[m[1]]!);
  s = s.replaceAllMapped(_accentLetter, (m) => m[2]! + _accents[m[1]]!);
  s = s.replaceAll(r'\textbackslash{}', r'\');
  s = s.replaceAllMapped(_command, (m) => m[1]!);
  s = s.replaceAllMapped(_escaped, (m) => m[1]!);
  s = s.replaceAll(_braces, '').replaceAll('~', ' ').replaceAll(_spaces, ' ');
  return unorm.nfc(s).trim();
}

final _and = RegExp(r'\s+and\s+', caseSensitive: false);
final _comma = RegExp(',');

List<String> _splitTopLevel(String value, RegExp separator) {
  final parts = <String>[];
  var depth = 0;
  final current = StringBuffer();
  var i = 0;
  while (i < value.length) {
    final c = value[i];
    if (c == '{') depth++;
    if (c == '}') depth--;
    final m = depth == 0 ? separator.matchAsPrefix(value, i) : null;
    if (m != null) {
      parts.add(current.toString());
      current.clear();
      i = m.end;
      continue;
    }
    current.write(c);
    i++;
  }
  parts.add(current.toString());
  return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}

final _bracedName = RegExp(r'^\{[^{}]*\}$');

List<Map<String, dynamic>> _parseNames(String value) =>
    _splitTopLevel(value, _and).map((raw) {
      if (_bracedName.hasMatch(raw)) {
        return <String, dynamic>{
          'literal': _cleanLatex(raw.substring(1, raw.length - 1))
        };
      }
      final parts = _splitTopLevel(raw, _comma).map(_cleanLatex).toList();
      if (parts.length == 3) {
        return <String, dynamic>{
          'family': parts[0],
          'suffix': parts[1],
          'given': parts[2]
        };
      }
      if (parts.length == 2) {
        return <String, dynamic>{'family': parts[0], 'given': parts[1]};
      }
      final n = nameParts(_cleanLatex(raw));
      return <String, dynamic>{'family': n.family, 'given': n.given};
    }).toList();

int _findClose(String src, int start, String open, String close) {
  var depth = 0;
  for (var i = start; i < src.length; i++) {
    if (src[i] == open) {
      depth++;
    } else if (src[i] == close) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

final _space = RegExp(r'\s');
final _fieldName = RegExp(r'[^\s=,{}]+');
final _token = RegExp(r'[^\s,#}]+');

Map<String, String> _parseFields(String body, Map<String, String> macros) {
  final fields = <String, String>{};
  final n = body.length;
  var i = 0;
  int skipSpace(int k) {
    while (k < n && _space.hasMatch(body[k])) {
      k++;
    }
    return k;
  }

  while (i < n) {
    while (i < n && (body[i] == ',' || _space.hasMatch(body[i]))) {
      i++;
    }
    final name = _fieldName.matchAsPrefix(body, i);
    if (name == null) break;
    i = skipSpace(name.end);
    if (i >= n || body[i] != '=') break;
    i++;

    final value = StringBuffer();
    while (true) {
      i = skipSpace(i);
      if (i < n && body[i] == '{') {
        final end = _findClose(body, i, '{', '}');
        if (end < 0) return fields;
        value.write(body.substring(i + 1, end));
        i = end + 1;
      } else if (i < n && body[i] == '"') {
        var depth = 0;
        var j = i + 1;
        for (; j < n; j++) {
          if (body[j] == '{') {
            depth++;
          } else if (body[j] == '}') {
            depth--;
          } else if (body[j] == '"' && depth == 0 && body[j - 1] != r'\') {
            break;
          }
        }
        value.write(body.substring(i + 1, j < n ? j : n));
        i = j + 1;
      } else {
        final token = i < n ? _token.matchAsPrefix(body, i) : null;
        if (token == null) break;
        value.write(macros[token[0]!.toLowerCase()] ?? token[0]);
        i = token.end;
      }
      i = skipSpace(i);
      if (i >= n || body[i] != '#') break;
      i++;
    }
    fields[name[0]!.toLowerCase()] = value.toString();
  }
  return fields;
}

final _isoDate = RegExp(r'^([0-9]{4})(?:-([0-9]{1,2}))?(?:-([0-9]{1,2}))?');
final _year = RegExp(r'[0-9]{4}');
final _hyphens = RegExp(r'\s*-+\s*');
final _doiUrl = RegExp(r'^https?://(dx\.)?doi\.org/', caseSensitive: false);

Map<String, dynamic> _toCsl(
    String type, String key, Map<String, String> fields) {
  String? field(String name) =>
      (fields[name]?.isNotEmpty ?? false) ? fields[name] : null;
  String? clean(String name) =>
      field(name) == null ? null : _cleanLatex(field(name)!);
  String? first(List<String?> values) =>
      values.firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);

  final ref = <String, dynamic>{
    'id': key,
    'type': _fromBibTeXType[type] ??
        (field('url') != null ? 'webpage' : 'document'),
  };

  if (field('author') != null) ref['author'] = _parseNames(field('author')!);
  if (field('editor') != null) ref['editor'] = _parseNames(field('editor')!);
  if (field('title') != null) ref['title'] = clean('title');
  final container = first([
    clean('journal'),
    clean('journaltitle'),
    clean('booktitle'),
    clean('howpublished')
  ]);
  if (container != null) ref['container-title'] = container;

  final date = _isoDate.firstMatch(field('date') ?? '');
  final year =
      date != null ? date[1] : _year.firstMatch(field('year') ?? '')?[0];
  if (year != null) {
    final month = first([date?[2], field('month')]);
    var monthNumber = 0;
    if (month != null && RegExp(r'^[0-9]+$').hasMatch(month)) {
      monthNumber = int.parse(month);
    } else if (month != null) {
      final key3 = month.trim().toLowerCase();
      monthNumber =
          _monthNames.indexOf(key3.length > 3 ? key3.substring(0, 3) : key3) +
              1;
    }
    ref['issued'] = {
      'date-parts': [
        [
          int.parse(year),
          if (monthNumber > 0) monthNumber,
          if (date?[3] != null) int.parse(date![3]!)
        ],
      ],
    };
  }

  if (field('volume') != null) ref['volume'] = clean('volume');
  if (field('number') != null) ref['issue'] = clean('number');
  if (field('pages') != null) {
    ref['page'] = (clean('pages') ?? '').replaceAll(_hyphens, '-');
  }
  if (field('edition') != null) ref['edition'] = clean('edition');
  final publisher = first([
    clean('publisher'),
    clean('school'),
    clean('institution'),
    clean('organization')
  ]);
  if (publisher != null) ref['publisher'] = publisher;
  if (field('address') != null || field('location') != null) {
    ref['publisher-place'] = first([clean('address'), clean('location')]);
  }
  if (field('isbn') != null) ref['ISBN'] = clean('isbn');
  if (field('doi') != null) {
    ref['DOI'] = field('doi')!.trim().replaceFirst(_doiUrl, '');
  }
  if (field('url') != null) ref['URL'] = field('url')!.trim();
  if (type == 'phdthesis') ref['genre'] = 'Doctoral dissertation';
  if (type == 'mastersthesis') ref['genre'] = 'Master\u2019s thesis';
  return ref;
}

final _head = RegExp(r'@\s*([A-Za-z]+)\s*([{(])');

/// Parses BibTeX/BibLaTeX text into a list of CSL-JSON references.
List<Map<String, dynamic>> parseBibTeX(String source) {
  final macros = {
    for (var i = 0; i < _monthNames.length; i++) _monthNames[i]: '${i + 1}'
  };
  final refs = <Map<String, dynamic>>[];
  var i = 0;
  while (true) {
    final at = source.indexOf('@', i);
    if (at < 0) break;
    final head = _head.matchAsPrefix(source, at);
    if (head == null) {
      i = at + 1;
      continue;
    }
    final type = head[1]!.toLowerCase();
    final openIndex = head.end - 1;
    final open = head[2]!;
    final end = _findClose(source, openIndex, open, open == '{' ? '}' : ')');
    if (end < 0) break;
    final body = source.substring(openIndex + 1, end);
    i = end + 1;

    if (type == 'comment' || type == 'preamble') continue;
    if (type == 'string') {
      macros.addAll(_parseFields(body, macros));
      continue;
    }

    final comma = body.indexOf(',');
    final key = (comma < 0 ? body : body.substring(0, comma)).trim();
    final fields = comma < 0
        ? <String, String>{}
        : _parseFields(body.substring(comma + 1), macros);
    refs.add(_toCsl(type, key, fields));
  }
  return refs;
}
