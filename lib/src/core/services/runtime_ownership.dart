class RuntimeOwnershipLease {
  static final Map<String, Object> _owners = <String, Object>{};

  final String name;
  final Object _token = Object();
  bool _held = false;

  RuntimeOwnershipLease(this.name);

  bool tryAcquire() {
    if (_held) return true;
    if (_owners.containsKey(name)) return false;
    _owners[name] = _token;
    _held = true;
    return true;
  }

  void release() {
    if (!_held) return;
    if (identical(_owners[name], _token)) _owners.remove(name);
    _held = false;
  }
}
