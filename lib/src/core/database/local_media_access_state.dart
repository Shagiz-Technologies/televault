enum LocalMediaAccessState { available, accessUnavailable }

extension LocalMediaAccessStateDb on LocalMediaAccessState {
  String get dbValue => name;
}

LocalMediaAccessState localMediaAccessStateFromDb(String value) {
  return LocalMediaAccessState.values.firstWhere(
    (state) => state.dbValue == value,
    orElse: () => LocalMediaAccessState.accessUnavailable,
  );
}
