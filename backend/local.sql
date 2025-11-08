PRAGMA defer_foreign_keys=TRUE;
CREATE TABLE organizations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
INSERT INTO "organizations" VALUES('org_default','Default Organization',1759741268);
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('owner', 'user')),
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
);
INSERT INTO "users" VALUES('user_admin','org_default','Admin User','admin@crm.com','240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9','owner',1759741268);
CREATE TABLE contacts (
  id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  created_by_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(org_id, phone_number)
);
INSERT INTO "contacts" VALUES('contact_1761661140613_xht9dvyqa','org_default','test','09125811880','user_admin',1761661140,1761661140);
CREATE TABLE calls (
  id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  contact_id TEXT,
  user_id TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('incoming', 'outgoing')),
  start_time INTEGER NOT NULL,
  duration INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')), uuid TEXT,
  FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX idx_users_org_id ON users(org_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_contacts_org_id ON contacts(org_id);
CREATE INDEX idx_contacts_phone ON contacts(org_id, phone_number);
CREATE INDEX idx_contacts_created_by ON contacts(created_by_user_id);
CREATE INDEX idx_calls_org_id ON calls(org_id);
CREATE INDEX idx_calls_contact_id ON calls(contact_id);
CREATE INDEX idx_calls_user_id ON calls(user_id);
CREATE INDEX idx_calls_phone ON calls(phone_number);
CREATE INDEX idx_calls_start_time ON calls(start_time);
