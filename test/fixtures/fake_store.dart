import 'package:dreamtide/data/local_store_base.dart';
import 'package:dreamtide/data/provider_key_store.dart';
import 'package:dreamtide/domain/models.dart';

class FakeStore implements LocalDataStore {
  FakeStore([this.data]);
  AppData? data;
  @override
  Future<AppData?> load() async => data;
  @override
  Future<void> save(AppData value) async {
    data = value;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

class FakeKeyStore extends ProviderKeyStore {
  String? value;
  @override
  Future<String?> read({required bool persistent}) async => value;
  @override
  Future<void> write(String value, {required bool persistent}) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
