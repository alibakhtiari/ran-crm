// === file: wrangler.toml ===
name = "contacts-crm-backend"
main = "src/index.js"
compatibility_date = "2025-10-19"

[[d1_databases]]
binding = "DB"
database_name = "contacts_crm"
database_id = "YOUR_D1_DATABASE_ID"

[vars]
JWT_SECRET = "__REPLACE_WITH_STRONG_SECRET__"
SEED_ADMIN_EMAIL = "admin@crm.local"
SEED_ADMIN_PASSWORD = "Admin@1234"

// === file: package.json ===
{
  "name": "contacts-crm-backend",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "jose": "^4.15.4"
  },
  "devDependencies": {}
}

// === file: src/schema.sql ===
-- run this schema to initialize D1 (or use migrations)
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('admin','user')) DEFAULT 'user',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone_number TEXT UNIQUE NOT NULL,
  created_by_user_id INTEGER,
  version INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS calls (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  contact_id INTEGER,
  user_id INTEGER,
  phone_number TEXT NOT NULL,
  direction TEXT CHECK(direction IN ('incoming','outgoing')),
  start_time DATETIME,
  duration INTEGER,
  version INTEGER DEFAULT 1,
  FOREIGN KEY (contact_id) REFERENCES contacts(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Index for faster lookup by phone_number
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone_number);
CREATE INDEX IF NOT EXISTS idx_calls_phone ON calls(phone_number);

// === file: src/utils/hash.js ===
import bcrypt from 'bcryptjs';

export async function hashPassword(plain) {
  const salt = bcrypt.genSaltSync(10);
  return bcrypt.hashSync(plain, salt);
}

export async function verifyPassword(plain, hash) {
  return bcrypt.compareSync(plain, hash);
}

// === file: src/utils/jwt.js ===
import { SignJWT, jwtVerify } from 'jose';

const encoder = new TextEncoder();

export async function signJWT(payload, secret, expiresInSeconds = 60 * 60 * 24) {
  const alg = 'HS256';
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + expiresInSeconds;

  const token = await new SignJWT({ ...payload })
    .setProtectedHeader({ alg })
    .setIssuedAt(iat)
    .setExpirationTime(exp)
    .sign(key);

  return token;
}

export async function verifyJWT(token, secret) {
  try {
    const alg = 'HS256';
    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify']
    );

    const { payload } = await jwtVerify(token, key, { algorithms: ['HS256'] });
    return payload;
  } catch (err) {
    return null;
  }
}

// === file: src/utils/db.js ===
// helper wrappers for D1 queries (env.DB is the D1 binding)
export async function queryFirst(env, sql, binds = []) {
  const stmt = env.DB.prepare(sql);
  binds.forEach((b, i) => stmt.bind(i + 1, b));
  const res = await stmt.first();
  return res || null;
}

export async function queryAll(env, sql, binds = []) {
  const stmt = env.DB.prepare(sql);
  binds.forEach((b, i) => stmt.bind(i + 1, b));
  const res = await stmt.all();
  return res?.results || [];
}

export async function run(env, sql, binds = []) {
  const stmt = env.DB.prepare(sql);
  binds.forEach((b, i) => stmt.bind(i + 1, b));
  const res = await stmt.run();
  return res;
}

// === file: src/middleware/authMiddleware.js ===
import { verifyJWT } from '../utils/jwt.js';

export async function requireAuth(req, env) {
  const auth = req.headers.get('authorization') || '';
  if (!auth.startsWith('Bearer ')) return null;
  const token = auth.split(' ')[1];
  const payload = await verifyJWT(token, env.JWT_SECRET);
  if (!payload) return null;
  return payload; // contains user fields (e.g., id, role)
}

