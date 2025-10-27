# Cloudflare Backend - Deployment Summary

## ✅ Completed Setup Steps

1. **D1 Database Created**
   - Name: `contacts_crm`
   - Database ID: `2a87cbe2-52cf-4f35-8187-2b01044ea424`
   - Region: EEUR (Europe)

2. **Database Schema Applied**
   - Tables: users, contacts, calls
   - Indexes created for performance

3. **Test Users Seeded**
   - Admin and regular user accounts created

4. **Worker Code Created**
   - Full REST API with authentication
   - CORS enabled
   - JWT token-based auth

5. **Project Files**
   - Location: `/Users/alib/crm/crm_backend/`
   - wrangler.toml configured
   - Worker source code in `src/index.js`

---

## 🔐 Test Credentials

### Admin Account
- **Email:** `admin@example.com`
- **Password:** `admin123`
- **Role:** admin
- **Permissions:** Full access to all contacts, can create/delete users

### Regular User Account
- **Email:** `user@example.com`
- **Password:** `user123`
- **Role:** user
- **Permissions:** View all contacts, edit only own contacts

---

## 📋 Next Steps

### 1. Register Workers.dev Subdomain

**Action Required:** Visit this URL to register your workers.dev subdomain:

https://dash.cloudflare.com/94c365af32be5e5d043932a0f7eaa952/workers/onboarding

This is a one-time setup. Choose a subdomain name (e.g., `mycrm.workers.dev`).

### 2. Deploy the Worker

After registering your subdomain, run:

```bash
cd /Users/alib/crm/crm_backend
wrangler deploy
```

This will output your Worker URL, something like:
```
https://shared-contact-crm.your-subdomain.workers.dev
```

**Save this URL!** You'll need it for the Flutter app.

### 3. Test the API

Once deployed, test the login endpoint:

```bash
# Replace YOUR_WORKER_URL with your actual Worker URL
curl -X POST https://YOUR_WORKER_URL/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}'
```

Expected response:
```json
{
  "token": "eyJ...",
  "user": {
    "id": 1,
    "email": "admin@example.com",
    "role": "admin",
    "created_at": "2024-..."
  }
}
```

### 4. Test Other Endpoints

```bash
# Save the token from login
TOKEN="your-token-here"

# Get contacts (should be empty initially)
curl https://YOUR_WORKER_URL/contacts \
  -H "Authorization: Bearer $TOKEN"

# Create a contact
curl -X POST https://YOUR_WORKER_URL/contacts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","phone_number":"+1234567890"}'

# List contacts again (should see John Doe)
curl https://YOUR_WORKER_URL/contacts \
  -H "Authorization: Bearer $TOKEN"
```

### 5. Update Flutter App

Edit `/Users/alib/crm/shared_contact_crm/lib/api/api_client.dart`:

```dart
static const String baseUrl = 'https://YOUR_WORKER_URL';
```

Replace `YOUR_WORKER_URL` with your actual Worker URL from step 2.

### 6. Run Flutter App

```bash
cd /Users/alib/crm/shared_contact_crm
flutter run
```

Login with:
- Email: `admin@example.com`
- Password: `admin123`

---

## 🎯 Available API Endpoints

### Public Endpoints
- `POST /login` - User authentication

### Authenticated Endpoints (require JWT token)
- `GET /contacts` - List all contacts
- `POST /contacts` - Create new contact
- `PUT /contacts/:id` - Update contact
- `DELETE /contacts/:id` - Delete contact
- `GET /calls` - List call logs
- `POST /calls` - Create call log

### Admin-Only Endpoints
- `GET /admin/users` - List all users
- `POST /admin/users` - Create new user
- `DELETE /admin/users/:id` - Delete user

---

## 🛠️ Useful Commands

