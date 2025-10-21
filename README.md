# Shared Contact CRM - Flutter Edition

A private, team-based CRM app built with Flutter and Cloudflare D1 backend for managing shared contacts and call logs.

## Features

- **Authentication**: JWT-based login/logout system
- **Contact Management**: Shared contact list with duplicate prevention
- **Call Logging**: Automatic call tracking (Android)
- **Role-Based Access**: Admin and user roles with different permissions
- **Offline Support**: Local caching with sqflite
- **Cross-Platform**: Android, iOS, and Web support

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── api/
│   ├── api_client.dart       # REST API client
│   └── auth_interceptor.dart # JWT token interceptor
├── models/
│   ├── user.dart             # User model
│   ├── contact.dart          # Contact model
│   └── call.dart             # Call model
├── providers/
│   ├── auth_provider.dart    # Authentication state
│   └── contact_provider.dart # Contact state
├── screens/
│   ├── login_screen.dart     # Login UI
│   ├── contacts_screen.dart  # Main contacts list
│   ├── call_logs_screen.dart # Call history
│   └── admin_screen.dart     # User management
└── widgets/
    ├── contact_tile.dart     # Contact list item
    └── call_tile.dart        # Call log item
```

## Setup Instructions

### Prerequisites

1. **Install Flutter**: Follow the official guide at https://flutter.dev/docs/get-started/install
2. **Set up Android Studio or Xcode** for your target platform

### Configuration

1. **Update API Base URL**

   Open `lib/api/api_client.dart` and replace the placeholder with your Cloudflare Worker URL:

   ```dart
   static const String baseUrl = 'YOUR_CLOUDFLARE_WORKER_URL';
   ```

2. **Android Permissions**

   For call logging features, add the following to `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <uses-permission android:name="android.permission.READ_PHONE_STATE" />
   <uses-permission android:name="android.permission.READ_CALL_LOG" />
   <uses-permission android:name="android.permission.PROCESS_OUTGOING_CALLS" />
   <uses-permission android:name="android.permission.INTERNET" />
   ```

3. **Install Dependencies**

   ```bash
   cd shared_contact_crm
   flutter pub get
   ```

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Build APK for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

## Backend Setup (Cloudflare Worker + D1)

This app requires a Cloudflare Worker with D1 database. See the PRD (1.md) for the complete backend schema and API endpoints.

### Required API Endpoints

- `POST /login` - User authentication
- `GET /contacts` - List all contacts
- `POST /contacts` - Create new contact
- `PUT /contacts/:id` - Update contact
- `DELETE /contacts/:id` - Delete contact
- `GET /calls` - List call logs
- `POST /calls` - Create call log
- `POST /admin/users` - Create user (admin only)
- `GET /admin/users` - List users (admin only)
- `DELETE /admin/users/:id` - Delete user (admin only)

## Default Admin Account

Make sure your Cloudflare Worker has seeded an admin account in the D1 database:

```sql
INSERT INTO users (email, password_hash, role)
VALUES ('admin@example.com', 'bcrypt_hash_here', 'admin');
```

## Security Features

- JWT token authentication
- Secure storage for tokens
- Role-based authorization
- Unique phone number constraint
- Owner-only edit permissions

## Future Enhancements

- Push notifications for contact updates
- Web admin dashboard
- Contact field encryption
- Export to Google Drive/iCloud
- Voice call integration
- SMS integration

## Troubleshooting

### Flutter Not Found

If you see "flutter: command not found", install Flutter SDK and add it to your PATH:

```bash
export PATH="$PATH:`pwd`/flutter/bin"
```

### Permission Errors (Android)

Request runtime permissions in the app for Android 6.0+ devices. The app should prompt for phone and call log permissions.

### Network Errors

Ensure your Cloudflare Worker URL is correct and accessible. Test the API endpoints using curl or Postman first.

## License

Private project - All rights reserved
