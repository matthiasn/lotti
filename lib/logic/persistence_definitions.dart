part of 'persistence_logic.dart';

/// Entity/dashboard definition and config-flag operations of
/// [PersistenceLogic]; same delegator pattern as the create part.
mixin _PersistenceDefinitionOps on _PersistenceLogicBase {
  @override
  Future<int> upsertEntityDefinitionImpl(
    EntityDefinition entityDefinition,
  ) async {
    final linesAffected = await _journalDb.upsertEntityDefinition(
      entityDefinition,
    );
    final typeNotification = switch (entityDefinition) {
      CategoryDefinition() => categoriesNotification,
      HabitDefinition() => habitsNotification,
      DashboardDefinition() => dashboardsNotification,
      MeasurableDataType() => measurablesNotification,
      LabelDefinition() => labelsNotification,
    };
    _updateNotifications.notify({entityDefinition.id, typeNotification});
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: entityDefinition,
        status: SyncEntryStatus.update,
      ),
    );
    return linesAffected;
  }

  @override
  Future<int> upsertDashboardDefinitionImpl(
    DashboardDefinition dashboard,
  ) async {
    final linesAffected = await _journalDb.upsertDashboardDefinition(dashboard);
    _updateNotifications.notify({dashboard.id, dashboardsNotification});
    await outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: dashboard,
        status: SyncEntryStatus.update,
      ),
    );

    if (dashboard.deletedAt != null) {
      await getIt<NotificationService>().cancelNotification(
        dashboard.id.hashCode,
      );
    }

    return linesAffected;
  }

  @override
  Future<void> setConfigFlagImpl(ConfigFlag configFlag) async {
    final previous = await _journalDb.getConfigFlagByName(configFlag.name);
    await _journalDb.upsertConfigFlag(configFlag);
    if (previous?.status != configFlag.status) {
      await outboxService.enqueueMessage(
        SyncMessage.configFlag(
          name: configFlag.name,
          description: configFlag.description,
          status: configFlag.status,
        ),
      );
    }
    if (configFlag.name == 'private') {
      _updateNotifications.notify({privateToggleNotification});
    }
  }

  @override
  Future<int> deleteDashboardDefinitionImpl(
    DashboardDefinition dashboard,
  ) async {
    final linesAffected = await upsertDashboardDefinition(
      dashboard.copyWith(
        deletedAt: DateTime.now(),
      ),
    );

    await getIt<NotificationService>().cancelNotification(
      dashboard.id.hashCode,
    );

    return linesAffected;
  }
}
