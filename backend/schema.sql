-- Users table
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('admin','user')) DEFAULT 'user',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Contacts table
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone_number TEXT UNIQUE NOT NULL,
  created_by_user_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id)
);

-- Calls table
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

-- Create indexes for better performance
CREATE INDEX idx_contacts_phone ON contacts(phone_number);
CREATE INDEX idx_calls_user ON calls(user_id);
CREATE INDEX idx_calls_contact ON calls(contact_id);
