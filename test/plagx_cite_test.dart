// Same cases and expected output as the JavaScript package (plagx-cite on npm).
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plagx_cite/plagx_cite.dart';
import 'package:test/test.dart';

const article = {
  'type': 'article-journal',
  'title': 'Deep learning for text similarity',
  'author': [
    {'family': 'Smith', 'given': 'John Allen'},
    {'family': 'Lee', 'given': 'Kate'},
  ],
  'issued': {
    'date-parts': [
      [2020],
    ],
  },
  'container-title': 'Journal of Academic Writing',
  'volume': '12',
  'issue': '3',
  'page': '45-67',
  'DOI': '10.1234/jaw.2020.045',
};

const book = {
  'type': 'book',
  'title': 'Writing research papers',
  'author': [
    {'family': 'Brown', 'given': 'Mary'},
  ],
  'issued': {
    'date-parts': [
      [2018],
    ],
  },
  'publisher': 'Academic Press',
  'edition': '2',
};

const chapter = {
  'type': 'chapter',
  'title': 'Citing sources well',
  'author': [
    {'family': 'Khan', 'given': 'Ali'},
    {'family': 'Ng', 'given': 'Wei'},
    {'family': 'Ruiz', 'given': 'Ana'},
  ],
  'editor': [
    {'family': 'Green', 'given': 'Paul'},
    {'family': 'White', 'given': 'Sara Jane'},
  ],
  'container-title': 'Handbook of scholarly writing',
  'page': '101-120',
  'publisher': 'Routledge',
  'issued': {
    'date-parts': [
      [2019],
    ],
  },
};

const webpage = {
  'type': 'webpage',
  'title': 'How to avoid plagiarism',
  'author': [
    {'literal': 'Writing Centre'},
  ],
  'container-title': 'University Library',
  'issued': {
    'date-parts': [
      [2023, 3, 15],
    ],
  },
  'URL': 'https://example.com/post',
};

Map<String, dynamic> withField(
        Map<String, dynamic> ref, String key, Object? value) =>
    {...ref, key: value};

