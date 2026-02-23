-- ============================================================================
-- Database Initialization Script
-- Runs automatically on first docker-compose up
-- ============================================================================

-- Create the items table
CREATE TABLE IF NOT EXISTS items (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed with sample data
INSERT INTO items (name, description) VALUES
    ('Sample Item 1', 'This is a sample item created during local development initialization.'),
    ('Sample Item 2', 'Another sample item to demonstrate the API functionality.'),
    ('Sample Item 3', 'A third item for testing list and retrieval endpoints.')
ON CONFLICT DO NOTHING;
