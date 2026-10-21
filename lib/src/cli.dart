// Plagx Cite command line. A free academic writing utility by Plagiarism Checker X.
import 'dart:convert';
import 'dart:io';

import '../plagx_cite.dart';

const _help =
    '''Plagx Cite $packageVersion: format and check references (APA 7 / MLA 9, BibTeX, DOI)

Usage:
  plagx-cite format <file>      Print a formatted reference list
  plagx-cite check <file>       Check for duplicates, invalid DOIs and missing fields
  plagx-cite doi <doi> [...]    Look up DOIs and print formatted references
  plagx-cite bibtex <file>      Convert a reference file to BibTeX

<file> is a .bib (BibTeX) or .json (CSL-JSON) file. Use - to read from stdin.

Options:
  --style apa|mla               Citation style (default: apa)
  --format text|html|markdown   Output format (default: text)
  --check-dois                  check: look up every DOI online
  --strict                      check: treat warnings as errors
  --json                        check: print the result as JSON
  --mailto <email>              Email for the Crossref polite pool (optional)
  -v, --version                 Show version
  -h, --help                    Show this help

Exit codes: 0 = OK, 1 = problems found (check), 2 = usage or input error.

A free academic writing utility by Plagiarism Checker X. It does not check for
plagiarism or AI-generated text: https://plagiarismcheckerx.com/''';

class _UsageError implements Exception {
  final String message;
  _UsageError(this.message);
}

class _Options {
  String style = 'apa';
  String format = 'text';
  String? mailto;
  bool checkDois = false;
  bool strict = false;
  bool json = false;
  bool help = false;
  bool version = false;
}

(_Options, List<String>) _parseArgs(List<String> argv) {
  final opts = _Options();
  final args = <String>[];
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    String value() {
      if (i + 1 >= argv.length) throw _UsageError('$a needs a value');
      return argv[++i];
    }

    if (a == '--style') {
      opts.style = value();
    } else if (a == '--format') {
      opts.format = value();
    } else if (a == '--mailto') {
      opts.mailto = value();
    } else if (a.startsWith('--style=')) {
      opts.style = a.substring(8);
    } else if (a.startsWith('--format=')) {
      opts.format = a.substring(9);
    } else if (a == '--check-dois') {
      opts.checkDois = true;
    } else if (a == '--strict') {
      opts.strict = true;
    } else if (a == '--json') {
      opts.json = true;
    } else if (a == '-h' || a == '--help') {
      opts.help = true;
    } else if (a == '-v' || a == '--version') {
      opts.version = true;
    } else if (a.startsWith('-') && a != '-') {
      throw _UsageError('Unknown option $a');
    } else {
      args.add(a);
    }
  }
  if (!styles.contains(opts.style)) {
    throw _UsageError(
        'Unknown style "${opts.style}". Use: ${styles.join(', ')}');
  }
  return (opts, args);
}

Future<List<Map<String, dynamic>>> _loadReferences(
    String path, Stream<List<int>> stdinStream) async {
  String text;
  try {
    text = path == '-'
        ? await utf8.decoder.bind(stdinStream).join()
        : await File(path).readAsString();
  } on PathNotFoundException {
    throw _UsageError('Cannot read $path: file not found');
  } on FileSystemException catch (e) {
    throw _UsageError('Cannot read $path: ${e.message}');
  }
  final trimmed = text.trimLeft();
  final looksJson = path.toLowerCase().endsWith('.json') ||
      (path == '-' && (trimmed.startsWith('[') || trimmed.startsWith('{')));
  if (!looksJson) return parseBibTeX(text);
  Object? data;
  try {
    data = jsonDecode(text);
  } on FormatException catch (e) {
    throw _UsageError('$path is not valid JSON: ${e.message}');
  }
  final refs = data is List
      ? data
      : (data is Map ? (data['items'] ?? data['references']) : null);
  if (refs is! List) {
    throw _UsageError('$path must contain a CSL-JSON array of references');
  }
  return [
    for (final r in refs)
      if (r is Map) Map<String, dynamic>.from(r)
  ];
}

String _printCheck(String file, Map<String, dynamic> result) => [
      '$file: ${result['references']} reference(s), ${result['errors']} error(s), ${result['warnings']} warning(s)',
      for (final x in result['issues'] as List)
        '  ${(x['level'] as String).padRight(7)} ${x['ref']}: ${x['message']}',
    ].join('\n');

/// Runs the command line and returns the exit code. [out], [err] and [stdinStream] default to the real ones.
Future<int> runCli(List<String> argv,
    {StringSink? out, StringSink? err, Stream<List<int>>? stdinStream}) async {
  out ??= stdout;
  err ??= stderr;
  void usage(String message) =>
      err!.write('$message\n\nRun plagx-cite --help for usage.\n');

  final _Options opts;
  final List<String> args;
  try {
    (opts, args) = _parseArgs(argv);
  } on _UsageError catch (e) {
    usage(e.message);
    return 2;
  }
  if (opts.version) {
    out.write('$packageVersion\n');
    return 0;
  }
  if (opts.help || args.isEmpty) {
    out.write('$_help\n');
    return opts.help ? 0 : 2;
  }

  final command = args[0];
  final rest = args.sublist(1);
  try {
    if (const ['format', 'bibtex', 'check'].contains(command)) {
      if (rest.isEmpty) {
        throw _UsageError(
            '$command needs a file (.bib or .json, or - for stdin)');
      }
      var failed = false;
      final reports = <Map<String, dynamic>>[];
      for (final file in rest) {
        final refs = await _loadReferences(file, stdinStream ?? stdin);
        if (command == 'format') {
          out.write(
              '${formatBibliography(refs, style: opts.style, format: opts.format).join('\n')}\n');
        } else if (command == 'bibtex') {
          out.write('${toBibTeX(sortReferences(refs))}\n');
        } else {
          final result = await checkReferences(refs,
              checkDois: opts.checkDois, mailto: opts.mailto);
          if (result['errors'] != 0 ||
              (opts.strict && result['warnings'] != 0)) {
            failed = true;
          }
          reports.add({'file': file, ...result});
        }
      }
      if (command == 'check') {
        out.write(opts.json
            ? '${const JsonEncoder.withIndent('  ').convert(reports)}\n'
            : '${reports.map((r) => _printCheck(r['file'] as String, r)).join('\n\n')}\n');
        return failed ? 1 : 0;
      }
      return 0;
    }

    if (command == 'doi') {
      if (rest.isEmpty) throw _UsageError('doi needs at least one DOI');
      var failed = false;
      for (final doi in rest) {
        try {
          final ref = await lookupDoi(doi, mailto: opts.mailto);
          out.write(
              '${formatReference(ref, style: opts.style, format: opts.format)}\n');
        } on FormatException catch (e) {
          err.write('${e.message}\n');
          failed = true;
        } on DoiLookupException catch (e) {
          err.write('${e.message}\n');
          failed = true;
        }
      }
      return failed ? 1 : 0;
    }

    throw _UsageError('Unknown command "$command"');
  } on _UsageError catch (e) {
    usage(e.message);
    return 2;
  } on ArgumentError catch (e) {
    usage('${e.message}'); // e.g. unknown --format
    return 2;
  }
}
