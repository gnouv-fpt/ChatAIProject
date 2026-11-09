import 'package:shared_preferences/shared_preferences.dart';

/// A fixed account namespace. Legacy local data is never assigned to a new user.
class PersonalPreferences {
  PersonalPreferences({this.uid});

  final String? uid;
  bool _closed = false;
  Future<void> _writes = Future.value();
  String get _prefix => uid == null ? '' : 'account/$uid/';

  Future<ScopedPreferences> open() async =>
      ScopedPreferences(await SharedPreferences.getInstance(), _prefix, this);

  void seal() => _closed = true;
  void reopen() => _closed = false;

  Future<bool> _write(Future<bool> Function() action) {
    if (_closed) return Future.value(false);
    final result = _writes.then<bool>(
      (_) async => _closed ? false : await action(),
    );
    _writes = result.then<void>((_) {}, onError: (Object error) {});
    return result;
  }

  Future<void> clearAccount() async {
    if (uid == null) throw StateError('An account is required.');
    seal();
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix))) {
      if (!await prefs.remove(key)) {
        throw StateError('Không thể xóa bộ nhớ tài khoản. Vui lòng thử lại.');
      }
    }
  }
}

class ScopedPreferences {
  ScopedPreferences(this._prefs, this._prefix, this._owner);
  final SharedPreferences _prefs;
  final String _prefix;
  final PersonalPreferences _owner;
  String? getString(String key) => _prefs.getString('$_prefix$key');
  double? getDouble(String key) => _prefs.getDouble('$_prefix$key');
  Future<bool> setString(String key, String value) =>
      _owner._write(() => _prefs.setString('$_prefix$key', value));
  Future<bool> setDouble(String key, double value) =>
      _owner._write(() => _prefs.setDouble('$_prefix$key', value));
  Future<bool> remove(String key) =>
      _owner._write(() => _prefs.remove('$_prefix$key'));
}
