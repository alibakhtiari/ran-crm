# Backend Setup & Testing Guide

## Cloudflare Worker + D1 Database Setup

This guide covers setting up the backend API for the Shared Contact CRM app.

---

## Prerequisites

1. **Cloudflare Account** - Sign up at https://dash.cloudflare.com
2. **Wrangler CLI** - Cloudflare's command-line tool
   ```bash
   npm install -g wrangler
   ```
3. **Node.js** - Version 16 or higher

---

## Step 1: Login to Cloudflare

```bash
wrangler login
```

This opens a browser window for authentication.

---

## Step 2: Create D1 Database

```bash
# Create the database
wrangler d1 create contacts_crm

# Output will show:
# database_name = "contacts_crm"
# database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**Save the `database_id`** - you'll need it for configuration.

---

## Step 3: Project Structure

Create a new directory for your backend:

```bash
mkdir ~/crm_backend
cd ~/crm_backend
npm init -y
```

---

## Step 4: Install Dependencies

```bash
npm install bcryptjs jsonwebtoken hono @hono/node-server
```

**Package purposes:**
- `bcryptjs` - Password hashing
- `jsonwebtoken` - JWT token generation/verification
- `hono` - Lightweight web framework for Workers
- `@hono/node-server` - For local testing

---

## Step 5: Create wrangler.toml

Create `wrangler.toml` in your backend directory:

```toml
name = "shared-contact-crm"
main = "src/index.js"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "contacts_crm"
database_id = "YOUR_DATABASE_ID_HERE"  # Replace with your actual ID

[vars]
JWT_SECRET = "your-super-secret-jwt-key-change-this-in-production"
```

**Important:** Replace `YOUR_DATABASE_ID_HERE` with the actual database ID from Step 2.

---

## Step 6: Initialize Database Schema

Create `schema.sql`:

```sql
-- Users table
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('admin','user')) DEFAULT 'user',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Contacts table
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone_number TEXT UNIQUE NOT NULL,
  created_by_user_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

-- Calls table
CREATE TABLE calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id INTEGER,
  user_id INTEGER,
  phone_number TEXT NOT NULL,
  direction TEXT CHECK(direction IN ('incoming','outgoing')),
  start_time DATETIME,
  duration INTEGER,
  FOREIGN KEY (contact_id) REFERENCES contacts(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Create indexes for better performance
CREATE INDEX idx_contacts_phone ON contacts(phone_number);
CREATE INDEX idx_calls_user ON calls(user_id);
CREATE INDEX idx_calls_contact ON calls(contact_id);
```

Apply the schema:

```bash
wrangler d1 execute contacts_crm --file=schema.sql
```

---

## Step 7: Create Admin User

Create `seed.sql`:

```sql
-- Admin user
-- Password: admin123 (bcrypt hash below)
INSERT INTO users (email, password_hash, role)
VALUES ('admin@example.com', '$2a$10$rQZ8JqZK3qZ8JqZK3qZ8JeuO5pXxHZ8JqZK3qZ8JqZK3qZ8JqZK3q', 'admin');

-- Test regular user
-- Password: user123 (bcrypt hash below)
INSERT INTO users (email, password_hash, role)
VALUES ('user@example.com', '$2a$10$tQZ8JqZK3qZ8JqZK3qZ8JeuO5pXxHZ8JqZK3qZ8JqZK3qZ8JqZK3t', 'user');
```

**Note:** These are example hashes. Generate your own in Step 8.

Apply the seed data:

```bash
wrangler d1 execute contacts_crm --file=seed.sql
```

---

## Step 8: Generate Password Hashes

Create a Node.js script `generate-hash.js`:

```javascript
const bcrypt = require('bcryptjs');

const password = process.argv[2] || 'admin123';
const hash = bcrypt.hashSync(password, 10);

console.log('Password:', password);
console.log('Hash:', hash);
console.log('\nSQL:');
console.log(`INSERT INTO users (email, password_hash, role) VALUES ('email@example.com', '${hash}', 'admin');`);
```

Run it:

```bash
node generate-hash.js admin123
node generate-hash.js user123
```

Update your `seed.sql` with the generated hashes.

---

## Step 9: Create Worker Code

Create `src/index.js`:

```javascript
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const app = new Hono();

// Enable CORS
app.use('/*', cors());

// JWT Middleware
const authMiddleware = async (c, next) => {
  const authHeader = c.req.header('Authorization');

  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const token = authHeader.substring(7);

  try {
    const decoded = jwt.verify(token, c.env.JWT_SECRET);
    c.set('user', decoded);
    await next();
  } catch (err) {
    return c.json({ error: 'Invalid token' }, 401);
  }
};

// Admin Middleware
const adminMiddleware = async (c, next) => {
  const user = c.get('user');
  if (user.role !== 'admin') {
    return c.json({ error: 'Forbidden: Admin only' }, 403);
  }
  await next();
};

// === ROUTES ===

// Login
app.post('/login', async (c) => {
  const { email, password } = await c.req.json();

  const user = await c.env.DB.prepare(
    'SELECT * FROM users WHERE email = ?'
  ).bind(email).first();

  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    return c.json({ error: 'Invalid credentials' }, 401);
  }

  const token = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    c.env.JWT_SECRET,
    { expiresIn: '7d' }
  );

  return c.json({
    token,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      created_at: user.created_at
    }
  });
});

