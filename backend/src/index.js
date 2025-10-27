import { Hono } from 'hono';
import { cors } from 'hono/cors';
import bcrypt from 'bcryptjs';

const app = new Hono();

// Enable CORS for all origins
app.use('/*', cors({
  origin: '*',
  allowHeaders: ['Content-Type', 'Authorization'],
  allowMethods: ['POST', 'GET', 'PUT', 'DELETE', 'OPTIONS'],
  exposeHeaders: ['Content-Length'],
  maxAge: 600,
  credentials: true,
}));

// Simple JWT implementation (for Workers environment)
function createJWT(payload, secret) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const encodedHeader = btoa(JSON.stringify(header));
  const encodedPayload = btoa(JSON.stringify(payload));
  const signature = btoa(`${encodedHeader}.${encodedPayload}.${secret}`);
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

function verifyJWT(token, secret) {
  try {
    const [encodedHeader, encodedPayload, signature] = token.split('.');
    const expectedSignature = btoa(`${encodedHeader}.${encodedPayload}.${secret}`);

    if (signature !== expectedSignature) {
      return null;
    }

    return JSON.parse(atob(encodedPayload));
  } catch {
    return null;
  }
}

// Auth Middleware
const authMiddleware = async (c, next) => {
  const authHeader = c.req.header('Authorization');

  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  const token = authHeader.substring(7);
  const decoded = verifyJWT(token, c.env.JWT_SECRET);

  if (!decoded) {
    return c.json({ error: 'Invalid token' }, 401);
  }

  c.set('user', decoded);
  await next();
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

// Health check
app.get('/', (c) => {
  return c.json({ message: 'Shared Contact CRM API', version: '1.0.0' });
});

// Login
app.post('/login', async (c) => {
  try {
    const { email, password } = await c.req.json();

    const user = await c.env.DB.prepare(
      'SELECT * FROM users WHERE email = ?'
    ).bind(email).first();

    if (!user) {
      return c.json({ error: 'Invalid credentials' }, 401);
    }

    const isValid = bcrypt.compareSync(password, user.password_hash);

    if (!isValid) {
      return c.json({ error: 'Invalid credentials' }, 401);
    }

    const token = createJWT(
      { id: user.id, email: user.email, role: user.role },
      c.env.JWT_SECRET
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
  } catch (err) {
    return c.json({ error: 'Login failed: ' + err.message }, 500);
  }
});

// Get all contacts
app.get('/contacts', authMiddleware, async (c) => {
  try {
    const contacts = await c.env.DB.prepare(
      'SELECT * FROM contacts ORDER BY name ASC'
    ).all();

    return c.json(contacts.results || []);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Create contact
app.post('/contacts', authMiddleware, async (c) => {
  try {
    const { name, phone_number } = await c.req.json();
    const user = c.get('user');

    // Check if phone number already exists
    const existing = await c.env.DB.prepare(
      'SELECT id FROM contacts WHERE phone_number = ?'
    ).bind(phone_number).first();

    if (existing) {
      return c.json({ error: 'Phone number already exists' }, 400);
    }

    const result = await c.env.DB.prepare(
      'INSERT INTO contacts (name, phone_number, created_by_user_id, created_at) VALUES (?, ?, ?, datetime("now"))'
    ).bind(name, phone_number, user.id).run();

    const contact = await c.env.DB.prepare(
      'SELECT * FROM contacts WHERE id = ?'
    ).bind(result.meta.last_row_id).first();

    return c.json(contact);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Update contact
app.put('/contacts/:id', authMiddleware, async (c) => {
  try {
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
      return c.json({ error: 'Forbidden: Can only edit own contacts' }, 403);
    }

    // Check if phone number is taken by another contact
    const existing = await c.env.DB.prepare(
      'SELECT id FROM contacts WHERE phone_number = ? AND id != ?'
    ).bind(phone_number, id).first();

    if (existing) {
      return c.json({ error: 'Phone number already exists' }, 400);
    }

    await c.env.DB.prepare(
      'UPDATE contacts SET name = ?, phone_number = ?, updated_at = datetime("now") WHERE id = ?'
    ).bind(name, phone_number, id).run();

    const updated = await c.env.DB.prepare(
      'SELECT * FROM contacts WHERE id = ?'
    ).bind(id).first();

    return c.json(updated);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Delete contact
app.delete('/contacts/:id', authMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const user = c.get('user');

    const contact = await c.env.DB.prepare(
      'SELECT * FROM contacts WHERE id = ?'
    ).bind(id).first();

    if (!contact) {
      return c.json({ error: 'Contact not found' }, 404);
    }

    if (user.role !== 'admin' && contact.created_by_user_id !== user.id) {
      return c.json({ error: 'Forbidden: Can only delete own contacts' }, 403);
    }

    await c.env.DB.prepare('DELETE FROM contacts WHERE id = ?').bind(id).run();

    return c.json({ message: 'Contact deleted successfully' });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Get all calls
app.get('/calls', authMiddleware, async (c) => {
  try {
    const calls = await c.env.DB.prepare(
      'SELECT * FROM calls ORDER BY start_time DESC LIMIT 100'
    ).all();

    return c.json(calls.results || []);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Create call log
app.post('/calls', authMiddleware, async (c) => {
  try {
    const { phone_number, direction, start_time, duration } = await c.req.json();
    const user = c.get('user');

    // Try to find matching contact
    const contact = await c.env.DB.prepare(
      'SELECT id FROM contacts WHERE phone_number = ?'
    ).bind(phone_number).first();

    const result = await c.env.DB.prepare(
      'INSERT INTO calls (contact_id, user_id, phone_number, direction, start_time, duration) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind(
      contact?.id || null,
      user.id,
      phone_number,
      direction,
      start_time,
      duration || 0
    ).run();

    const call = await c.env.DB.prepare(
      'SELECT * FROM calls WHERE id = ?'
    ).bind(result.meta.last_row_id).first();

    return c.json(call);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Get all users (admin only)
app.get('/admin/users', authMiddleware, adminMiddleware, async (c) => {
  try {
    const users = await c.env.DB.prepare(
      'SELECT id, email, role, created_at FROM users ORDER BY created_at DESC'
    ).all();

    return c.json(users.results || []);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Create user (admin only)
app.post('/admin/users', authMiddleware, adminMiddleware, async (c) => {
  try {
    const { email, password, role } = await c.req.json();

    // Check if email already exists
    const existing = await c.env.DB.prepare(
      'SELECT id FROM users WHERE email = ?'
    ).bind(email).first();

    if (existing) {
      return c.json({ error: 'Email already exists' }, 400);
    }

    const hash = bcrypt.hashSync(password, 10);

    const result = await c.env.DB.prepare(
      'INSERT INTO users (email, password_hash, role, created_at) VALUES (?, ?, ?, datetime("now"))'
    ).bind(email, hash, role || 'user').run();

    const user = await c.env.DB.prepare(
      'SELECT id, email, role, created_at FROM users WHERE id = ?'
    ).bind(result.meta.last_row_id).first();

    return c.json(user);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Delete user (admin only)
app.delete('/admin/users/:id', authMiddleware, adminMiddleware, async (c) => {
  try {
    const id = c.req.param('id');
    const user = c.get('user');

    if (parseInt(id) === user.id) {
      return c.json({ error: 'Cannot delete yourself' }, 400);
    }

    await c.env.DB.prepare('DELETE FROM users WHERE id = ?').bind(id).run();

    return c.json({ message: 'User deleted successfully' });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

export default app;
