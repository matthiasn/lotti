import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:uuid/uuid.dart';

/// Provides the shared [CategoryRepository], wired from the global [getIt]
/// service locator. Riverpod consumers read categories through this so they
/// can be overridden with a fake repository in tests.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    getIt<PersistenceLogic>(),
    getIt<JournalDb>(),
    getIt<EntitiesCacheService>(),
    getIt<UpdateNotifications>(),
  );
});

/// Read/write access to [CategoryDefinition] records.
///
/// Categories are stored as entity definitions in [JournalDb] and synced
/// across devices via the vector-clock CRDT, so every write goes through
/// [PersistenceLogic.upsertEntityDefinition] (which stamps sync metadata and
/// fans out an [UpdateNotifications] event) rather than touching the table
/// directly. "Deletes" are soft deletes: the row stays and gains a
/// `deletedAt` timestamp so the deletion itself replicates.
///
/// The `watch*` streams re-fetch whenever a relevant notification fires;
/// [getCategoryById] reads from the in-memory [EntitiesCacheService] for
/// synchronous, allocation-free lookups in hot UI paths.
class CategoryRepository {
  CategoryRepository(
    this._persistenceLogic,
    this._journalDb,
    this._entitiesCacheService,
    this._updateNotifications,
  );

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final EntitiesCacheService _entitiesCacheService;
  final UpdateNotifications _updateNotifications;
  final _uuid = const Uuid();

  /// Streams all (non-deleted) categories, re-emitting whenever a category is
  /// created/updated/deleted or the global private-mode toggle flips (which
  /// changes whether private categories are visible). Emits the current set
  /// once on subscription, then on every matching notification.
  Stream<List<CategoryDefinition>> watchCategories() {
    return notificationDrivenStream(
      notifications: _updateNotifications,
      notificationKeys: {categoriesNotification, privateToggleNotification},
      fetcher: _journalDb.getAllCategories,
    );
  }

  /// Streams a single category by [id], re-fetching on the same triggers as
  /// [watchCategories]. Emits `null` if the category does not exist (or has
  /// been deleted). Backs `categoryDetailsControllerProvider`.
  Stream<CategoryDefinition?> watchCategory(String id) {
    return notificationDrivenItemStream(
      notifications: _updateNotifications,
      notificationKeys: {categoriesNotification, privateToggleNotification},
      fetcher: () => _journalDb.getCategoryById(id),
    );
  }

  /// Resolves a category by [id] synchronously from the in-memory
  /// [EntitiesCacheService] (no DB round-trip), or `null` if not cached.
  /// Prefer this in hot paths; use [watchCategory] when you need to react to
  /// updates.
  Future<CategoryDefinition?> getCategoryById(String id) async {
    // Use the cached version for efficient synchronous access
    return _entitiesCacheService.getCategoryById(id);
  }

  /// One-shot fetch of every category straight from [JournalDb], bypassing the
  /// cache. Used where a fresh snapshot is needed rather than the cached set.
  Future<List<CategoryDefinition>> getAllCategories() async {
    final categories = await _journalDb.allCategoryDefinitions().get();
    return categoryDefinitionsStreamMapper(categories);
  }

  /// Creates and persists a new category with a fresh UUID.
  ///
  /// New categories start `active: true` and `private: false`; [color] is a
  /// CSS hex string. The persisted record is returned (including its generated
  /// `id`/timestamps) so callers (e.g. the category create modal) can use it
  /// immediately without waiting for the cache to refresh.
  Future<CategoryDefinition> createCategory({
    required String name,
    required String color,
    CategoryIcon? icon,
    String? defaultProfileId,
    String? defaultTemplateId,
  }) async {
    final now = DateTime.now();

    final category = CategoryDefinition(
      id: _uuid.v4(),
      name: name,
      color: color,
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
      private: false,
      active: true,
      icon: icon,
      defaultProfileId: defaultProfileId,
      defaultTemplateId: defaultTemplateId,
    );

    await _persistenceLogic.upsertEntityDefinition(category);
    return category;
  }

  /// Persists [category], refreshing its `updatedAt` so the change wins the
  /// last-writer-wins merge on sync. Returns the stamped record. Callers pass
  /// a fully-formed category (typically the controller's pending copy); this
  /// does not merge field-by-field.
  Future<CategoryDefinition> updateCategory(
    CategoryDefinition category,
  ) async {
    final updated = category.copyWith(
      updatedAt: DateTime.now(),
    );

    await _persistenceLogic.upsertEntityDefinition(updated);
    return updated;
  }

  /// Returns a map of category id to the number of tasks assigned to it, in a
  /// single aggregate query. Categories with zero tasks are omitted. Backs
  /// `categoryTaskCountsProvider`.
  Future<Map<String, int>> getTaskCountsByCategory() async {
    return _journalDb.getTaskCountsByCategory();
  }

  /// Soft-deletes the category with [id] by stamping `deletedAt`/`updatedAt`
  /// and upserting it, so the deletion replicates across devices rather than
  /// silently dropping the row. No-op if the category is not found.
  Future<void> deleteCategory(String id) async {
    final category = await getCategoryById(id);
    if (category != null) {
      final deleted = category.copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _persistenceLogic.upsertEntityDefinition(deleted);
    }
  }
}