### View Database Contents
```bash
# List all users
wrangler d1 execute contacts_crm --remote \
  --command "SELECT id, email, role, created_at FROM users;"

# List all contacts
wrangler d1 execute contacts_crm --remote \
  --command "SELECT * FROM contacts;"

# Count records
wrangler d1 execute contacts_crm --remote \
  --command "SELECT 'users' as table_name, COUNT(*) as count FROM users UNION ALL SELECT 'contacts', COUNT(*) FROM contacts;"
```

### View Worker Logs
```bash
wrangler tail
```

### Re-deploy After Changes
```bash
wrangler deploy
```

### Test Locally (Development Mode)
```bash
wrangler dev
# Access at http://localhost:8787
```

---

## 🔧 Troubleshooting

### Worker Not Deploying
1. Make sure you've registered a workers.dev subdomain
2. Check you're logged in: `wrangler whoami`
3. Verify wrangler.toml exists and is correct

### Database Connection Issues
- Verify database ID in wrangler.toml matches: `2a87cbe2-52cf-4f35-8187-2b01044ea424`
- Check binding name is `DB` (matches code)

### Authentication Errors
- Verify JWT_SECRET is set in wrangler.toml
- Check token is included in Authorization header: `Bearer <token>`
- Token format: `Authorization: Bearer <token>`

### CORS Errors
- CORS is enabled for all origins (`*`)
- Check browser console for specific CORS errors
- Verify request includes proper Content-Type header

---

## 📊 Database Schema

### users table
- id (INTEGER, PRIMARY KEY)
- email (TEXT, UNIQUE)
- password_hash (TEXT)
- role (TEXT: 'admin' | 'user')
- created_at (DATETIME)

### contacts table
- id (INTEGER, PRIMARY KEY)
- name (TEXT)
- phone_number (TEXT, UNIQUE)
- created_by_user_id (INTEGER, FK to users)
- created_at (DATETIME)
- updated_at (DATETIME)

### calls table
- id (INTEGER, PRIMARY KEY)
- contact_id (INTEGER, FK to contacts)
- user_id (INTEGER, FK to users)
- phone_number (TEXT)
- direction (TEXT: 'incoming' | 'outgoing')
- start_time (DATETIME)
- duration (INTEGER, seconds)

---

## 🔒 Security Notes

### Change in Production
1. **JWT_SECRET**: Generate a strong random secret
   ```bash
   wrangler secret put JWT_SECRET
   # Enter a strong random string when prompted
   ```

2. **Admin Password**: Change immediately after first login
   - Login as admin
   - Use admin panel to create new admin user
   - Delete old admin account

3. **CORS**: Restrict to your domain
   ```javascript
   // In src/index.js
   cors({
     origin: 'https://yourdomain.com',
     // ... other settings
   })
   ```

---

## 📱 Flutter App Configuration

After deployment, update these files:

### lib/api/api_client.dart
```dart
static const String baseUrl = 'https://shared-contact-crm.your-subdomain.workers.dev';
```

### Build Android APK
```bash
cd /Users/alib/crm/shared_contact_crm
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

---

## ✅ Quick Deployment Checklist

- [ ] Register workers.dev subdomain
- [ ] Run `wrangler deploy`
- [ ] Save Worker URL
- [ ] Test `/login` endpoint with curl
- [ ] Test `/contacts` endpoint with curl
- [ ] Update Flutter app with Worker URL
- [ ] Run Flutter app
- [ ] Login with admin@example.com / admin123
- [ ] Add test contact
- [ ] Build Android APK
- [ ] Install on device

---

## 📁 Project Structure

```
/Users/alib/crm/crm_backend/
├── src/
│   └── index.js           # Worker API code
├── wrangler.toml          # Cloudflare configuration
├── package.json           # Node dependencies
├── schema.sql             # Database schema
├── seed.sql               # Test user data
└── generate-hash.js       # Password hash generator

/Users/alib/crm/shared_contact_crm/
└── [Flutter app files]
```

---

**Status:** Backend configured and ready to deploy!
**Next:** Register workers.dev subdomain and run `wrangler deploy`