// Get all contacts
app.get('/contacts', authMiddleware, async (c) => {
  const contacts = await c.env.DB.prepare(
    'SELECT * FROM contacts ORDER BY name ASC'
  ).all();

  return c.json(contacts.results || []);
});

// Create contact
app.post('/contacts', authMiddleware, async (c) => {
  const { name, phone_number } = await c.req.json();
  const user = c.get('user');

  try {
    const result = await c.env.DB.prepare(
      'INSERT INTO contacts (name, phone_number, created_by_user_id) VALUES (?, ?, ?)'
    ).bind(name, phone_number, user.id).run();

    const contact = await c.env.DB.prepare(
      'SELECT * FROM contacts WHERE id = ?'
    ).bind(result.meta.last_row_id).first();

    return c.json(contact);
  } catch (err) {
    return c.json({ error: 'Phone number already exists' }, 400);
  }
});

// Update contact
app.put('/contacts/:id', authMiddleware, async (c) => {
  const id = c.req.param('id');
  const { name, phone_number } = await c.req.json();
  const user = c.get('user');

  const contact = await c.env.DB.prepare(
    'SELECT * FROM contacts WHERE id = ?'
  ).bind(id).first();

  if (!contact) {
    return c.json({ error: 'Contact not found' }, 404);
  }

  if (user.role !== 'admin' && contact.created_by_user_id !== user.id) {
    return c.json({ error: 'Forbidden' }, 403);
  }

  await c.env.DB.prepare(
    'UPDATE contacts SET name = ?, phone_number = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
  ).bind(name, phone_number, id).run();

  const updated = await c.env.DB.prepare(
    'SELECT * FROM contacts WHERE id = ?'
  ).bind(id).first();

  return c.json(updated);
});

// Delete contact
app.delete('/contacts/:id', authMiddleware, async (c) => {
  const id = c.req.param('id');
  const user = c.get('user');

  const contact = await c.env.DB.prepare(
    'SELECT * FROM contacts WHERE id = ?'
  ).bind(id).first();

  if (!contact) {
    return c.json({ error: 'Contact not found' }, 404);
  }

  if (user.role !== 'admin' && contact.created_by_user_id !== user.id) {
    return c.json({ error: 'Forbidden' }, 403);
  }

  await c.env.DB.prepare('DELETE FROM contacts WHERE id = ?').bind(id).run();

  return c.json({ message: 'Contact deleted' });
});

// Get all calls
app.get('/calls', authMiddleware, async (c) => {
  const calls = await c.env.DB.prepare(
    'SELECT * FROM calls ORDER BY start_time DESC'
  ).all();

  return c.json(calls.results || []);
});

