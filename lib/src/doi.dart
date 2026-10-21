// DOI normalising, extraction and lookup (Crossref, with a doi.org fallback).
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'util.dart';

/// Thrown when a DOI lookup fails or the DOI can't be found.
class DoiLookupException implements Exception {
  /// Readable description, e.g. `DOI not found: 10.1234/x`.
  final String message;

  /// HTTP status returned by the server.
  final int statusCode;

  DoiLookupException(this.message, this.statusCode);

  @override
  String toString() => message;
}

final _pattern = RegExp(r'''10\.[0-9]{4,9}/[^\s"'<>]+''', caseSensitive: false);
final _prefix =
    RegExp(r'^(?:https?://(?:dx\.)?doi\.org/|doi:\s*)', caseSensitive: false);
final _bare = RegExp(r'^10\.[0-9]{4,9}/\S+$');
final _trailing = RegExp(r'[.,;:]+$');

const _crossrefTypes = {
  'journal-article': 'article-journal',
  'book': 'book',
  'monograph': 'book',
  'edited-book': 'book',
  'reference-book': 'book',
  'book-chapter': 'chapter',
  'book-section': 'chapter',
  'book-part': 'chapter',
  'reference-entry': 'entry-encyclopedia',
  'proceedings-article': 'paper-conference',
  'report': 'report',
  'dissertation': 'thesis',
  'posted-content': 'article',
  'dataset': 'dataset',
};

const _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' '
};

String _trimTrailing(String doi) {
  var s = doi.replaceAll(_trailing, '');
  // Drop a closing bracket that has no opening partner inside the DOI.
  while (s.endsWith(')') || s.endsWith(']')) {
    final close = s[s.length - 1];
    final open = close == ')' ? '(' : '[';
    if (open.allMatches(s).length >= close.allMatches(s).length) break;
    s = s.substring(0, s.length - 1).replaceAll(_trailing, '');
  }
  return s;
}

/// Returns a bare DOI ("10.xxxx/...") from a DOI, doi: string or doi.org URL, or null if invalid.
String? normalizeDoi(String? value) {
  var s = (value ?? '').trim().replaceFirst(_prefix, '');
  try {
    s = Uri.decodeComponent(s);
  } on ArgumentError {
    // Malformed percent-encoding: keep as is.
  }
  return _bare.hasMatch(s) ? _trimTrailing(s) : null;
}

/// True when the value is a valid DOI.
bool isDoi(String? value) => normalizeDoi(value) != null;

/// Finds every DOI in a block of text (unique, in order of appearance).
List<String> extractDois(String? text) {
  final found = <String, String>{};
  for (final m in _pattern.allMatches(text ?? '')) {
    final doi = _trimTrailing(m[0]!);
    found.putIfAbsent(doi.toLowerCase(), () => doi);
  }
  return found.values.toList();
}

final _tag = RegExp('<[^>]+>');
final _entity = RegExp(r'&(#x[0-9a-f]+|#[0-9]+|[a-z]+);', caseSensitive: false);
final _spaces = RegExp(r'\s+');

/// Metadata often contains HTML/JATS markup and entities; returns plain text.
String? _cleanText(Object? value) {
  if (value == null || value == '') return null;
  final s = str(value)
      .replaceAll(_tag, '')
      .replaceAllMapped(_entity, (m) {
        final e = m[1]!;
        if (e[0] != '#') return _entities[e.toLowerCase()] ?? m[0]!;
        try {
          return String.fromCharCode(e[1].toLowerCase() == 'x'
              ? int.parse(e.substring(2), radix: 16)
              : int.parse(e.substring(1)));
        } on Object {
          return m[0]!;
        }
      })
      .replaceAll(_spaces, ' ')
      .trim();
  return s.isEmpty ? null : s;
}

List<Map<String, dynamic>>? _cleanNames(Object? names) {
  if (names is! List || names.isEmpty) return null;
  return [
    for (final item in names)
      if (item is Map && filled(item['family']))
        {
          'family': _cleanText(item['family']),
          'given': _cleanText(item['given']) ?? ''
        }
      else
        {
          'literal': _cleanText(item is Map
                  ? (filled(item['name']) ? item['name'] : item['literal'])
                  : null) ??
              ''
        },
  ];
}

List<String> _texts(Object? value) => (value is List ? value : [value])
    .map(_cleanText)
    .whereType<String>()
    .toList();

String? _withSubtitle(String? title, String? subtitle) {
  if (title == null || title.isEmpty || subtitle == null || subtitle.isEmpty) {
    return title;
  }
  if (title.toLowerCase().contains(subtitle.toLowerCase())) return title;
  return RegExp(r'[:?!]$').hasMatch(title)
      ? '$title $subtitle'
      : '$title: $subtitle';
}

Map<String, dynamic>? _dateParts(Object? issued) {
  if (issued is! Map || issued['date-parts'] is! List) return null;
  final dp = issued['date-parts'] as List;
  if (dp.isEmpty || dp[0] is! List) return null;
  return {
    'date-parts': [
      [
        for (final n in dp[0] as List)
          if (n != null) n
      ],
    ],
  };
}

Map<String, dynamic> _compact(Map<String, dynamic> ref) => {
      for (final e in ref.entries)
        if (e.value != null && e.value != '') e.key: e.value
    };

String? _first(List<String> values) => values.isEmpty ? null : values.first;

