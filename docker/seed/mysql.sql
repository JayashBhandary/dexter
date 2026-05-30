-- Seed for Dexter MySQL testing.

CREATE TABLE IF NOT EXISTS users (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(255) NOT NULL,
    is_active   TINYINT(1)   NOT NULL DEFAULT 1,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED NOT NULL,
    total_cents INT UNSIGNED NOT NULL DEFAULT 0,
    status      VARCHAR(32)  NOT NULL DEFAULT 'pending',
    placed_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata    JSON,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE,
    INDEX orders_user_id_idx (user_id)
) ENGINE=InnoDB;

INSERT IGNORE INTO users (email, full_name, is_active) VALUES
    ('alice@example.com', 'Alice Liddell',  1),
    ('bob@example.com',   'Bob Roberts',    1),
    ('carol@example.com', 'Carol Danvers',  0);

INSERT INTO orders (user_id, total_cents, status, metadata)
SELECT u.id, FLOOR(RAND() * 50000), 'shipped',
       JSON_OBJECT('source', 'seed', 'note', 'demo row')
FROM users u
JOIN (
    SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
) gs;
