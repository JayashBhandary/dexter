-- Seed for Dexter Postgres testing.

CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    full_name   TEXT NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
    status      TEXT NOT NULL DEFAULT 'pending',
    placed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata    JSONB
);

CREATE INDEX IF NOT EXISTS orders_user_id_idx ON orders (user_id);

INSERT INTO users (email, full_name, is_active) VALUES
    ('alice@example.com', 'Alice Liddell',  TRUE),
    ('bob@example.com',   'Bob Roberts',    TRUE),
    ('carol@example.com', 'Carol Danvers',  FALSE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO orders (user_id, total_cents, status, metadata)
SELECT u.id, (random() * 50000)::INTEGER, 'shipped',
       jsonb_build_object('source', 'seed', 'note', 'demo row')
FROM users u
CROSS JOIN generate_series(1, 5) gs
ON CONFLICT DO NOTHING;