export function jsonResponse(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

// === file: src/routes/auth.js ===
import { queryFirst } from '../utils/db.js';
import { verifyPassword } from '../utils/hash.js';
import { signJWT } from '../utils/jwt.js';
import { jsonResponse } from '../middleware/authMiddleware.js';

export async function handleLogin(req, env) {
  try {
    const { email, password } = await req.json();
    const user = await queryFirst(env, 'SELECT * FROM users WHERE email = ? LIMIT 1', [email]);
    if (!user) return jsonResponse({ error: 'Invalid credentials' }, 401);

    const ok = await verifyPassword(password, user.password_hash);
    if (!ok) return jsonResponse({ error: 'Invalid credentials' }, 401);

    const token = await signJWT({ id: user.id, role: user.role, email: user.email }, env.JWT_SECRET);
    return jsonResponse({ token, user: { id: user.id, email: user.email, role: user.role } });
  } catch (err) {
    return jsonResponse({ error: 'Bad request' }, 400);
  }
}

// === file: src/routes/contacts.js ===
import { queryAll, queryFirst, run } from '../utils/db.js';
import { jsonResponse } from '../middleware/authMiddleware.js';

export async function listContacts(req, env) {
  const rows = await queryAll(env, 'SELECT * FROM contacts ORDER BY created_at DESC');
  return jsonResponse({ contacts: rows });
}

export async function createContact(req, env, auth) {
  try {
    const { name, phone_number } = await req.json();
    if (!name || !phone_number) return jsonResponse({ error: 'Missing fields' }, 400);

    // Try insert - if conflict on phone_number, ignore (keep older)
    const sql = `INSERT INTO contacts (name, phone_number, created_by_user_id) VALUES (?, ?, ?)`;
    try {
      await run(env, sql, [name, phone_number, auth.id]);
      const newRow = await queryFirst(env, 'SELECT * FROM contacts WHERE phone_number = ? LIMIT 1', [phone_number]);
      return jsonResponse({ contact: newRow }, 201);
    } catch (err) {
      // likely unique constraint violation; return existing
      const existing = await queryFirst(env, 'SELECT * FROM contacts WHERE phone_number = ? LIMIT 1', [phone_number]);
      return jsonResponse({ contact: existing, warning: 'Phone number already exists — keeping older record' }, 200);
    }
  } catch (err) {
    return jsonResponse({ error: 'Bad request' }, 400);
  }
}

export async function updateContact(req, env, auth, id) {
  try {
    const body = await req.json();
    const existing = await queryFirst(env, 'SELECT * FROM contacts WHERE id = ? LIMIT 1', [id]);
    if (!existing) return jsonResponse({ error: 'Not found' }, 404);

    // Check ownership unless admin
    if (auth.role !== 'admin' && existing.created_by_user_id !== auth.id) {
      return jsonResponse({ error: 'Forbidden' }, 403);
    }

    // If phone_number changed, ensure uniqueness — if conflict, keep older
    if (body.phone_number && body.phone_number !== existing.phone_number) {
      const conflict = await queryFirst(env, 'SELECT * FROM contacts WHERE phone_number = ? LIMIT 1', [body.phone_number]);
      if (conflict) {
        return jsonResponse({ error: 'Phone number conflict - existing older record kept' }, 409);
      }
    }

    const updatedAt = new Date().toISOString();
    const sql = `UPDATE contacts SET name = ?, phone_number = ?, updated_at = ?, version = version + 1 WHERE id = ?`;
    await run(env, sql, [body.name || existing.name, body.phone_number || existing.phone_number, updatedAt, id]);
    const row = await queryFirst(env, 'SELECT * FROM contacts WHERE id = ? LIMIT 1', [id]);
    return jsonResponse({ contact: row });
  } catch (err) {
    return jsonResponse({ error: 'Bad request' }, 400);
  }
}

export async function deleteContact(req, env, auth, id) {
  const existing = await queryFirst(env, 'SELECT * FROM contacts WHERE id = ? LIMIT 1', [id]);
  if (!existing) return jsonResponse({ error: 'Not found' }, 404);
  if (auth.role !== 'admin' && existing.created_by_user_id !== auth.id) return jsonResponse({ error: 'Forbidden' }, 403);

  await run(env, 'DELETE FROM contacts WHERE id = ?', [id]);
  return jsonResponse({ ok: true });
}

// Sync endpoints
export async function syncContactsGet(req, env) {
  const url = new URL(req.url);
  const since = url.searchParams.get('since');
  let rows;
  if (since) {
    rows = await queryAll(env, 'SELECT * FROM contacts WHERE updated_at > ? OR created_at > ? ORDER BY created_at ASC', [since, since]);
  } else {
    rows = await queryAll(env, 'SELECT * FROM contacts ORDER BY created_at ASC');
  }
  return jsonResponse({ contacts: rows });
}

export async function syncContactsPost(req, env, auth) {
  try {
    const { contacts } = await req.json();
    if (!Array.isArray(contacts)) return jsonResponse({ error: 'Invalid payload' }, 400);

    const results = [];
    for (const c of contacts) {
      // try insert; on conflict keep older
      try {
        await run(env, 'INSERT INTO contacts (name, phone_number, created_by_user_id) VALUES (?, ?, ?)', [c.name, c.phone_number, auth.id]);
        const inserted = await queryFirst(env, 'SELECT * FROM contacts WHERE phone_number = ? LIMIT 1', [c.phone_number]);
        results.push({ status: 'inserted', contact: inserted });
      } catch (err) {
        const existing = await queryFirst(env, 'SELECT * FROM contacts WHERE phone_number = ? LIMIT 1', [c.phone_number]);
        results.push({ status: 'exists', contact: existing });
      }
    }
    return jsonResponse({ results });
  } catch (err) {
    return jsonResponse({ error: 'Bad request' }, 400);
  }
}

// === file: src/routes/calls.js ===
import { queryAll, run, queryFirst } from '../utils/db.js';
import { jsonResponse } from '../middleware/authMiddleware.js';

export async function listCalls(req, env) {
  const rows = await queryAll(env, 'SELECT * FROM calls ORDER BY start_time DESC');
  return jsonResponse({ calls: rows });
}

export async function createCall(req, env, auth) {
  try {
    const { phone_number, direction, start_time, duration } = await req.json();
    if (!phone_number) return jsonResponse({ error: 'Missing phone_number' }, 400);

    // If contact exists, link it
    const contact = await queryFirst(env, 'SELECT * FROM contacts WHERE phone_number = ? LIMIT 1', [phone_number]);

    await run(env, 'INSERT INTO calls (contact_id, user_id, phone_number, direction, start_time, duration) VALUES (?, ?, ?, ?, ?, ?)', [contact?.id || null, auth.id, phone_number, direction, start_time || new Date().toISOString(), duration || 0]);

    const inserted = await queryFirst(env, 'SELECT * FROM calls WHERE phone_number = ? ORDER BY id DESC LIMIT 1', [phone_number]);
    return jsonResponse({ call: inserted }, 201);
  } catch (err) {
    return jsonResponse({ error: 'Bad request' }, 400);
  }
}

export async function syncCallsGet(req, env) {
  const url = new URL(req.url);
  const since = url.searchParams.get('since');
  let rows;
  if (since) {
    rows = await queryAll(env, 'SELECT * FROM calls WHERE start_time > ? ORDER BY start_time ASC', [since]);
  } else {
    rows = await queryAll(env, 'SELECT * FROM calls ORDER BY start_time ASC');
  }
  return jsonResponse({ calls: rows });
}

export async function syncCallsPost(req, env, auth) {
  try {
    const { calls } = await req.json();
    if (!Array.isArray(calls)) return jsonResponse({ error: 'Invalid payload' }, 400);

    const results = [];
    for (const c of calls) {
      await run(env, 'INSERT INTO calls (contact_id, user_id, phone_number, direction, start_time, duration) VALUES (?, ?, ?, ?, ?, ?)', [null, auth.id, c.phone_number, c.direction, c.start_time || new Date().toISOString(), c.duration || 0]);
      const inserted = await queryFirst(env, 'SELECT * FROM calls WHERE phone_number = ? ORDER BY id DESC LIMIT 1', [c.phone_number]);
      results.push({ status: 'inserted', call: inserted });
    }
    return jsonResponse({ results });
  } catch (err) {
    return jsonResponse({ error: 'Bad request' }, 400);
  }
}

// === file: src/routes/admin.js ===
import { hashPassword } from '../utils/hash.js';
import { queryFirst, run, queryAll } from '../utils/db.js';
import { jsonResponse } from '../middleware/authMiddleware.js';

export async function createUser(req, env, auth) {
  if (auth.role !== 'admin') return jsonResponse({ error: 'Forbidden' }, 403);
  const { email, password, role } = await req.json();
  if (!email || !password) return jsonResponse({ error: 'Missing fields' }, 400);
  const existing = await queryFirst(env, 'SELECT * FROM users WHERE email = ? LIMIT 1', [email]);
  if (existing) return jsonResponse({ error: 'User exists' }, 409);
  const hash = await hashPassword(password);
  await run(env, 'INSERT INTO users (email, password_hash, role) VALUES (?, ?, ?)', [email, hash, role || 'user']);
  const user = await queryFirst(env, 'SELECT id, email, role, created_at FROM users WHERE email = ? LIMIT 1', [email]);
  return jsonResponse({ user }, 201);
}

export async function listUsers(req, env, auth) {
  if (auth.role !== 'admin') return jsonResponse({ error: 'Forbidden' }, 403);
  const rows = await queryAll(env, 'SELECT id, email, role, created_at FROM users ORDER BY created_at DESC');
  return jsonResponse({ users: rows });
}

export async function deleteUser(req, env, auth, id) {
  if (auth.role !== 'admin') return jsonResponse({ error: 'Forbidden' }, 403);
  await run(env, 'DELETE FROM users WHERE id = ?', [id]);
  return jsonResponse({ ok: true });
}

// Seed endpoint (one-time) - guarded by SEED_ADMIN_EMAIL & SEED_ADMIN_PASSWORD env vars
export async function seedAdmin(req, env) {
  // Only allow if admin user doesn't exist
  const exists = await queryFirst(env, 'SELECT * FROM users WHERE email = ? LIMIT 1', [env.SEED_ADMIN_EMAIL]);
  if (exists) return jsonResponse({ ok: 'Admin already exists' });
  const hash = await hashPassword(env.SEED_ADMIN_PASSWORD);
  await run(env, 'INSERT INTO users (email, password_hash, role) VALUES (?, ?, ?)', [env.SEED_ADMIN_EMAIL, hash, 'admin']);
  return jsonResponse({ ok: true });
}

// === file: src/index.js ===
import { handleLogin } from './routes/auth.js';
import * as contacts from './routes/contacts.js';
import * as calls from './routes/calls.js';
import * as admin from './routes/admin.js';
import { requireAuth, jsonResponse } from './middleware/authMiddleware.js';

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request, event));
});