void main() {
  test('APA reference list entries', () {
    expect(formatReference(article),
        'Smith, J. A., & Lee, K. (2020). Deep learning for text similarity. Journal of Academic Writing, 12(3), 45–67. https://doi.org/10.1234/jaw.2020.045');
    expect(formatReference(book),
        'Brown, M. (2018). Writing research papers (2nd ed.). Academic Press.');
    expect(formatReference(chapter),
        'Khan, A., Ng, W., & Ruiz, A. (2019). Citing sources well. In P. Green & S. J. White (Eds.), Handbook of scholarly writing (pp. 101–120). Routledge.');
    expect(formatReference(webpage),
        'Writing Centre. (2023, March 15). How to avoid plagiarism. University Library. https://example.com/post');
  });

  test('APA without author or date', () {
    expect(
        formatReference({
          'type': 'webpage',
          'title': 'Citation basics',
          'URL': 'https://example.com'
        }),
        'Citation basics. (n.d.). https://example.com');
  });

  test('APA many authors use ellipsis', () {
    final out = formatReference({
      'type': 'article-journal',
      'title': 'T',
      'author': [
        for (var i = 1; i <= 22; i++) {'family': 'A$i', 'given': 'B'}
      ],
      'issued': {
        'date-parts': [
          [2021],
        ],
      },
    });
    expect(out,
        matches(RegExp(r'^A1, B\., .*A19, B\., \. \. \. A22, B\. \(2021\)')));
    expect(out, isNot(contains('A20')));
  });

  test('MLA works cited entries', () {
    expect(formatReference(article, style: 'mla'),
        'Smith, John Allen, and Kate Lee. “Deep learning for text similarity.” Journal of Academic Writing, vol. 12, no. 3, 2020, pp. 45-67, https://doi.org/10.1234/jaw.2020.045.');
    expect(formatReference(book, style: 'mla'),
        'Brown, Mary. Writing research papers. 2nd ed., Academic Press, 2018.');
    expect(formatReference(chapter, style: 'mla'),
        'Khan, Ali, et al. “Citing sources well.” Handbook of scholarly writing, edited by Paul Green and Sara Jane White, Routledge, 2019, pp. 101-120.');
    expect(formatReference(webpage, style: 'mla'),
        'Writing Centre. “How to avoid plagiarism.” University Library, 15 Mar. 2023, https://example.com/post.');
  });

  test('HTML and Markdown output', () {
    expect(formatReference(book, format: 'html'),
        'Brown, M. (2018). <i>Writing research papers</i> (2nd ed.). Academic Press.');
    expect(formatReference(book, format: 'markdown'),
        'Brown, M. (2018). *Writing research papers* (2nd ed.). Academic Press.');
    expect(
        formatReference(withField(book, 'title', 'Tom & <Jerry>'),
            format: 'html'),
        contains('<i>Tom &amp; &lt;Jerry&gt;</i>'));
  });

  test('in-text citations', () {
    expect(citeInText(article, page: '50'), '(Smith & Lee, 2020, p. 50)');
    expect(citeInText(article, narrative: true), 'Smith and Lee (2020)');
    expect(citeInText(chapter, page: '101-103'),
        '(Khan et al., 2019, pp. 101–103)');
    expect(citeInText(article, style: 'mla', page: '50'), '(Smith and Lee 50)');
    expect(citeInText(chapter, style: 'mla'), '(Khan et al.)');
    expect(citeInText({'title': 'Citation guide', 'year': 2021}),
        '(“Citation guide,” 2021)');
    expect(citeInText({'title': 'Citation guide'}, narrative: true),
        '“Citation guide” (n.d.)');
  });

  test('bibliography is sorted', () {
    expect(
        formatBibliography([article, chapter, book])
            .map((s) => s.split(',')[0]),
        ['Brown', 'Khan', 'Smith']);
  });

  test('unknown style or format', () {
    expect(
        () => formatReference(book, style: 'xyz'),
        throwsA(isA<ArgumentError>().having((e) => '${e.message}', 'message',
            contains('Unknown citation style'))));
    expect(
        () => formatReference(book, format: 'pdf'),
        throwsA(isA<ArgumentError>().having((e) => '${e.message}', 'message',
            contains('Unknown output format'))));
  });

  test('invalid DOI is not a link and full URL is not doubled', () {
    const base = {
      'type': 'book',
      'title': 'T',
      'author': [
        {'family': 'A', 'given': 'B'},
      ],
      'year': 2001,
    };
    expect(formatReference(withField(base, 'DOI', 'not-a-doi')),
        'A, B. (2001). T.');
    expect(formatReference(withField(base, 'DOI', 'https://doi.org/10.1234/x')),
        'A, B. (2001). T. https://doi.org/10.1234/x');
  });

  test('BibTeX export', () {
    expect(
        toBibTeX(article),
        [
          '@article{smith2020deep,',
          '  author = {Smith, John Allen and Lee, Kate},',
          '  title = {Deep learning for text similarity},',
          '  journal = {Journal of Academic Writing},',
          '  year = {2020},',
          '  volume = {12},',
          '  number = {3},',
          '  pages = {45--67},',
          '  doi = {10.1234/jaw.2020.045}',
          '}',
        ].join('\n'));
    expect(toBibTeX(withField(book, 'title', '50% of R&D')),
        contains(r'title = {50\% of R\&D}'));
    expect(
        RegExp(r'@book\{(\w+),')
            .allMatches(toBibTeX([book, book]))
            .map((m) => m[1]),
        ['brown2018writing', 'brown2018writinga']);
  });

  test('BibTeX round trip', () {
    final originals = [article, book, chapter];
    final parsed = parseBibTeX(toBibTeX(originals));
    for (var i = 0; i < originals.length; i++) {
      expect(parsed[i]..remove('id'), originals[i]);
    }
  });

  test('BibTeX import: LaTeX, macros and organisations', () {
    final refs = parseBibTeX(r'''
        @comment{ignored}
        @string{jaw = "Journal of Academic Writing"}
        @Article{muller21,
          author  = {M{\"u}ller, J{\"o}rg and {World Health Organization}},
          title   = "{T}he {\&} problem",
          journal = jaw,
          year    = 2021, month = mar,
          pages   = "1--9",
          doi     = {https://doi.org/10.5555/abc}
        }''');
    expect(refs, hasLength(1));
    final ref = refs.single;
    expect(ref['author'], [
      {'family': 'Müller', 'given': 'Jörg'},
      {'literal': 'World Health Organization'},
    ]);
    expect(ref['title'], 'The & problem');
    expect(ref['container-title'], 'Journal of Academic Writing');
    expect(ref['issued'], {
      'date-parts': [
        [2021, 3],
      ],
    });
    expect(ref['page'], '1-9');
    expect(ref['DOI'], '10.5555/abc');
  });

  test('DOI normalising and extraction', () {
    expect(normalizeDoi('https://doi.org/10.1234/ABC.5'), '10.1234/ABC.5');
    expect(normalizeDoi('doi: 10.1234/abc'), '10.1234/abc');
    expect(normalizeDoi('not a doi'), isNull);
    expect(isDoi(null), isFalse);
    expect(
        extractDois(
            'See (doi:10.1000/xyz123). Also https://doi.org/10.1000/xyz123 and 10.5555/a(b)c.'),
        ['10.1000/xyz123', '10.5555/a(b)c']);
  });

  test('DOI lookup maps Crossref', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      return http.Response(
          jsonEncode({
            'message': {
              'type': 'journal-article',
              'title': ['Deep learning for text similarity'],
              'author': [
                {'given': 'John Allen', 'family': 'Smith'},
                {'given': 'Kate', 'family': 'Lee'},
              ],
              'container-title': ['Journal of Academic Writing'],
              'issued': {
                'date-parts': [
                  [2020],
                ],
              },
              'volume': '12',
              'issue': '3',
              'page': '45-67',
              'DOI': '10.1234/jaw.2020.045',
              'URL': 'https://doi.org/10.1234/jaw.2020.045',
              'publisher': 'Example Publisher',
            },
          }),
          200);
    });
    final ref = await lookupDoi('doi:10.1234/jaw.2020.045',
        mailto: 'a@b.org', client: client);
    expect(urls.single,
        'https://api.crossref.org/works/10.1234%2Fjaw.2020.045?mailto=a%40b.org');
    expect(formatReference(ref), formatReference(article));

    final notFound = MockClient((_) async => http.Response('', 404));
    await expectLater(
        lookupDoi('10.1234/none', client: notFound),
        throwsA(isA<DoiLookupException>()
            .having((e) => e.message, 'message', startsWith('DOI not found'))));
    await expectLater(
        lookupDoi('nope', client: notFound), throwsFormatException);
  });

  test('DOI lookup falls back to doi.org', () async {
    final calls = <(String, String?)>[];
    final client = MockClient((request) async {
      calls.add((request.url.toString(), request.headers['Accept']));
      if (request.url.host == 'api.crossref.org') return http.Response('', 404);
      return http.Response(
          jsonEncode({
            'type': 'article',
            'title': 'Attention is all you need',
            'author': [
              {'family': 'Vaswani', 'given': 'Ashish'},
              {'family': 'Shazeer', 'given': 'Noam'},
            ],
            'issued': {
              'date-parts': [
                [2017],
              ],
            },
            'publisher': 'arXiv',
            'DOI': '10.48550/ARXIV.1706.03762',
            'abstract': 'ignored',
          }),
          200);
    });
    final ref = await lookupDoi('10.48550/arXiv.1706.03762', client: client);
    expect(calls[1], (
      'https://doi.org/10.48550/arXiv.1706.03762',
      'application/vnd.citationstyles.csl+json'
    ));
    expect(ref.containsKey('abstract'), isFalse);
    expect(formatReference(ref),
        'Vaswani, A., & Shazeer, N. (2017). Attention is all you need. arXiv. https://doi.org/10.48550/ARXIV.1706.03762');
    expect(formatReference(ref, style: 'mla'),
        'Vaswani, Ashish, and Noam Shazeer. “Attention is all you need.” arXiv, 2017, https://doi.org/10.48550/ARXIV.1706.03762.');
  });

  test('Crossref markup, subtitle and book title', () {
    final ref = fromCrossref({
      'type': 'book-chapter',
      'title': ['Optuna'],
      'subtitle': ['A next-generation <i>hyperparameter</i> framework'],
      'container-title': [
        'Lecture Notes in Computer Science',
        'Knowledge Discovery &amp; Data Mining'
      ],
      'author': [
        {'family': 'Akiba', 'given': 'Takuya'},
      ],
      'publisher': 'ACM',
      'DOI': '10.1145/1',
    });
    expect(ref['title'], 'Optuna: A next-generation hyperparameter framework');
    expect(ref['container-title'], 'Knowledge Discovery & Data Mining');
    expect(
        fromCrossref({
          'type': 'journal-article',
          'container-title': ['Nature', 'Nat.'],
        })['container-title'],
        'Nature');
  });

  test('duplicate detection', () {
    final groups = findDuplicates([
      article,
      book,
      {
        ...article,
        'title': 'A different title',
        'DOI': 'https://doi.org/10.1234/JAW.2020.045'
      },
      withField(book, 'title', 'Writing Research Papers!'),
      withField(book, 'author', [
        {'family': 'Someone', 'given': 'Else'},
      ]),
    ]);
    expect(groups, [
      {
        'indexes': [0, 2],
        'reasons': ['doi'],
      },
      {
        'indexes': [1, 3],
        'reasons': ['title'],
      },
    ]);
    expect(findDuplicates([article, book]), isEmpty);
  });

  test('check references', () async {
    final refs = parseBibTeX('''
        @article{smith2020, author={Smith, John and Lee, Kate}, title={Deep learning for text similarity},
          journal={Journal of Academic Writing}, year=2020, volume=12, number=3, pages={45--67}}
        @book{brown2018, author={Brown, Mary}, title={Writing research papers}, publisher={Academic Press}, year=2018}
        @article{smithdup, author={Smith, J.}, title={Deep Learning for Text Similarity!}, journal={JAW}, year=2020}
        @misc{bad, title={Untitled web page}, doi={not-a-doi}}
        ''');
    final result = await checkReferences(refs);
    expect([result['references'], result['errors'], result['warnings']],
        [4, 2, 2]);
    final issues = result['issues'] as List;
    expect(issues.map((x) => x['code']),
        ['duplicate', 'invalid-doi', 'missing-author', 'missing-year']);
    expect(issues[0]['message'],
        'Possible duplicate (title match) of smith2020: smith2020, smithdup');

    final missing = await checkReferences([
      {
        'title': 'X',
        'author': ['A B'],
        'year': 2000,
        'DOI': '10.1234/missing',
      },
    ],
        checkDois: true,
        client: MockClient((_) async => http.Response('', 404)));
    expect(
        (missing['issues'] as List).map((x) => x['code']), ['doi-not-found']);
  });

  test('numbers in fields', () {
    final ref = {
      'type': 'book',
      'title': 'Writing research papers',
      'author': [
        {'family': 'Brown', 'given': 'Mary'},
      ],
      'issued': {
        'date-parts': [
          [2018, 4],
        ],
      },
      'edition': 3,
      'volume': 2.0,
      'publisher': 'Academic Press',
    };
    expect(formatReference(ref),
        'Brown, M. (2018). Writing research papers (3rd ed.). Academic Press.');
    expect(formatReference(ref, style: 'mla'),
        'Brown, Mary. Writing research papers. 3rd ed., vol. 2, Academic Press, Apr. 2018.');
    expect(toBibTeX(ref), contains('month = {apr}'));
  });
}
