import 'dart:io';

import 'package:plagx_cite/src/cli.dart';

Future<void> main(List<String> arguments) async {
  final code = await runCli(arguments);
  await stdout.flush();
  exit(code);
}
