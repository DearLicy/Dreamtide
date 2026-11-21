import 'dart:io';

import '../../test/fixtures/sample_data.dart';

/// QA only: the runtime app never imports test fixtures or seeds demo data.
void main() {
  final data = buildSeedData();
  Directory('.tmp').createSync(recursive: true);
  File('.tmp/management-fixture.json').writeAsStringSync(
    data
        .copyWith(settings: data.settings.copyWith(ageConfirmed: true))
        .encode(),
  );
}
