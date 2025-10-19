Excellent — let’s now **split the Flutter + Cloudflare D1 version** into two distinct deliverables:

1. **Backend (Cloudflare Worker + D1)** → handles authentication, users, contacts, calls, and admin logic.
2. **Frontend (Flutter App)** → UI for login, contact list, call logs, and user management.

Below is a **clear, production-style specification for both sides**, including their structures, endpoints, and integration model.

---

# 🧩 PART 1 — Backend (Cloudflare Worker + D1)

### Overview

A lightweight REST API that provides:

* JWT-based authentication
* User and admin management
* Contacts CRUD
* Call log storage
* Role-based access control
* No public signup (admin only can create users)

---

## 🔧 Stack

* **Runtime:** Cloudflare Workers
* **Database:** Cloudflare D1 (SQLite)
* **Auth:** JWT (HS256)
* **Password Hashing:** bcrypt (via `bcryptjs` or compatible lib)

---

## ⚙️ Worker Directory Structure

```
backend/
 ├─ wrangler.toml
 ├─ src/
 │   ├─ index.js               # main entry
 │   ├─ routes/
 │   │   ├─ auth.js
 │   │   ├─ contacts.js
 │   │   ├─ calls.js
 │   │   └─ admin.js
 │   ├─ utils/
 │   │   ├─ jwt.js
 │   │   ├─ db.js
 │   │   └─ hash.js
 │   ├─ middleware/
 │   │   ├─ authMiddleware.js
 │   │   └─ adminMiddleware.js
 │   └─ schema.sql
 └─ package.json
```

---

## 🗄️ Database Schema (D1)

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('admin','user')) DEFAULT 'user',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone_number TEXT UNIQUE NOT NULL,
  created_by_user_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

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
```

---

## 🔑 Auth Flow

1. **Login**:
   `POST /login`

   * Checks email/password against `users` table.
   * If valid → returns JWT with `{ user_id, role }`.

2. **JWT Middleware**:

   * Reads `Authorization: Bearer <token>` header.
   * Verifies and attaches user to request context.

---

## 🧭 REST API Endpoints

| Method | Endpoint           | Description                        | Auth   |
| ------ | ------------------ | ---------------------------------- | ------ |
| POST   | `/login`           | User login → returns JWT           | Public |
| GET    | `/contacts`        | List all contacts                  | JWT    |
| POST   | `/contacts`        | Add new contact                    | JWT    |
| PUT    | `/contacts/:id`    | Edit contact (only own or admin)   | JWT    |
| DELETE | `/contacts/:id`    | Delete contact (only own or admin) | JWT    |
| GET    | `/calls`           | List all calls                     | JWT    |
| POST   | `/calls`           | Add call log                       | JWT    |
| POST   | `/admin/users`     | Create new user                    | Admin  |
| DELETE | `/admin/users/:id` | Remove user                        | Admin  |

---

## 🧠 Example Worker Endpoint (auth.js)

```js
import { signJWT, verifyPassword } from '../utils/jwt.js';

export async function login(req, env) {
  const { email, password } = await req.json();
  const user = await env.DB.prepare(`SELECT * FROM users WHERE email=?`).bind(email).first();
  if (!user) return new Response('Invalid credentials', { status: 401 });

  const ok = await verifyPassword(password, user.password_hash);
  if (!ok) return new Response('Invalid credentials', { status: 401 });

  const token = await signJWT({ id: user.id, role: user.role }, env.JWT_SECRET);
  return Response.json({ token, role: user.role });
}
```

---

## 🔐 Environment Variables

```toml
[vars]
JWT_SECRET = "supersecretkey"
ADMIN_EMAIL = "admin@crm.local"
ADMIN_PASSWORD = "Admin@1234"
```
### ✅ Updates for Sync Support

#### Add version columns

```sql
ALTER TABLE contacts ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE calls ADD COLUMN version INTEGER DEFAULT 1;
```

Each update increments version → used for conflict resolution.
Older record always wins when duplicate numbers appear across users.

#### Conflict policy

* Unique constraint on `phone_number`.
* When insert/update conflict → keep the **older record** (`created_at` ascending).
  Implement with `ON CONFLICT (phone_number) DO NOTHING;` for inserts.

#### API updates

| Method | Endpoint                           | Description                          |
| ------ | ---------------------------------- | ------------------------------------ |
| GET    | `/sync/contacts?since=<timestamp>` | Get updated contacts since timestamp |
| POST   | `/sync/contacts`                   | Push new/updated contacts            |
| GET    | `/sync/calls?since=<timestamp>`    | Get updated calls                    |
| POST   | `/sync/calls`                      | Push new/updated calls               |

---
