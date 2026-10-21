// Prints the same output as the JS/Python/PHP parity scripts (used to compare ports).
import 'dart:convert';
import 'dart:io';

import 'package:plagx_cite/plagx_cite.dart';

Future<void> main(List<String> args) async {
  final refs = [
    for (final r in jsonDecode(File(args[0]).readAsStringSync()) as List)
      Map<String, dynamic>.from(r as Map)
  ];
  final out = <String>[];
  for (final r in refs) {
    for (final style in ['apa', 'mla']) {
      for (final fmt in ['text', 'html', 'markdown']) {
        out.add(formatReference(r, style: style, format: fmt));
      }
      out.add(citeInText(r, style: style));
      out.add(citeInText(r, style: style, page: '12-15', narrative: true));
    }
  }
  out.addAll(formatBibliography(refs));
  out.add(toBibTeX(refs));
  out.add(jsonEncode(parseBibTeX(toBibTeX(refs))));
  out.add(jsonEncode(findDuplicates([...refs, refs[0], refs[2]])));
  out.add(jsonEncode(await checkReferences(refs)));
  stdout.add(utf8.encode('${out.join('\n')}\n'));
}
