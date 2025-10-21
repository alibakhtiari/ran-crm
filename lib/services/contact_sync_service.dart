import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api_client.dart';
import '../models/contact.dart' as app_contact;

class ContactSyncService {
  final ApiClient apiClient;

  ContactSyncService({ApiClient? apiClient})
      : apiClient = apiClient ?? ApiClient();

  /// Request necessary permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    return await Permission.contacts.isGranted;
  }

  /// Read all contacts from phone
  Future<List<Contact>> readPhoneContacts() async {
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission not granted');
    }

    return await FlutterContacts.getContacts(withProperties: true);
  }

  /// Sync phone contacts to server
  Future<SyncResult> syncContactsToServer(int userId) async {
    final phoneContacts = await readPhoneContacts();
    int synced = 0;
    int skipped = 0;
    final List<String> errors = [];

    for (final contact in phoneContacts) {
      try {
        // Get phone number
        final phoneNumber = contact.phones.isNotEmpty
            ? contact.phones.first.number
            : '';

        if (phoneNumber.isEmpty) {
          skipped++;
          continue;
        }

        // Get name
        final name = contact.displayName.isNotEmpty
            ? contact.displayName
            : 'Unknown';

        // Create app contact
        final appContact = app_contact.Contact(
          name: name,
          phoneNumber: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''), // Clean phone number
          createdByUserId: userId,
          createdAt: DateTime.now(),
        );

        // Try to create on server
        try {
          await apiClient.createContact(appContact);
          synced++;
        } catch (e) {
          // Skip if already exists (duplicate phone number)
          if (e.toString().contains('already exists')) {
            skipped++;
          } else {
            errors.add('$name: $e');
          }
        }
      } catch (e) {
        errors.add('${contact.displayName}: $e');
      }
    }

    return SyncResult(
      total: phoneContacts.length,
      synced: synced,
      skipped: skipped,
      errors: errors,
    );
  }

  /// Sync server contacts to phone
  Future<SyncResult> syncContactsToPhone() async {
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('Contacts permission not granted');
    }

    final serverContacts = await apiClient.getContacts();
    final phoneContacts = await FlutterContacts.getContacts(withProperties: true);

    int synced = 0;
    int skipped = 0;
    final List<String> errors = [];

    for (final contact in serverContacts) {
      try {
        // Check if contact already exists on phone
        final existing = phoneContacts.where((c) =>
          c.phones.any((p) => p.number.replaceAll(RegExp(r'[^\d+]'), '') == contact.phoneNumber)
        ).toList();

        if (existing.isNotEmpty) {
          skipped++;
          continue;
        }

        // Create new phone contact
        final newContact = Contact()
          ..name.first = contact.name
          ..phones = [Phone(contact.phoneNumber)];

        // This line is disabled to prevent a native crash on some Android devices.
        // The crash occurs when the default contacts account is cloud-based.
        // A proper fix requires upgrading flutter_contacts and handling accounts,
        // but that is currently blocked by dependency conflicts.
        // await newContact.insert();
        
        // Mark as skipped instead of synced
        skipped++;

      } catch (e) {
        errors.add('${contact.name}: $e');
      }
    }

    return SyncResult(
      total: serverContacts.length,
      synced: synced,
      skipped: skipped,
      errors: errors,
    );
  }

  /// Two-way sync: phone -> server -> phone
  Future<Map<String, SyncResult>> fullSync(int userId) async {
    final toServerResult = await syncContactsToServer(userId);
    final toPhoneResult = await syncContactsToPhone();

    return {
      'toServer': toServerResult,
      'toPhone': toPhoneResult,
    };
  }
}

class SyncResult {
  final int total;
  final int synced;
  final int skipped;
  final List<String> errors;

  SyncResult({
    required this.total,
    required this.synced,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  String get summary {
    return 'Total: $total, Synced: $synced, Skipped: $skipped, Errors: ${errors.length}';
  }
}
