/// Plagx Cite: a free academic writing utility by Plagiarism Checker X.
/// APA 7 and MLA 9 citation generator and reference checker.
/// https://plagiarismcheckerx.com/ · MIT License
///
/// References are CSL-JSON maps, e.g. `jsonDecode` of a Zotero or Crossref export.
library;

export 'src/bibtex.dart' show parseBibTeX, toBibTeX;
export 'src/check.dart' show checkReferences;
export 'src/doi.dart'
    show
        DoiLookupException,
        extractDois,
        fromCrossref,
        isDoi,
        lookupDoi,
        normalizeDoi;
export 'src/duplicates.dart' show findDuplicates;
export 'src/format.dart'
    show
        citeInText,
        formatBibliography,
        formatReference,
        sortReferences,
        styles;
export 'src/version.dart' show packageVersion;
