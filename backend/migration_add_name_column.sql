-- Migration script to add name column and update existing users
-- Run this script to update the database schema and populate existing user names

-- Add name column if it doesn't exist
ALTER TABLE users ADD COLUMN name TEXT;

-- Update existing users with default names based on their role
UPDATE users SET name = 'Admin User' WHERE role = 'admin' AND name IS NULL;
UPDATE users SET name = 'Regular User' WHERE role = 'user' AND name IS NULL;

-- Alternative: Update based on email pattern (uncomment if preferred)
-- UPDATE users SET name = 'Admin User' WHERE email LIKE '%admin%' AND name IS NULL;
-- UPDATE users SET name = 'Regular User' WHERE email NOT LIKE '%admin%' AND name IS NULL;