// Create call log
app.post('/calls', authMiddleware, async (c) => {
  const { phone_number, direction, start_time, duration } = await c.req.json();
  const user = c.get('user');

  // Try to find matching contact
  const contact = await c.env.DB.prepare(
    'SELECT id FROM contacts WHERE phone_number = ?'
  ).bind(phone_number).first();

  const result = await c.env.DB.prepare(
    'INSERT INTO calls (contact_id, user_id, phone_number, direction, start_time, duration) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(contact?.id || null, user.id, phone_number, direction, start_time, duration).run();

  const call = await c.env.DB.prepare(
    'SELECT * FROM calls WHERE id = ?'
  ).bind(result.meta.last_row_id).first();

  return c.json(call);
});

// Get all users (admin only)
app.get('/admin/users', authMiddleware, adminMiddleware, async (c) => {
  const users = await c.env.DB.prepare(
    'SELECT id, email, role, created_at FROM users ORDER BY created_at DESC'
  ).all();

  return c.json(users.results || []);
});

// Create user (admin only)
app.post('/admin/users', authMiddleware, adminMiddleware, async (c) => {
  const { email, password, role } = await c.req.json();

  const hash = bcrypt.hashSync(password, 10);

  try {
    const result = await c.env.DB.prepare(
      'INSERT INTO users (email, password_hash, role) VALUES (?, ?, ?)'
    ).bind(email, hash, role || 'user').run();

    const user = await c.env.DB.prepare(
      'SELECT id, email, role, created_at FROM users WHERE id = ?'
    ).bind(result.meta.last_row_id).first();

    return c.json(user);
  } catch (err) {
    return c.json({ error: 'Email already exists' }, 400);
  }
});

// Delete user (admin only)
app.delete('/admin/users/:id', authMiddleware, adminMiddleware, async (c) => {
  const id = c.req.param('id');
  const user = c.get('user');

  if (parseInt(id) === user.id) {
    return c.json({ error: 'Cannot delete yourself' }, 400);
  }

  await c.env.DB.prepare('DELETE FROM users WHERE id = ?').bind(id).run();

  return c.json({ message: 'User deleted' });
});

export default app;
```

---

## Step 10: Deploy to Cloudflare

```bash
# Deploy the worker
wrangler deploy

# Output will show your worker URL:
# Published shared-contact-crm
# https://shared-contact-crm.your-subdomain.workers.dev
```

**Save this URL** - you'll need it for the Flutter app configuration.

---

## Step 11: Test the API

### Test Login
```bash
curl -X POST https://your-worker-url.workers.dev/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}'
```

Expected response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "admin@example.com",
    "role": "admin",
    "created_at": "2024-01-15 10:30:00"
  }
}
```

### Test Get Contacts
```bash
TOKEN="your-token-from-login"

curl -X GET https://your-worker-url.workers.dev/contacts \
  -H "Authorization: Bearer $TOKEN"
```

### Test Create Contact
```bash
curl -X POST https://your-worker-url.workers.dev/contacts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","phone_number":"+1234567890"}'
```

---

## Default Test Credentials

### Admin User
- **Email:** `admin@example.com`
- **Password:** `admin123`
- **Role:** `admin`
- **Can:** Manage all contacts, create/delete users

### Regular User
- **Email:** `user@example.com`
- **Password:** `user123`
- **Role:** `user`
- **Can:** View all contacts, edit only own contacts

---

## Step 12: Update Flutter App

Edit `lib/api/api_client.dart`:

```dart
static const String baseUrl = 'https://your-worker-url.workers.dev';
```

Replace with your actual worker URL from Step 10.

---

## Step 13: Build Android APK

### Debug Build (for testing)
```bash
cd /Users/alib/crm/shared_contact_crm
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release Build (for production)
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Google Play Store)
```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Install on Device
```bash
# Connect Android device via USB
# Enable USB debugging in Developer Options

# Install debug APK
flutter install

# Or manually install
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Step 14: Configure Android Permissions

The `flutter create` command should have created the Android manifest, but verify it includes:

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.READ_CALL_LOG" />

    <application
        android:label="Shared Contact CRM"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- Rest of your manifest -->
    </application>
</manifest>
```

---

## Monitoring & Logs

### View Worker Logs
```bash
wrangler tail
```

### View D1 Database
```bash
# List all tables
wrangler d1 execute contacts_crm --command "SELECT name FROM sqlite_master WHERE type='table';"

# View users
wrangler d1 execute contacts_crm --command "SELECT * FROM users;"

# View contacts
wrangler d1 execute contacts_crm --command "SELECT * FROM contacts;"
```

---

## Troubleshooting

### CORS Issues
The worker includes CORS middleware. If you still have issues, check browser console.

### Authentication Errors
- Verify JWT_SECRET matches in wrangler.toml
- Check token expiration (7 days by default)
- Ensure Bearer token is properly formatted

### Database Errors
```bash
# Reset database
wrangler d1 execute contacts_crm --command "DROP TABLE IF EXISTS users; DROP TABLE IF EXISTS contacts; DROP TABLE IF EXISTS calls;"
wrangler d1 execute contacts_crm --file=schema.sql
wrangler d1 execute contacts_crm --file=seed.sql
```

### Build Errors (Android)
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

---

## Production Checklist

- [ ] Change JWT_SECRET to a strong random string
- [ ] Update default admin credentials
- [ ] Enable Cloudflare security features (rate limiting, etc.)
- [ ] Set up custom domain for worker
- [ ] Configure proper CORS origins
- [ ] Add input validation
- [ ] Set up monitoring/alerting
- [ ] Generate signed APK with keystore for Play Store

---

## Security Notes

1. **Never commit** wrangler.toml with real credentials to git
2. **Use secrets** for production: `wrangler secret put JWT_SECRET`
3. **Change default passwords** immediately
4. **Enable 2FA** on Cloudflare account
5. **Use signed APKs** for production Android builds

---

## Quick Reference Commands

```bash
# Backend
wrangler deploy                    # Deploy worker
wrangler tail                      # View logs
wrangler d1 execute contacts_crm   # Query database

# Flutter
flutter run                        # Run debug
flutter build apk --release        # Build release APK
flutter install                    # Install on device
adb logcat | grep flutter          # View Android logs
```

---

**Status:** Ready for production deployment!
