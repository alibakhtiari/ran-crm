# Shared Contact CRM - Flutter App

A simple, private CRM app for small teams built with Flutter and Cloudflare D1 backend.

## Features

- **JWT-based Authentication** - Secure login/logout
- **Contact Management** - Add, edit, delete contacts with unique phone numbers
- **Call Logging** - Track incoming/outgoing calls
- **Admin Panel** - Admin-only user management
- **Cross-platform** - Works on Android, iOS, and Web

## Prerequisites

- Flutter SDK (>=3.0.0)
- Cloudflare Worker with D1 database set up
- Android Studio / VS Code with Flutter extensions

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure API Endpoint

Open `lib/api/api_client.dart` and update the `baseUrl` with your Cloudflare Worker URL:

```dart
static const String baseUrl = 'https://your-worker.workers.dev';
```

### 3. Android Permissions

The app requires the following permissions for call logging (already configured in `AndroidManifest.xml`):
- `READ_CALL_LOG`
- `READ_PHONE_STATE`
- `INTERNET`

Make sure to request these permissions at runtime using the `permission_handler` package.

### 4. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── api/
│   ├── api_client.dart         # HTTP client with all API calls
│   └── auth_interceptor.dart   # JWT authentication interceptor
├── models/
│   ├── user.dart               # User model
│   ├── contact.dart            # Contact model
│   └── call.dart               # Call model
├── providers/
│   ├── auth_provider.dart      # Authentication state management
│   └── contact_provider.dart   # Contact state management
├── screens/
│   ├── login_screen.dart       # Login UI
│   ├── contacts_screen.dart    # Main contacts list
│   ├── call_logs_screen.dart   # Call history
│   └── admin_screen.dart       # Admin panel for user management
└── widgets/
    ├── contact_tile.dart       # Contact list item widget
    └── call_tile.dart          # Call log item widget
```

## Backend Setup

You need a Cloudflare Worker with D1 database. Refer to the PRD document (1.md) for:
- Database schema
- API endpoints
- Authentication setup

### API Endpoints Expected

- `POST /login` - Login with email/password
- `GET /contacts` - Get all contacts
- `POST /contacts` - Create new contact
- `PUT /contacts/:id` - Update contact
- `DELETE /contacts/:id` - Delete contact
- `GET /calls` - Get call logs
- `POST /calls` - Create call log
- `POST /admin/users` - Create user (admin only)
- `GET /admin/users` - Get all users (admin only)
- `DELETE /admin/users/:id` - Delete user (admin only)

## Default Admin Credentials

Make sure your backend is seeded with an admin user. Example:
```
Email: admin@example.com
Password: admin123
```

## Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Security Notes

- JWT tokens are stored securely using `flutter_secure_storage`
- All API requests include Bearer token authentication
- Passwords are hashed on the backend (bcrypt)
- Phone numbers have unique constraints

## Dependencies

Key packages used:
- `dio` - HTTP client
- `provider` - State management
- `flutter_secure_storage` - Secure token storage
- `sqflite` - Local database cache
- `call_log` - Call detection (Android)
- `permission_handler` - Runtime permissions
- `intl` - Date formatting

## Future Enhancements

- [ ] Push notifications for contact updates
- [ ] Offline mode with local sync
- [ ] Call detection background service
- [ ] Web admin panel
- [ ] Contact export/import
- [ ] Search and filter contacts
- [ ] Dark mode

## License

This project is private and proprietary.

## Support

For issues or questions, contact your development team.
