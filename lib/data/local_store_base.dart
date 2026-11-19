import '../domain/models.dart';

abstract class LocalDataStore {
  Future<AppData?> load();

  Future<void> save(AppData data);

  Future<void> clear();
}
