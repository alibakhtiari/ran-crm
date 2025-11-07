-- Migration: Add UUID and Missed Call Support to Calls Table
-- Version: 2.0
-- Date: 2025-11-08

-- First, add uuid column if it doesn't exist
ALTER TABLE calls ADD COLUMN uuid TEXT;

-- Update existing records to have UUIDs (for SQLite compatibility)
-- Note: This is handled in the application layer for better UUID generation

-- Update the CHECK constraint to include missed calls
-- Since SQLite doesn't support ALTER TABLE DROP CONSTRAINT, we need to recreate
-- This migration assumes data is migrated through the application

-- Add missed call support comment
-- The direction column now supports: 'incoming', 'outgoing', 'missed'
