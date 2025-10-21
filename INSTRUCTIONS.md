# Shared Contact CRM - Setup Instructions

## Project Status
✅ All Flutter source code files have been created and saved.

## Project Location
```
/Users/alib/crm/shared_contact_crm
```

## Files Created

### Core Files
- `pubspec.yaml` - Dependencies configuration
- `lib/main.dart` - App entry point with routing
- `.gitignore` - Git ignore rules
- `analysis_options.yaml` - Linting rules
- `README.md` - Complete documentation
- `setup.sh` - Automated setup script

### Data Models
- `lib/models/user.dart` - User model
- `lib/models/contact.dart` - Contact model
- `lib/models/call.dart` - Call log model

### API Layer
- `lib/api/api_client.dart` - REST API client with JWT
- `lib/api/auth_interceptor.dart` - JWT token interceptor

### State Management
- `lib/providers/auth_provider.dart` - Authentication state
- `lib/providers/contact_provider.dart` - Contact management state

### Screens
- `lib/screens/login_screen.dart` - Login UI
- `lib/screens/contacts_screen.dart` - Main contacts list
- `lib/screens/call_logs_screen.dart` - Call history view
- `lib/screens/admin_screen.dart` - User management (admin only)

### Widgets
- `lib/widgets/contact_tile.dart` - Contact list item
- `lib/widgets/call_tile.dart` - Call log list item

---

## Setup Steps (After Console Restart)

### 1. Navigate to Project Directory
```bash
cd /Users/alib/crm/shared_contact_crm
```

### 2. Initialize Flutter Project Structure
This creates the Android/iOS folders and native project files:
```bash
flutter create --org com.crm --project-name shared_contact_crm .
```

### 3. Install Dependencies
```bash
flutter pub get
```

**Note:** If you get dependency errors, run:
```bash
flutter pub upgrade
```

### 4. Configure API Endpoint
Edit `lib/api/api_client.dart` and replace:
```dart
static const String baseUrl = 'YOUR_CLOUDFLARE_WORKER_URL';
```

With your actual Cloudflare Worker URL:
```dart
static const String baseUrl = 'https://your-worker.your-subdomain.workers.dev';
```

### 5. Add Android Permissions
If targeting Android, ensure `android/app/src/main/AndroidManifest.xml` includes:
```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.READ_CALL_LOG" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 6. Run the App
```bash
# Check connected devices
flutter devices

# Run on connected device/emulator
flutter run

# Or run in debug mode with hot reload
flutter run --debug
```

### 7. Build for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS and Xcode)
flutter build ios --release
```

---

## Required Backend (Cloudflare Worker)

This app requires a Cloudflare Worker with D1 database. See `1.md` (PRD) for complete backend schema.

### API Endpoints Required:
- `POST /login` - User authentication
- `GET /contacts` - List all contacts
- `POST /contacts` - Create contact
- `PUT /contacts/:id` - Update contact
- `DELETE /contacts/:id` - Delete contact
- `GET /calls` - List call logs
- `POST /calls` - Create call log
- `POST /admin/users` - Create user (admin only)
- `GET /admin/users` - List users (admin only)
- `DELETE /admin/users/:id` - Delete user (admin only)

### Database Schema:
See the SQL schema in `1.md` for:
- `users` table
- `contacts` table
- `calls` table

---

## Troubleshooting

### Flutter Command Not Found
Add Flutter to your PATH:
```bash
export PATH="$PATH:/path/to/flutter/bin"
```

Or add to your `.zshrc` or `.bashrc`:
```bash
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Dependency Version Conflicts
If you see version conflicts, update dependencies:
```bash
flutter pub upgrade --major-versions
```

### Build Errors
Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

### Android Emulator Issues
Start emulator manually:
```bash
flutter emulators --launch <emulator_id>
```

### iOS Simulator Issues (macOS only)
```bash
open -a Simulator
```

---

## Testing the App

### Default Login
You'll need to create an admin user in your Cloudflare D1 database:
```sql
INSERT INTO users (email, password_hash, role)
VALUES ('admin@example.com', '$2a$10$hash...', 'admin');
```

Use bcrypt to hash passwords.

### Features to Test
1. Login with admin credentials
2. View empty contacts list
3. Add a new contact
4. Edit/delete contacts (only your own, unless admin)
5. Navigate to call logs (will be empty until calls are logged)
6. Admin panel - create/delete users
7. Logout and login as different user

---

## Project Architecture

### State Management: Provider
- `AuthProvider` - Manages login state, current user
- `ContactProvider` - Manages contact list, CRUD operations

### API Client: Dio
- Automatic JWT token injection via interceptor
- Error handling with user-friendly messages
- Secure token storage with flutter_secure_storage

### Navigation: Named Routes
- `/` - Auth gate (checks login status)
- `/login` - Login screen
- `/contacts` - Main contacts screen
- `/calls` - Call logs screen
- `/admin` - Admin panel (requires admin role)

---

## Next Development Steps

1. **Backend Setup**: Deploy Cloudflare Worker with D1 database
2. **Call Detection**: Implement phone state listener for automatic call logging (Android)
3. **Offline Support**: Add local database sync with sqflite
4. **Push Notifications**: Notify users of contact changes
5. **Testing**: Write unit and integration tests
6. **CI/CD**: Set up automated builds

---

## Support

For Flutter issues: https://flutter.dev/docs
For project issues: See README.md

---

**Status**: Ready for `flutter create` and `flutter pub get`



flutter build apk --debug

flutter build apk --release
