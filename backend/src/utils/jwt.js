// JWT utility functions for Workers environment
export function createJWT(payload, secret) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const encodedHeader = btoa(JSON.stringify(header));
  const encodedPayload = btoa(JSON.stringify(payload));
  const signature = btoa(`${encodedHeader}.${encodedPayload}.${secret}`);
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

export function verifyJWT(token, secret) {
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
