// Admin Middleware
export const adminMiddleware = async (c, next) => {
  const user = c.get('user');
  if (user.role !== 'admin') {
    return c.json({ error: 'Forbidden: Admin only' }, 403);
  }
  await next();
};
