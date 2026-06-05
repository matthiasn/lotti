part of 'database.dart';

/// Config-flag state, lookups, and private-visibility helpers for
/// [JournalDb].
///
/// Owns the in-memory flag cache behind [watchConfigFlags] and the
/// `private` visibility gate that every query mixin routes through via
/// [_queryWithPrivateFilter].
mixin _JournalDbConfigFlags on _$JournalDb {
  final Map<String, ConfigFlag> _configFlagsByName = <String, ConfigFlag>{};
  final StreamController<Set<ConfigFlag>> _configFlagsController =
      StreamController<Set<ConfigFlag>>.broadcast(sync: true);
  Future<void>? _configFlagsBootstrap;
  bool _configFlagsLoaded = false;

  Stream<Set<ConfigFlag>> watchConfigFlags() {
    return Stream<Set<ConfigFlag>>.multi((controller) {
      StreamSubscription<Set<ConfigFlag>>? subscription;
      Set<ConfigFlag>? lastEmitted;

      void emit(Set<ConfigFlag> flags) {
        final previousFlags = lastEmitted;
        if (previousFlags != null &&
            const SetEquality<ConfigFlag>().equals(previousFlags, flags)) {
          return;
        }

        lastEmitted = flags;
        controller.add(flags);
      }

      subscription = _configFlagsController.stream.listen(
        emit,
        onError: controller.addError,
        onDone: controller.close,
      );

      if (_configFlagsLoaded) {
        emit(_currentConfigFlags());
      } else {
        Future<void>(() async {
          await _ensureConfigFlagsLoaded();
          emit(_currentConfigFlags());
        });
      }

      controller.onCancel = () => subscription?.cancel();
    }, isBroadcast: true);
  }

  Stream<Set<String>> watchActiveConfigFlagNames() {
    return watchConfigFlags().map((configFlags) {
      final activeFlags = <String>{};
      for (final flag in configFlags) {
        if (flag.status) {
          activeFlags.add(flag.name);
        }
      }
      return activeFlags;
    });
  }

  bool findConfigFlag(String flagName, List<ConfigFlag> flags) {
    var flag = false;

    for (final configFlag in flags) {
      if (configFlag.name == flagName) {
        flag = configFlag.status;
      }
    }

    return flag;
  }

  Future<bool> getConfigFlag(String flagName) async {
    await _ensureConfigFlagsLoaded();
    return _configFlagsByName[flagName]?.status ?? false;
  }

  Stream<bool> watchConfigFlag(String flagName) {
    return watchConfigFlags()
        .map(
          (_) => _configFlagsByName[flagName]?.status ?? false,
        )
        .distinct();
  }

  Future<ConfigFlag?> getConfigFlagByName(String flagName) async {
    await _ensureConfigFlagsLoaded();
    return _configFlagsByName[flagName];
  }

  Future<void> insertFlagIfNotExists(ConfigFlag configFlag) async {
    await _ensureConfigFlagsLoaded();
    final existing = _configFlagsByName[configFlag.name];

    if (existing == null) {
      await into(configFlags).insert(configFlag);
      _setConfigFlag(configFlag);
    }
  }

  Future<int> upsertConfigFlag(ConfigFlag configFlag) async {
    await _ensureConfigFlagsLoaded();
    final result = await into(configFlags).insertOnConflictUpdate(configFlag);
    _setConfigFlag(configFlag);
    return result;
  }

  Future<void> toggleConfigFlag(String flagName) async {
    final configFlag = await getConfigFlagByName(flagName);

    if (configFlag != null) {
      await upsertConfigFlag(configFlag.copyWith(status: !configFlag.status));
    }
  }

  Future<List<bool>> _visiblePrivateStatuses() async {
    final showPrivateEntries = await getConfigFlag('private');
    return showPrivateEntries ? const [false, true] : const [false];
  }

  bool _matchesAllPrivateStates(List<bool> privateStatuses) =>
      privateStatuses.length == 2 &&
      privateStatuses.contains(true) &&
      privateStatuses.contains(false);

  /// Resolves private-visibility config and dispatches to either the
  /// [allPrivate] query (when all private states are visible) or the
  /// [filtered] query (passing the allowed statuses).
  Future<T> _queryWithPrivateFilter<T>({
    required Future<T> Function() allPrivate,
    required Future<T> Function(List<bool> statuses) filtered,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    return _matchesAllPrivateStates(privateStatuses)
        ? allPrivate()
        : filtered(privateStatuses);
  }

  Future<void> _ensureConfigFlagsLoaded() {
    final existingBootstrap = _configFlagsBootstrap;
    if (existingBootstrap != null) {
      return existingBootstrap;
    }

    late final Future<void> future;
    future = listConfigFlags()
        .get()
        .then((flags) {
          _configFlagsLoaded = true;
          _replaceConfigFlags(flags);
        })
        .whenComplete(() {
          if (identical(_configFlagsBootstrap, future)) {
            if (_configFlagsLoaded) {
              _configFlagsBootstrap = Future<void>.value();
            } else {
              _configFlagsBootstrap = null;
            }
          }
        });

    _configFlagsBootstrap = future;
    return future;
  }

  Set<ConfigFlag> _currentConfigFlags() => _configFlagsByName.values.toSet();

  void _replaceConfigFlags(Iterable<ConfigFlag> flags) {
    final next = <String, ConfigFlag>{
      for (final flag in flags) flag.name: flag,
    };

    if (const MapEquality<String, ConfigFlag>().equals(
      _configFlagsByName,
      next,
    )) {
      return;
    }

    _configFlagsByName
      ..clear()
      ..addAll(next);
    _emitConfigFlags();
  }

  void _setConfigFlag(ConfigFlag configFlag) {
    _configFlagsLoaded = true;
    final existing = _configFlagsByName[configFlag.name];
    if (existing == configFlag) {
      return;
    }

    _configFlagsByName[configFlag.name] = configFlag;
    _emitConfigFlags();
  }

  void _emitConfigFlags() {
    if (!_configFlagsController.isClosed) {
      _configFlagsController.add(_currentConfigFlags());
    }
  }
}
