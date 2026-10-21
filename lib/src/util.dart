// Date, text and page helpers shared by the styles.
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'doi.dart';

typedef Ref = Map<String, dynamic>;

const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const monthsMla = [
  'Jan.',
  'Feb.',
  'Mar.',
  'Apr.',
  'May',
  'June',
  'July',
  'Aug.',
  'Sept.',
  'Oct.',
  'Nov.',
  'Dec.',
];

/// JavaScript-style truthiness for optional fields (the string "0" counts as filled).
bool filled(Object? value) =>
    value != null &&
    value != false &&
    value != '' &&
    value != 0 &&
    !(value is List && value.isEmpty);

/// The value as text: strings as is, whole numbers without ".0".
String str(Object? value) {
  if (value == null) return '';
  if (value is double && value == value.truncateToDouble() && value.isFinite) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// The field as text when filled, otherwise "".
String text(Ref ref, String key) => filled(ref[key]) ? str(ref[key]) : '';

/// The field as a list (empty when missing or not a list).
List<dynamic> list(Object? value) => value is List ? value : const [];

int? toInt(Object? value) {
  if (!filled(value)) return null;
  if (value is num) return value.toInt();
  return num.tryParse(str(value).trim())?.toInt();
}

class Date {
  final int? year;
  final int? month;
  final int? day;
  const Date([this.year, this.month, this.day]);
}

/// Year, month and day from a CSL `issued` date or a plain `year` field.
Date getDate(Ref ref) {
  final issued = ref['issued'];
  if (issued is Map && issued['date-parts'] is List) {
    final dp = issued['date-parts'] as List;
    if (dp.isNotEmpty && dp[0] is List) {
      final parts = dp[0] as List;
      if (parts.isNotEmpty && filled(parts[0])) {
        int? part(int i) => parts.length > i ? toInt(parts[i]) : null;
        return Date(toInt(parts[0]), part(1), part(2));
      }
    }
  }
  if (filled(ref['year'])) return Date(toInt(ref['year']));
  return const Date();
}

String? getYear(Ref ref) {
  final year = getDate(ref).year;
  return year != null && year != 0 ? '$year' : null;
}

final _combining = RegExp('[̀-ͯ]');
final _nonAlnum = RegExp('[^a-z0-9]+');

/// Lowercase, strip accents and punctuation; used for comparisons and keys.
String normalizeText(Object? value) => unorm
    .nfkd(str(value))
    .replaceAll(_combining, '')
    .toLowerCase()
    .replaceAll(_nonAlnum, ' ')
    .trim();

final _terminal = RegExp('[.?!]["”’]?\$');

/// Period to append unless the text already ends with terminal punctuation.
String dot(String value) => _terminal.hasMatch(value.trim()) ? '' : '.';

final _dashes = RegExp(r'\s*[-–—]+\s*');

String pageRange(Object? page, [String dash = '–']) =>
    str(page).trim().replaceAll(_dashes, dash);

bool isPageRange(Object? page) => RegExp('[-–—]').hasMatch(str(page));

String ordinal(Object? value) {
  int n;
  if (value is num && value == value.truncate()) {
    n = value.toInt();
  } else if (value is String && RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
    n = int.parse(value.trim());
  } else {
    return str(value);
  }
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return '$n${const {1: 'st', 2: 'nd', 3: 'rd'}[n.remainder(10)] ?? 'th'}';
}

/// Preferred link for a reference: a valid DOI first, then URL.
String link(Ref ref) {
  final doi = filled(ref['DOI']) ? normalizeDoi(str(ref['DOI'])) : null;
  if (doi != null) return 'https://doi.org/$doi';
  return text(ref, 'URL');
}