/// Maps a Crossref "work" record to CSL-JSON.
Map<String, dynamic> fromCrossref(Map<String, dynamic> work) {
  final type = _crossrefTypes[text(work, 'type')] ?? 'article';
  Object? issued = work['issued'];
  final hasIssued = issued is Map &&
      issued['date-parts'] is List &&
      (issued['date-parts'] as List).isNotEmpty &&
      (issued['date-parts'] as List)[0] is List &&
      ((issued['date-parts'] as List)[0] as List).isNotEmpty &&
      filled(((issued['date-parts'] as List)[0] as List)[0]);
  if (!hasIssued) {
    issued = [
      work['published-print'],
      work['published-online'],
      work['created']
    ].firstWhere(filled, orElse: () => null);
  }
  // For chapters and proceedings Crossref may list [series, book]; the book is last.
  final containers = _texts(work['container-title']);
  final ref = <String, dynamic>{
    'id': work['DOI'],
    'type': type,
    'title': _withSubtitle(
        _first(_texts(work['title'])), _first(_texts(work['subtitle']))),
    'author': _cleanNames(work['author']),
    'editor': _cleanNames(work['editor']),
    'container-title': type == 'chapter' || type == 'paper-conference'
        ? (containers.isEmpty ? null : containers.last)
        : _first(containers),
    'issued': _dateParts(issued),
    'volume': work['volume'],
    'issue': work['issue'],
    'page': work['page'],
    'publisher': _cleanText(work['publisher']),
    'publisher-place': _cleanText(work['publisher-location']),
    'ISBN': _first(_texts(work['ISBN'])),
    'DOI': work['DOI'],
    'URL': work['URL'],
  };
  final institution = work['institution'];
  if (type == 'thesis' &&
      institution is List &&
      institution.isNotEmpty &&
      institution[0] is Map &&
      filled(institution[0]['name'])) {
    ref['publisher'] = _cleanText(institution[0]['name']);
  }
  return _compact(ref);
}

/// Keeps the CSL-JSON fields Plagx Cite uses from doi.org content negotiation (DataCite, arXiv, mEDRA…).
Map<String, dynamic> _fromCsl(Map<String, dynamic> data) => _compact({
      'id': data['DOI'],
      'type': filled(data['type']) ? data['type'] : 'article',
      'title': _first(_texts(data['title'])),
      'author': _cleanNames(data['author']),
      'editor': _cleanNames(data['editor']),
      'container-title': _first(_texts(data['container-title'])),
      'issued': _dateParts(data['issued']),
      'volume': data['volume'],
      'issue': data['issue'],
      'page': data['page'],
      'publisher': _cleanText(data['publisher']),
      'DOI': data['DOI'],
      'URL': data['URL'],
    });

/// Percent-encodes UTF-8 bytes except letters, digits and the given safe characters.
String _encode(String value, String safe) {
  final sb = StringBuffer();
  for (final b in utf8.encode(value)) {
    final c = String.fromCharCode(b);
    if (b < 128 && (RegExp('[A-Za-z0-9]').hasMatch(c) || safe.contains(c))) {
      sb.write(c);
    } else {
      sb.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return sb.toString();
}

// Browsers don't allow setting User-Agent; `identical(0, 0.0)` is true only on the web.
const _isWeb = identical(0, 0.0);

Future<(int, String)> _get(
    http.Client client, String url, String accept) async {
  final response = await client.get(Uri.parse(url), headers: {
    'Accept': accept,
    if (!_isWeb)
      'User-Agent':
          'plagx-cite-dart (+https://github.com/plagiarismcheckerx/plagx-cite-dart)',
  });
  return (
    response.statusCode,
    utf8.decode(response.bodyBytes, allowMalformed: true)
  );
}

bool _ok(int status) => status >= 200 && status < 300;

/// Looks up a DOI and returns CSL-JSON. Tries the public Crossref API first, then
/// doi.org content negotiation (covers DataCite DOIs such as arXiv and Zenodo).
///
/// [mailto] (optional) uses Crossref's polite pool. Pass [client] to use your own `http.Client`.
/// Throws [FormatException] for an invalid DOI and [DoiLookupException] when the DOI can't be found.
Future<Map<String, dynamic>> lookupDoi(String value,
    {String? mailto, http.Client? client}) async {
  final doi = normalizeDoi(value);
  if (doi == null) throw FormatException('Not a valid DOI: "$value"');
  final http.Client c = client ?? http.Client();
  try {
    var url = 'https://api.crossref.org/works/${_encode(doi, "-_.!~*'()")}';
    if (mailto != null && mailto.isNotEmpty) {
      url += '?mailto=${_encode(mailto, "-_.!~*'()")}';
    }
    var (status, body) = await _get(c, url, 'application/json');
    if (_ok(status)) {
      final data = jsonDecode(body);
      return fromCrossref(data is Map && data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : {});
    }
    if (status != 404) {
      throw DoiLookupException('DOI lookup failed ($status) for $doi', status);
    }

    (status, body) = await _get(
        c,
        'https://doi.org/${_encode(doi, ";,/?:@&=+\$-_.!~*'()#")}',
        'application/vnd.citationstyles.csl+json');
    if (status == 404) throw DoiLookupException('DOI not found: $doi', status);
    if (!_ok(status)) {
      throw DoiLookupException('DOI lookup failed ($status) for $doi', status);
    }
    final data = jsonDecode(body);
    return _fromCsl(data is Map ? Map<String, dynamic>.from(data) : {});
  } finally {
    if (client == null) c.close();
  }
}
