const bcrypt = require('bcryptjs');

const passwords = [
  { email: 'admin@example.com', password: 'admin123', role: 'admin' },
  { email: 'user@example.com', password: 'user123', role: 'user' }
];

console.log('Generating password hashes...\n');

passwords.forEach(({ email, password, role }) => {
  const hash = bcrypt.hashSync(password, 10);
  console.log(`Email: ${email}`);
  console.log(`Password: ${password}`);
  console.log(`Hash: ${hash}`);
  console.log(`Role: ${role}\n`);
});

// Generate seed.sql
console.log('\n=== seed.sql content ===\n');
passwords.forEach(({ email, password, role }) => {
  const hash = bcrypt.hashSync(password, 10);
  console.log(`INSERT INTO users (email, password_hash, role) VALUES ('${email}', '${hash}', '${role}');`);
});
