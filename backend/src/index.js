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
  return c.json({ message: 'Shared Contact CRM API', version: '2.0.0', features: ['UUID duplicate prevention', 'Missed call support'] });
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
      { id: user.id, name: user.name, email: user.email, role: user.role },
      c.env.JWT_SECRET
    );

    return c.json({
      token,
      user: {
        id: user.id,
        name: user.name,
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

// Get all calls with user filtering and UUID support
app.get('/calls', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const url = new URL(c.req.url);
    const userId = url.searchParams.get('user_id');
    const direction = url.searchParams.get('direction'); // Filter by direction (incoming, outgoing, missed)

    let query = 'SELECT * FROM calls';
    let params = [];
    let conditions = [];

    // If user_id is provided and user is not admin, filter by user_id
    if (userId && user.role !== 'admin') {
      conditions.push('user_id = ?');
      params.push(parseInt(userId));
    }
    // If user is admin and no user_id is provided, show all calls
    // If user is admin and user_id is provided, show calls for that specific user
    else if (userId && user.role === 'admin') {
      conditions.push('user_id = ?');
      params.push(parseInt(userId));
    }

    // Add direction filter if provided
    if (direction && ['incoming', 'outgoing', 'missed'].includes(direction)) {
      conditions.push('direction = ?');
      params.push(direction);
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY start_time DESC LIMIT 100';

    const calls = await c.env.DB.prepare(query).bind(...params).all();

    return c.json(calls.results || []);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Get call statistics
app.get('/calls/stats', authMiddleware, async (c) => {
  try {
    const user = c.get('user');
    const url = new URL(c.req.url);
    const userId = url.searchParams.get('user_id');

    let whereClause = '';
    let params = [];

    if (userId && user.role !== 'admin') {
      whereClause = 'WHERE user_id = ?';
      params.push(user.id);
    } else if (userId && user.role === 'admin') {
      whereClause = 'WHERE user_id = ?';
      params.push(parseInt(userId));
    }

    // Get total count
    const totalResult = await c.env.DB.prepare(
      `SELECT COUNT(*) as count FROM calls ${whereClause}`
    ).bind(...params).first();

    // Get incoming count
    const incomingResult = await c.env.DB.prepare(
      `SELECT COUNT(*) as count FROM calls ${whereClause ? whereClause + ' AND' : 'WHERE'} direction = 'incoming'`
    ).bind(...params).first();

    // Get outgoing count
    const outgoingResult = await c.env.DB.prepare(
      `SELECT COUNT(*) as count FROM calls ${whereClause ? whereClause + ' AND' : 'WHERE'} direction = 'outgoing'`
    ).bind(...params).first();

    // Get missed count
    const missedResult = await c.env.DB.prepare(
      `SELECT COUNT(*) as count FROM calls ${whereClause ? whereClause + ' AND' : 'WHERE'} direction = 'missed'`
    ).bind(...params).first();

    return c.json({
      total: totalResult.count || 0,
      incoming: incomingResult.count || 0,
      outgoing: outgoingResult.count || 0,
      missed: missedResult.count || 0
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Create call log with UUID duplicate prevention
app.post('/calls', authMiddleware, async (c) => {
  try {
    const { phone_number, direction, start_time, duration, uuid } = await c.req.json();
    const user = c.get('user');

    // Validate direction
    const validDirections = ['incoming', 'outgoing', 'missed'];
    if (!validDirections.includes(direction)) {
      return c.json({ error: 'Invalid direction. Must be one of: ' + validDirections.join(', ') }, 400);
    }

    // Check for duplicate using UUID if provided
    if (uuid) {
      const existingByUuid = await c.env.DB.prepare(
        'SELECT id FROM calls WHERE uuid = ?'
      ).bind(uuid).first();

      if (existingByUuid) {
        return c.json({ error: 'Call log already exists (duplicate UUID)' }, 409);
      }
    }

    // Also check for duplicates by phone number and timestamp (fallback)
    const existingByTime = await c.env.DB.prepare(
      'SELECT id FROM calls WHERE phone_number = ? AND start_time = ?'
    ).bind(phone_number, start_time).first();

    if (existingByTime) {
      return c.json({ error: 'Call log already exists' }, 409);
    }

    // Try to find matching contact
    const contact = await c.env.DB.prepare(
      'SELECT id FROM contacts WHERE phone_number = ?'
    ).bind(phone_number).first();

    const result = await c.env.DB.prepare(
      'INSERT INTO calls (uuid, contact_id, user_id, phone_number, direction, start_time, duration) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(
      uuid || null, // Store UUID if provided
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

// Bulk create calls (for efficient sync)
app.post('/calls/bulk', authMiddleware, async (c) => {
  try {
    const { calls } = await c.req.json();
    const user = c.get('user');

    if (!Array.isArray(calls)) {
      return c.json({ error: 'Calls must be an array' }, 400);
    }

    const results = {
      created: 0,
      skipped: 0,
      errors: []
    };

    for (const callData of calls) {
      try {
        const { phone_number, direction, start_time, duration, uuid } = callData;

        // Validate direction
        const validDirections = ['incoming', 'outgoing', 'missed'];
        if (!validDirections.includes(direction)) {
          results.errors.push({ call: callData, error: 'Invalid direction' });
          continue;
        }

        // Check for duplicate using UUID if provided
        if (uuid) {
          const existingByUuid = await c.env.DB.prepare(
            'SELECT id FROM calls WHERE uuid = ?'
          ).bind(uuid).first();

          if (existingByUuid) {
            results.skipped++;
            continue;
          }
        }

        // Also check for duplicates by phone number and timestamp (fallback)
        const existingByTime = await c.env.DB.prepare(
          'SELECT id FROM calls WHERE phone_number = ? AND start_time = ?'
        ).bind(phone_number, start_time).first();

        if (existingByTime) {
          results.skipped++;
          continue;
        }

        // Try to find matching contact
        const contact = await c.env.DB.prepare(
          'SELECT id FROM contacts WHERE phone_number = ?'
        ).bind(phone_number).first();

        await c.env.DB.prepare(
          'INSERT INTO calls (uuid, contact_id, user_id, phone_number, direction, start_time, duration) VALUES (?, ?, ?, ?, ?, ?, ?)'
        ).bind(
          uuid || null,
          contact?.id || null,
          user.id,
          phone_number,
          direction,
          start_time,
          duration || 0
        ).run();

        results.created++;
      } catch (err) {
        results.errors.push({ call: callData, error: err.message });
      }
    }

    return c.json(results);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Get all users (admin only)
app.get('/admin/users', authMiddleware, adminMiddleware, async (c) => {
  try {
    const users = await c.env.DB.prepare(
      'SELECT id, name, email, role, created_at FROM users ORDER BY created_at DESC'
    ).all();

    return c.json(users.results || []);
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Create user (admin only)
app.post('/admin/users', authMiddleware, adminMiddleware, async (c) => {
  try {
    const { name, email, password, role } = await c.req.json();

    // Check if email already exists
    const existing = await c.env.DB.prepare(
      'SELECT id FROM users WHERE email = ?'
    ).bind(email).first();

    if (existing) {
      return c.json({ error: 'Email already exists' }, 400);
    }

    const hash = bcrypt.hashSync(password, 10);

    const result = await c.env.DB.prepare(
      'INSERT INTO users (name, email, password_hash, role, created_at) VALUES (?, ?, ?, ?, datetime("now"))'
    ).bind(name, email, hash, role || 'user').run();

    const user = await c.env.DB.prepare(
      'SELECT id, name, email, role, created_at FROM users WHERE id = ?'
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

// Get user contacts (admin only)
app.get('/admin/users/:id/contacts', authMiddleware, adminMiddleware, async (c) => {
  try {
    const id = c.req.param('id');

    // Check if user exists
    const user = await c.env.DB.prepare(
      'SELECT id, name, email FROM users WHERE id = ?'
    ).bind(id).first();

    if (!user) {
      return c.json({ error: 'User not found' }, 404);
    }

    const contacts = await c.env.DB.prepare(
      'SELECT * FROM contacts WHERE created_by_user_id = ? ORDER BY name ASC'
    ).bind(id).all();

    return c.json({
      user: { id: user.id, name: user.name, email: user.email },
      contacts: contacts.results || []
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Get user calls (admin only)
app.get('/admin/users/:id/calls', authMiddleware, adminMiddleware, async (c) => {
  try {
    const id = c.req.param('id');

    // Check if user exists
    const user = await c.env.DB.prepare(
      'SELECT id, name, email FROM users WHERE id = ?'
    ).bind(id).first();

    if (!user) {
      return c.json({ error: 'User not found' }, 404);
    }

    const calls = await c.env.DB.prepare(
      'SELECT * FROM calls WHERE user_id = ? ORDER BY start_time DESC LIMIT 1000'
    ).bind(id).all();

    return c.json({
      user: { id: user.id, name: user.name, email: user.email },
      calls: calls.results || []
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Get user stats (admin only)
app.get('/admin/users/:id/stats', authMiddleware, adminMiddleware, async (c) => {
  try {
    const id = c.req.param('id');

    // Check if user exists
    const user = await c.env.DB.prepare(
      'SELECT id, name, email FROM users WHERE id = ?'
    ).bind(id).first();

    if (!user) {
      return c.json({ error: 'User not found' }, 404);
    }

    // Count contacts
    const contactCount = await c.env.DB.prepare(
      'SELECT COUNT(*) as count FROM contacts WHERE created_by_user_id = ?'
    ).bind(id).first();

    // Count calls
    const callCount = await c.env.DB.prepare(
      'SELECT COUNT(*) as count FROM calls WHERE user_id = ?'
    ).bind(id).first();

    // Count calls by direction
    const incomingCount = await c.env.DB.prepare(
      'SELECT COUNT(*) as count FROM calls WHERE user_id = ? AND direction = "incoming"'
    ).bind(id).first();

    const outgoingCount = await c.env.DB.prepare(
      'SELECT COUNT(*) as count FROM calls WHERE user_id = ? AND direction = "outgoing"'
    ).bind(id).first();

    const missedCount = await c.env.DB.prepare(
      'SELECT COUNT(*) as count FROM calls WHERE user_id = ? AND direction = "missed"'
    ).bind(id).first();

    return c.json({
      user: { id: user.id, name: user.name, email: user.email },
      stats: {
        contacts: contactCount.count || 0,
        calls: {
          total: callCount.count || 0,
          incoming: incomingCount.count || 0,
          outgoing: outgoingCount.count || 0,
          missed: missedCount.count || 0
        }
      }
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

// Flush user data (admin only) - admins can flush their own data
app.delete('/admin/users/:id/data', authMiddleware, adminMiddleware, async (c) => {
  try {
    const id = c.req.param('id');

    // Check if user exists
    const targetUser = await c.env.DB.prepare(
      'SELECT id, name, email FROM users WHERE id = ?'
    ).bind(id).first();

    if (!targetUser) {
      return c.json({ error: 'User not found' }, 404);
    }

    // Delete calls first (due to foreign key constraints)
    await c.env.DB.prepare('DELETE FROM calls WHERE user_id = ?').bind(id).run();

    // Delete contacts
    await c.env.DB.prepare('DELETE FROM contacts WHERE created_by_user_id = ?').bind(id).run();

    return c.json({
      message: 'User data flushed successfully',
      user: { id: targetUser.id, name: targetUser.name, email: targetUser.email }
    });
  } catch (err) {
    return c.json({ error: err.message }, 500);
  }
});

export default app;
