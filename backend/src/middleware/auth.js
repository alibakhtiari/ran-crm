import { verifyJWT } from '../utils/jwt.js';

// Auth Middleware
export const authMiddleware = async (c, next) => {
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
