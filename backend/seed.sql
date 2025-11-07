-- Admin user (email: admin@example.com, password: admin123)
INSERT INTO users (name, email, password_hash, role) VALUES ('Admin User', 'admin@example.com', '$2b$10$OYFasaWu26fLXOjNY/KPEOezUgMCR1UFW5OUTREd7PLjqNmwBWq1e', 'admin');

-- Regular user (email: user@example.com, password: user123)
INSERT INTO users (name, email, password_hash, role) VALUES ('Regular User', 'user@example.com', '$2b$10$Dt9ex23Ma42.n/83P7lewOlE0hCuzgu1CkAl8.7AFsoRol376OA2C', 'user');
