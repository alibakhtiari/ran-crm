# Quick Start Guide - Background Sync

## How to Test Background Sync

### 1. Run the App
```bash
flutter run
```

### 2. Login
- Use your credentials (e.g., admin@example.com / admin123)
- Background sync will automatically register on login
- Look for: `✅ Background sync registered successfully`

### 3. Enable/Disable Background Sync

**Via Settings Screen:**
1. Go to Contacts screen
2. Tap the Settings icon (gear) in the app bar
3. Toggle "Background Sync" on/off
4. You'll see a confirmation message

### 4. Manual Sync

**Option 1 - From Settings:**
1. Go to Settings screen
2. Tap "Sync Now"
3. Wait for sync to complete
4. Check the result message

**Option 2 - From Contacts:**
1. Go to Contacts screen
2. Tap the menu (three dots)
3. Select "Sync Phone Data"
4. Wait for sync dialog to complete

**Option 3 - From Call Logs:**
1. Go to Call Logs screen
2. Tap the Sync button in the app bar
3. Grant phone permission if requested
4. Wait for sync to complete

### 5. Monitor Background Sync

**View Logs (Android):**
```bash
# Monitor all background sync activity
adb logcat | grep -E "Background sync|📱|✅|❌"

# Filter for sync results only
adb logcat | grep "Background sync"
```

**Expected Log Output:**
```
📱 Background sync task started: com.crm.ran_crm.sync
🔄 Starting contact sync...
✅ Contacts to server: Total: 50, Synced: 5, Skipped: 45, Errors: 0
✅ Contacts to phone: Total: 100, Synced: 10, Skipped: 90, Errors: 0
📞 Starting call log sync...
✅ Call logs synced: Total: 25, Synced: 3, Skipped: 22, Errors: 0
✅ Background sync completed successfully
```

### 6. Test Automatic Sync

**Method 1 - Wait for Periodic Sync:**
- Background sync runs every hour
- No action needed, just wait
- Check logs after 1 hour

**Method 2 - Trigger Immediate Test (Development):**

For testing, you can reduce the sync interval temporarily:

Edit `lib/services/background_sync_service.dart`:
```dart
// Change from 1 hour to 15 minutes (minimum allowed)
static const Duration syncInterval = Duration(minutes: 15);
```

Then:
1. Logout and login again
2. Wait 15 minutes
3. Check logs for automatic sync

### 7. Verify Sync Results

**Check Contacts:**
1. Add a contact on your phone
2. Wait for background sync (or trigger manual sync)
3. Check the Contacts screen - new contact should appear
4. Check on another device - contact should sync there too

**Check Call Logs:**
1. Make or receive a phone call
2. Wait for background sync (or trigger manual sync)
3. Go to Call Logs screen
4. Tap refresh - new call log should appear

### 8. Test Between Devices

**Setup:**
1. Install app on Device A and Device B
2. Login with same account on both devices
3. Enable background sync on both

**Test Flow:**
```
Device A: Add contact "John Doe"
   ↓
Wait for sync (1 hour) or trigger manual sync
   ↓
Server: Receives contact
   ↓
Device B: Background sync runs
   ↓
Device B: Contact "John Doe" appears
```

### 9. Troubleshooting

**Sync not working?**

1. **Check authentication:**
   ```bash
   adb logcat | grep "No auth token"
   ```
   → If you see this, logout and login again

2. **Check permissions:**
   - Go to Android Settings → Apps → RAN CRM → Permissions
   - Ensure Contacts and Phone are allowed

3. **Check network:**
   ```bash
   adb logcat | grep "Network error"
   ```
   → Ensure device has internet connection

4. **Check battery optimization:**
   - Go to Android Settings → Battery → Battery optimization
   - Find RAN CRM and set to "Don't optimize"

5. **Force sync:**
   - Go to Settings screen
   - Tap "Sync Now"
   - Check the error message if it fails

6. **View detailed errors:**
   ```bash
   adb logcat | grep -E "sync error|sync failed"
   ```

### 10. Testing Checklist

- [ ] Login works and registers background sync
- [ ] Manual sync from Settings works
- [ ] Manual sync from Contacts screen works
- [ ] Manual sync from Call Logs screen works
- [ ] Background sync toggle in Settings works
- [ ] Contacts sync from phone to server
- [ ] Contacts sync from server to phone
- [ ] Call logs sync from phone to server
- [ ] Sync works between multiple devices
- [ ] Sync runs automatically every hour
- [ ] Logout cancels background sync
- [ ] Sync respects network requirements
- [ ] Error messages display properly
- [ ] Success messages display properly

## Common Commands

```bash
# Install and run app
flutter run

# Watch logs in real-time
adb logcat | grep "Background sync"

# Trigger sync manually via command line (if testing)
adb shell am broadcast -a android.intent.action.RUN -n com.crm.ran_crm

# Check WorkManager tasks
adb shell dumpsys jobscheduler | grep ran_crm

# Clear app data (reset)
adb shell pm clear com.crm.ran_crm

# Restart app
adb shell am force-stop com.crm.ran_crm
adb shell am start -n com.crm.ran_crm/.MainActivity
```

## Performance Notes

- First sync may take longer (syncing all contacts/calls)
- Subsequent syncs are faster (only new data)
- Sync skips duplicates automatically
- Large contact lists (1000+) may take 30-60 seconds
- Call logs limited to last 30 days

## Next Steps

After testing basic functionality:
1. Test with real phone contacts
2. Test with real call logs
3. Test on different Android versions
4. Test with poor network conditions
5. Test battery impact over 24 hours
6. Test sync reliability over multiple days
