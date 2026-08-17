import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/relationships/model/imported_contact.dart';
import 'package:lotti/features/relationships/service/contact_import_mapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// The outcome of asking for read access to the address book.
enum ContactsAccess {
  /// The whole address book is readable.
  granted,

  /// iOS 18+ partial access: the user chose which contacts to share, and only
  /// those are readable. Treated as usable rather than as a failure — picking
  /// a handful of people is exactly what this feature asks for, so the OS
  /// handing back a curated subset is the happy path, not a degraded one.
  limited,

  /// Declined, but askable again.
  denied,

  /// Declined with "don't ask again", or restricted by policy. Only a trip to
  /// system settings changes this, so the UI offers that instead of a retry
  /// that cannot succeed.
  permanentlyDenied,

  /// No address book to read: desktop, where contact channels are entered by
  /// hand (ADR 0041 §2).
  unsupported,
}

/// Reads the OS address book on the user's explicit instruction (ADR 0041).
///
/// An interface rather than static calls so every caller above it — the
/// import controller, the review screen, the link action — is testable
/// without a platform channel.
///
/// Nothing here runs on its own: there is no background sync and no read at
/// launch. Every method corresponds to a button the user pressed, which is
/// what keeps the permission request honest and the address book out of
/// Lotti's storage.
abstract class ContactsService {
  /// Whether this platform has an address book Lotti can read.
  bool get isSupported;

  /// Requests read access, returning what the OS decided.
  Future<ContactsAccess> requestReadAccess();

  /// Opens the native single-contact picker and returns the chosen contact
  /// with its channels, or null when the user cancelled.
  ///
  /// The picker runs out-of-process, so the user sees their address book
  /// without Lotti reading it — only the one contact they tap comes back.
  Future<ImportedContact?> pickSingle();

  /// Reads every contact the app is allowed to see, for the multi-select
  /// import list. Requires [requestReadAccess] to have succeeded.
  Future<List<ImportedContact>> readAll();

  /// Re-reads one contact by its OS id, for "Update from contact".
  /// Returns null when the contact no longer exists on this device.
  Future<ImportedContact?> readById(String id);

  /// Sends the user to the app's system settings page, the only route out of
  /// [ContactsAccess.permanentlyDenied].
  Future<void> openSystemSettings();
}

/// The `flutter_contacts` implementation.
///
/// Every platform call is wrapped: a [PlatformException] from a missing
/// permission, a cancelled picker or a plugin absent on this platform is
/// reported and turned into a safe empty result. A contact import that fails
/// must leave the user on the same screen with a message, never crash the
/// People tab.
class FlutterContactsService implements ContactsService {
  FlutterContactsService({
    DomainLogger? logger,
    bool Function()? hasAddressBook,
  }) : _injectedLogger = logger,
       _hasAddressBook = hasAddressBook ?? _platformHasAddressBook;

  final DomainLogger? _injectedLogger;

  /// Injectable so the platform-guarded paths are reachable in the test VM,
  /// which reports macOS/Linux and would otherwise make every method
  /// early-return before the platform channel is ever consulted.
  final bool Function() _hasAddressBook;

  static bool _platformHasAddressBook() => Platform.isAndroid || Platform.isIOS;

  /// Resolved lazily and tolerantly: logging must never be the reason a
  /// contact import fails, and `getIt` is not populated in every test.
  DomainLogger? get _logger {
    if (_injectedLogger != null) return _injectedLogger;
    return getIt.isRegistered<DomainLogger>() ? getIt<DomainLogger>() : null;
  }

  /// The properties worth reading. Photos, addresses, notes, organizations
  /// and events are deliberately not requested — Lotti has no use for them,
  /// and not asking is cheaper than asking and discarding (ADR 0037).
  static const Set<ContactProperty> _wantedProperties = {
    ContactProperty.name,
    ContactProperty.phone,
    ContactProperty.email,
  };

  @override
  bool get isSupported => _hasAddressBook();

  @override
  Future<ContactsAccess> requestReadAccess() async {
    if (!isSupported) return ContactsAccess.unsupported;

    return _guard(
      'requestReadAccess',
      fallback: ContactsAccess.denied,
      () async {
        final status = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        return switch (status) {
          PermissionStatus.granted => ContactsAccess.granted,
          PermissionStatus.limited => ContactsAccess.limited,
          // Restricted by policy (parental controls, MDM) behaves like a
          // permanent denial from the app's side: asking again cannot change
          // it, so the UI must not offer a retry.
          PermissionStatus.permanentlyDenied ||
          PermissionStatus.restricted => ContactsAccess.permanentlyDenied,
          // `notDetermined` after an explicit request means the OS dismissed
          // the prompt without an answer; asking again is legitimate.
          PermissionStatus.denied ||
          PermissionStatus.notDetermined => ContactsAccess.denied,
        };
      },
    );
  }

  @override
  Future<ImportedContact?> pickSingle() async {
    if (!isSupported) return null;

    return _guard('pickSingle', fallback: null, () async {
      final contact = await FlutterContacts.native.showPicker(
        properties: _wantedProperties,
      );
      return contact == null ? null : importedContactFrom(contact);
    });
  }

  @override
  Future<List<ImportedContact>> readAll() async {
    if (!isSupported) return const [];

    return _guard('readAll', fallback: const <ImportedContact>[], () async {
      final contacts = await FlutterContacts.getAll(
        properties: _wantedProperties,
      );
      final imported = importedContactsFrom(contacts);
      // The OS returns its own order, which differs per platform and per
      // account; sorting here means the import list reads the same way
      // everywhere.
      return imported..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
    });
  }

  @override
  Future<ImportedContact?> readById(String id) async {
    if (!isSupported) return null;

    return _guard('readById', fallback: null, () async {
      final contact = await FlutterContacts.get(
        id,
        properties: _wantedProperties,
      );
      return contact == null ? null : importedContactFrom(contact);
    });
  }

  @override
  Future<void> openSystemSettings() async {
    if (!isSupported) return;
    await _guard(
      'openSystemSettings',
      fallback: null,
      () async => FlutterContacts.permissions.openSettings(),
    );
  }

  /// Runs [action], converting any platform failure into [fallback].
  ///
  /// Catches [Object] rather than [PlatformException] alone: a plugin whose
  /// platform side is missing throws [MissingPluginException], and a malformed
  /// payload from the native layer surfaces as a cast error. None of those
  /// should reach the user as a crash on a screen they opened to pick a
  /// friend.
  Future<T> _guard<T>(
    String operation,
    Future<T> Function() action, {
    required T fallback,
  }) async {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      _logger?.error(
        LogDomain.general,
        error,
        message: 'contacts $operation failed',
        stackTrace: stackTrace,
        subDomain: operation,
      );
      return fallback;
    }
  }
}

final contactsServiceProvider = Provider<ContactsService>(
  (ref) => FlutterContactsService(),
  name: 'contactsServiceProvider',
);
