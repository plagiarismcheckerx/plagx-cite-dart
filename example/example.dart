import 'package:plagx_cite/plagx_cite.dart';

Future<void> main() async {
  final refs = parseBibTeX('''
@article{smith2020, author={Smith, John Allen and Lee, Kate}, title={Deep learning for text similarity},
  journal={Journal of Academic Writing}, year=2020, volume=12, number=3, pages={45--67}, doi={10.1234/jaw.2020.045}}
@book{brown2018, author={Brown, Mary}, title={Writing research papers}, publisher={Academic Press}, year=2018, edition=2}
''');

  // APA 7 reference list and in-text citation.
  formatBibliography(refs).forEach(print);
  print(citeInText(refs[0], page: '50'));

  // MLA 9 works cited.
  formatBibliography(refs, style: 'mla').forEach(print);

  // Duplicates, invalid DOIs and missing fields.
  final result = await checkReferences(refs);
  print('${result['errors']} error(s), ${result['warnings']} warning(s)');

  // Look up a DOI online (Crossref, then doi.org).
  final ref = await lookupDoi('10.1038/nature14539');
  print(formatReference(ref));
}
