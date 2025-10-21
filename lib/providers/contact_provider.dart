import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/contact.dart';
import '../services/local_database_service.dart';

class ContactProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final LocalDatabaseService _localDb = LocalDatabaseService();

  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ContactProvider({ApiClient? apiClient}) : apiClient = apiClient ?? ApiClient() {
    // Load from local cache immediately
    _loadFromCache();
  }

  /// Load contacts from local cache (instant)
  Future<void> _loadFromCache() async {
    try {
      _contacts = await _localDb.getContacts();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load from cache: $e');
      }
    }
  }

  /// Fetch contacts from server and update cache
  Future<void> fetchContacts({bool showLoading = true}) async {
    try {
      if (showLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      // Fetch from server
      final serverContacts = await apiClient.getContacts();

      // Update local cache
      await _localDb.clearContacts();
      await _localDb.insertContacts(serverContacts);

      // Update UI
      _contacts = serverContacts;
      _isLoading = false;
      notifyListeners();

      // Update contact names in call logs
      await _localDb.updateCallLogContactNames();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();

      // Fall back to cache on error
      if (_contacts.isEmpty) {
        await _loadFromCache();
      }
    }
  }

  Future<bool> addContact(Contact contact) async {
    try {
      _errorMessage = null;
      final newContact = await apiClient.createContact(contact);

      // Update local cache
      await _localDb.insertContact(newContact);

      // Update UI
      _contacts.add(newContact);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateContact(int id, Contact contact) async {
    try {
      _errorMessage = null;
      final updatedContact = await apiClient.updateContact(id, contact);

      // Update local cache
      await _localDb.updateContact(updatedContact);

      // Update UI
      final index = _contacts.indexWhere((c) => c.id == id);
      if (index != -1) {
        _contacts[index] = updatedContact;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContact(int id) async {
    try {
      _errorMessage = null;
      await apiClient.deleteContact(id);

      // Update local cache
      await _localDb.deleteContact(id);

      // Update UI
      _contacts.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Contact? getContactByPhone(String phoneNumber) {
    // Quick in-memory lookup
    final normalized = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    for (final contact in _contacts) {
      final contactNormalized = contact.phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      if (contactNormalized.contains(normalized) || normalized.contains(contactNormalized)) {
        return contact;
      }
    }
    return null;
  }

  bool canEditContact(Contact contact, int currentUserId, bool isAdmin) {
    return isAdmin || contact.createdByUserId == currentUserId;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
