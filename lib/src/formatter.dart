// Escapes text and italicises titles for the chosen output format.

const _htmlEscapes = {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'};
final _markdownSpecial = RegExp(r'([\\*_])');

class Formatter {
  final String format;

  Formatter(this.format) {
    if (!const ['text', 'html', 'markdown'].contains(format)) {
      throw ArgumentError(
          'Unknown output format "$format". Use "text", "html" or "markdown".');
    }
  }

  /// Plain text in the output format.
  String t(String s) {
    if (format == 'html') {
      return s.replaceAllMapped(RegExp('[&<>"]'), (m) => _htmlEscapes[m[0]]!);
    }
    if (format == 'markdown') {
      return s.replaceAllMapped(_markdownSpecial, (m) => '\\${m[1]}');
    }
    return s;
  }

  /// Italic text in the output format.
  String i(String s) {
    if (format == 'html') return '<i>${t(s)}</i>';
    if (format == 'markdown') return '*${t(s)}*';
    return s;
  }
}
