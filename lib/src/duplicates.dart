// Duplicate reference detection.
import 'doi.dart';
import 'names.dart';
import 'util.dart';

Map<String, String> _keysFor(Ref ref) {
  final keys = <String, String>{};
  final doi = filled(ref['DOI']) ? normalizeDoi(str(ref['DOI'])) : null;
  if (doi != null) keys['doi'] = doi.toLowerCase();
  final title = normalizeText(text(ref, 'title'));
  if (title.isNotEmpty) {
    final lead = filled(ref['author'])
        ? normalizeText(familyName(list(ref['author'])[0]))
        : '';
    keys['title'] = '$title|$lead';
  }
  return keys;
}

/// Finds references that appear more than once, matched by DOI or by
/// normalized title + first author.
///
/// Returns `[{"indexes": [0, 3], "reasons": ["doi", "title"]}, ...]`.
List<Map<String, dynamic>> findDuplicates(List<Map<String, dynamic>> refs) {
  final keys = refs.map(_keysFor).toList();
  final parent = List<int>.generate(refs.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  final firstSeen = <String, int>{};
  for (var i = 0; i < keys.length; i++) {
    for (final e in keys[i].entries) {
      final id = '${e.key}:${e.value}';
      if (firstSeen.containsKey(id)) {
        parent[find(i)] = find(firstSeen[id]!);
      } else {
        firstSeen[id] = i;
      }
    }
  }

  final groups = <int, List<int>>{};
  for (var i = 0; i < refs.length; i++) {
    groups.putIfAbsent(find(i), () => []).add(i);
  }

  return [
    for (final indexes in groups.values)
      if (indexes.length > 1)
        {
          'indexes': indexes,
          'reasons': [
            for (final reason in const ['doi', 'title'])
              if (indexes
                      .map((i) => keys[i][reason])
                      .whereType<String>()
                      .length >
                  indexes
                      .map((i) => keys[i][reason])
                      .whereType<String>()
                      .toSet()
                      .length)
                reason,
          ],
        },
  ];
}
