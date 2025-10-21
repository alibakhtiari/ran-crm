# Background Sync Implementation

## Overview
The RAN CRM app now includes automatic background synchronization that runs even when the app is closed. This ensures your contacts and call logs stay synced across all devices automatically.

## Features

### ✅ Automatic Background Sync
- **Periodic Sync**: Runs every hour automatically
- **Two-Way Contact Sync**: Syncs contacts between phone and server
- **Call Log Sync**: Uploads call logs from phone to server
- **Network-Aware**: Only syncs when internet connection is available
- **Battery-Efficient**: Uses Android WorkManager for optimal battery usage

### ✅ Manual Sync Options
- **Settings Screen**: Enable/disable background sync
- **Sync Now Button**: Trigger immediate sync from settings or contacts screen
- **Call Logs Screen**: Direct sync button for call logs

## How It Works

### 1. **On Login**
When a user logs in, the app:
- Stores user credentials securely
- Registers periodic background sync (every 1 hour)
- Initializes WorkManager for background tasks

### 2. **Background Sync Process**
Every hour, the background service:
1. Checks if user is authenticated
2. Syncs contacts from phone → server
3. Syncs contacts from server → phone
4. Syncs call logs from phone → server
5. Shows success/failure logs in device logs

### 3. **On Logout**
When a user logs out:
- Cancels all background sync tasks
- Clears stored credentials
- Removes account from Android system

## File Structure

```
lib/
├── services/
│   ├── background_sync_service.dart    # Main background sync logic
│   ├── contact_sync_service.dart       # Contact synchronization
│   ├── call_log_sync_service.dart      # Call log synchronization
│   └── account_sync_service.dart       # Android account management
├── screens/
│   ├── settings_screen.dart            # Sync settings UI
│   ├── contacts_screen.dart            # Contact management with sync
│   └── call_logs_screen.dart           # Call logs with sync button
└── providers/
    └── auth_provider.dart              # Authentication with sync setup
```

## Permissions Required

The app requires these Android permissions for background sync:

### Core Permissions
- `INTERNET` - To communicate with the server
- `READ_CONTACTS` - To read phone contacts
- `WRITE_CONTACTS` - To write synced contacts to phone
- `READ_CALL_LOG` - To read call logs
- `READ_PHONE_STATE` - To access phone state for call logs

### Background Work Permissions
- `WAKE_LOCK` - To wake device for sync tasks
- `RECEIVE_BOOT_COMPLETED` - To restart sync after device reboot
- `FOREGROUND_SERVICE` - For foreground services (if needed)

### Android Account Permissions
- `AUTHENTICATE_ACCOUNTS` - For Android account integration
- `GET_ACCOUNTS` - To get system accounts
- `MANAGE_ACCOUNTS` - To manage user accounts
- `WRITE_SYNC_SETTINGS` - To configure sync settings
- `READ_SYNC_SETTINGS` - To read sync configuration

## User Guide

### Enabling Background Sync

1. **Login to the app**
   - Background sync is automatically enabled after login

2. **Configure Sync Settings**
   - Open Settings (gear icon in Contacts screen)
   - Toggle "Background Sync" on/off
   - View sync status and information

3. **Manual Sync**
   - Tap "Sync Now" in Settings
   - Or use the sync button in Contacts screen
   - Or use the sync button in Call Logs screen

### Monitoring Sync

To monitor background sync:
1. Check device logs with `adb logcat | grep "Background sync"`
2. Look for these messages:
   - `📱 Background sync task started`
   - `✅ Contacts synced`
   - `✅ Call logs synced`
   - `✅ Background sync completed successfully`

### Troubleshooting

**Background sync not working?**
- Check if user is logged in
- Verify internet connection
- Check if background sync is enabled in Settings
- Ensure all required permissions are granted
- Check device battery optimization settings (may need to disable for this app)

**Data not syncing?**
- Manually trigger sync from Settings
- Check server connectivity
- Verify credentials are valid
- Check logs for specific error messages

## Technical Details

### WorkManager Configuration
- **Frequency**: 1 hour (minimum for periodic tasks)
- **Network Constraint**: Requires connected network
- **Backoff Policy**: Exponential with 5-minute delay
- **Existing Work Policy**: Replace (updates existing tasks)

### Sync Strategy
1. **Contacts to Server**:
   - Reads all phone contacts
   - Uploads new contacts to server
   - Skips duplicates (by phone number)

2. **Contacts to Phone**:
   - Fetches all contacts from server
   - Creates contacts on phone if not exists
   - Skips duplicates (by phone number)

3. **Call Logs to Server**:
   - Reads last 30 days of call logs
   - Uploads incoming/outgoing calls only
   - Skips missed/rejected calls
   - Skips duplicates on server

### Background Task Lifecycle
```
Login
  ↓
Initialize WorkManager
  ↓
Register Periodic Task
  ↓
[Every Hour]
  ↓
Execute Sync
  ↓
Log Results
  ↓
Schedule Next Run
```

### Data Flow
```
Phone Contacts ←→ Server ←→ Other Devices
Phone Call Logs → Server (one-way)
```

## API Integration

The background sync uses these API endpoints:
- `POST /contacts` - Create contact
- `GET /contacts` - Get all contacts
- `POST /calls` - Create call log
- `GET /calls` - Get all call logs

All API calls use JWT authentication stored in FlutterSecureStorage.

## Future Enhancements

Potential improvements:
- [ ] Configurable sync interval (15 min, 30 min, 1 hour, etc.)
- [ ] Sync only on WiFi option
- [ ] Sync status notifications
- [ ] Conflict resolution UI
- [ ] Selective sync (choose which contacts to sync)
- [ ] Sync statistics dashboard
- [ ] Manual conflict resolution
- [ ] Export/import sync logs

## Notes

- Background sync only works on Android (uses Android WorkManager)
- iOS would require different implementation (Background Fetch or Silent Push Notifications)
- Sync interval minimum is 15 minutes on Android 12+
- Battery optimization may affect sync reliability
- Users should whitelist the app from battery optimization for best results