async function handleRequest(req, event) {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;
  const env = event?.context?.vars || globalThis; // compatibility

  // Simple routing
  try {
    if (path === '/login' && method === 'POST') return await handleLogin(req, env);

    // Seed admin
    if (path === '/admin/seed' && method === 'POST') return await admin.seedAdmin(req, env);

    // Auth-protected routes
    const auth = await requireAuth(req, env);
    if (!auth) return jsonResponse({ error: 'Unauthorized' }, 401);

    // Contacts
    if (path === '/contacts' && method === 'GET') return await contacts.listContacts(req, env);
    if (path === '/contacts' && method === 'POST') return await contacts.createContact(req, env, auth);
    if (path.match(/^\/contacts\/\d+$/) && method === 'PUT') {
      const id = path.split('/')[2];
      return await contacts.updateContact(req, env, auth, id);
    }
    if (path.match(/^\/contacts\/\d+$/) && method === 'DELETE') {
      const id = path.split('/')[2];
      return await contacts.deleteContact(req, env, auth, id);
    }

    // Sync contacts
    if (path === '/sync/contacts' && method === 'GET') return await contacts.syncContactsGet(req, env);
    if (path === '/sync/contacts' && method === 'POST') return await contacts.syncContactsPost(req, env, auth);

    // Calls
    if (path === '/calls' && method === 'GET') return await calls.listCalls(req, env);
    if (path === '/calls' && method === 'POST') return await calls.createCall(req, env, auth);
    if (path === '/sync/calls' && method === 'GET') return await calls.syncCallsGet(req, env);
    if (path === '/sync/calls' && method === 'POST') return await calls.syncCallsPost(req, env, auth);

    // Admin
    if (path === '/admin/users' && method === 'POST') return await admin.createUser(req, env, auth);
    if (path === '/admin/users' && method === 'GET') return await admin.listUsers(req, env, auth);
    if (path.match(/^\/admin\/users\/\d+$/) && method === 'DELETE') {
      const id = path.split('/')[3];
      return await admin.deleteUser(req, env, auth, id);
    }

    return jsonResponse({ error: 'Not found' }, 404);
  } catch (err) {
    return jsonResponse({ error: 'Server error', detail: err?.message || String(err) }, 500);
  }
}

// === file: tools/seed_admin.js ===
// Node script to generate SQL insert with bcrypt hash (run locally)
import bcrypt from 'bcryptjs';
const email = process.env.SEED_ADMIN_EMAIL || 'admin@crm.local';
const password = process.env.SEED_ADMIN_PASSWORD || 'Admin@1234';
const salt = bcrypt.genSaltSync(10);
const hash = bcrypt.hashSync(password, salt);
console.log("-- Run the following SQL against your D1 database (or use Cloudflare dashboard):\n");
console.log(`INSERT INTO users (email, password_hash, role) VALUES ('${email}', '${hash}', 'admin');`);
