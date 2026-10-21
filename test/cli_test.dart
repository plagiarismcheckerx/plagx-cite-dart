// Command line tests (same behaviour as `npx plagx-cite`).
import 'dart:convert';
import 'dart:io';

import 'package:plagx_cite/src/cli.dart';
import 'package:test/test.dart';

const bib = '''
@article{smith2020, author={Smith, John and Lee, Kate}, title={Deep learning for text similarity},
  journal={Journal of Academic Writing}, year=2020, volume=12, number=3, pages={45--67}}
@book{brown2018, author={Brown, Mary}, title={Writing research papers}, publisher={Academic Press}, year=2018}
@article{smithdup, author={Smith, J.}, title={Deep Learning for Text Similarity!}, journal={JAW}, year=2020}
@misc{bad, title={Untitled web page}, doi={not-a-doi}}
''';

Future<(int, String, String)> run(List<String> args,
    {String stdinText = ''}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(args,
      out: out, err: err, stdinStream: Stream.value(utf8.encode(stdinText)));
  return (code, out.toString(), err.toString());
}

void main() {
  late Directory dir;
  late String bibFile;
  late String cleanFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('plagx_cite_cli');
    bibFile = '${dir.path}/refs.bib';
    File(bibFile).writeAsStringSync(bib);
    cleanFile = '${dir.path}/clean.json';
    File(cleanFile).writeAsStringSync(jsonEncode([
      {
        'type': 'book',
        'title': 'T',
        'author': [
          {'family': 'A', 'given': 'B'},
        ],
        'year': 2001,
      },
    ]));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('format', () async {
    expect(await run(['format', cleanFile]), (0, 'A, B. (2001). T.\n', ''));
    final (_, out, _) = await run(['format', bibFile, '--style', 'mla']);
    expect(out.split('\n')[0],
        startsWith('Brown, Mary. Writing research papers.'));
  });

  test('format from stdin', () async {
    final (code, out, _) = await run(['format', '-'], stdinText: bib);
    expect(code, 0);
    expect(out, startsWith('Brown, M. (2018).'));
  });

  test('check', () async {
    final (code, out, _) = await run(['check', bibFile]);
    expect(code, 1);
    expect(out, contains('4 reference(s), 2 error(s), 2 warning(s)'));
    expect(out, contains('error   smithdup: Possible duplicate (title match)'));
    expect(out, contains('error   bad: Invalid DOI "not-a-doi"'));
    expect((await run(['check', cleanFile])).$1, 0);
  });

  test('check --json and --strict', () async {
    final report =
        (jsonDecode((await run(['check', bibFile, '--json'])).$2) as List)
            .single as Map;
    expect((report['issues'] as List).map((x) => x['code']),
        ['duplicate', 'invalid-doi', 'missing-author', 'missing-year']);
    final warn = '${dir.path}/warn.json';
    File(warn).writeAsStringSync(jsonEncode([
      {'title': 'No author here', 'year': 2020},
    ]));
    expect((await run(['check', warn])).$1, 0);
    expect((await run(['check', warn, '--strict'])).$1, 1);
  });

  test('bibtex', () async {
    final (code, out, _) = await run(['bibtex', cleanFile]);
    expect(code, 0);
    expect(out, startsWith('@book{a2001,'));
  });

  test('usage errors', () async {
    expect((await run([])).$1, 2);
    expect((await run(['format'])).$1, 2);
    expect((await run(['format', '${dir.path}/missing.bib'])).$1, 2);
    expect((await run(['format', cleanFile, '--style', 'chicago'])).$1, 2);
    expect((await run(['format', cleanFile, '--format', 'pdf'])).$1, 2);
    expect((await run(['nope'])).$1, 2);
    final (code, out, _) = await run(['--version']);
    expect(code, 0);
    expect(out.trim(), '0.2.1');
  });
}
