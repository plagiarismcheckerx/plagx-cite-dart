// Checks a reference list for problems.
import 'package:http/http.dart' as http;

import 'doi.dart';
import 'duplicates.dart';
import 'util.dart';

String _label(Ref ref, int i) =>
    filled(ref['id']) ? str(ref['id']) : '#${i + 1}';

/// Checks a reference list.
///
/// Errors: duplicate references, invalid DOIs, DOIs not found (with [checkDois]).
/// Warnings: missing title, author or year.
///
/// Returns `{"references", "errors", "warnings", "issues": [{"level", "code", "index", "ref", "message"}]}`.
Future<Map<String, dynamic>> checkReferences(List<Map<String, dynamic>> refs,
    {bool checkDois = false, String? mailto, http.Client? client}) async {
  final issues = <Map<String, dynamic>>[];
  void add(String level, String code, int index, String message) => issues.add({
        'level': level,
        'code': code,
        'index': index,
        'ref': _label(refs[index], index),
        'message': message
      });

  for (final group in findDuplicates(refs)) {
    final indexes = group['indexes'] as List<int>;
    final names = [for (final i in indexes) _label(refs[i], i)];
    for (final i in indexes.skip(1)) {
      add('error', 'duplicate', i,
          'Possible duplicate (${(group['reasons'] as List).join(' and ')} match) of ${names[0]}: ${names.join(', ')}');
    }
  }

  for (var i = 0; i < refs.length; i++) {
    final ref = refs[i];
    if (!filled(ref['title'])) add('warning', 'missing-title', i, 'No title');
    if (!filled(ref['author']) && !filled(ref['editor'])) {
      add('warning', 'missing-author', i, 'No author or editor');
    }
    if (getYear(ref) == null) {
      add('warning', 'missing-year', i, 'No year (will show as n.d.)');
    }
    if (filled(ref['DOI']) && normalizeDoi(str(ref['DOI'])) == null) {
      add('error', 'invalid-doi', i, 'Invalid DOI "${str(ref['DOI'])}"');
    }
  }

  if (checkDois) {
    for (var i = 0; i < refs.length; i++) {
      final doi =
          filled(refs[i]['DOI']) ? normalizeDoi(str(refs[i]['DOI'])) : null;
      if (doi == null) continue;
      try {
        await lookupDoi(doi, mailto: mailto, client: client);
      } on FormatException catch (e) {
        add('error', 'doi-not-found', i, e.message);
      } catch (e) {
        add('error', 'doi-not-found', i, '$e');
      }
    }
  }

  // List.sort is not stable; the position keeps equal issues in the order they were found.
  final order = {for (var k = 0; k < issues.length; k++) issues[k]: k};
  issues.sort((a, b) {
    final c = (a['index'] as int).compareTo(b['index'] as int);
    if (c != 0) return c;
    final l = (a['level'] == 'error' ? 0 : 1)
        .compareTo(b['level'] == 'error' ? 0 : 1);
    return l != 0 ? l : order[a]!.compareTo(order[b]!);
  });
  final errors = issues.where((x) => x['level'] == 'error').length;
  return {
    'references': refs.length,
    'errors': errors,
    'warnings': issues.length - errors,
    'issues': issues
  };
}
