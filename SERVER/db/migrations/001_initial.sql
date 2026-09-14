CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    username_normalized TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'normal'
        CHECK (status IN ('normal', 'banned', 'deleted')),
    banned_until INTEGER,
    must_change_password INTEGER NOT NULL DEFAULT 0
        CHECK (must_change_password IN (0, 1)),
    registration_request_id TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
    deleted_at INTEGER,
    CONSTRAINT accounts_username_normalized_key UNIQUE (username_normalized),
    CONSTRAINT accounts_registration_request_id_key UNIQUE (registration_request_id)
) STRICT;

CREATE TABLE IF NOT EXISTS invite_codes (
    id TEXT PRIMARY KEY,
    code_hash TEXT NOT NULL CHECK (length(code_hash) = 64),
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'used', 'revoked', 'expired')),
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
    used_at INTEGER,
    used_by_account_id TEXT REFERENCES accounts(id),
    revoked_at INTEGER,
    CONSTRAINT invite_codes_code_hash_key UNIQUE (code_hash)
) STRICT;

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL CHECK (length(token_hash) = 64),
    account_id TEXT NOT NULL REFERENCES accounts(id),
    created_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    idle_expires_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    revoked_at INTEGER,
    revoke_reason TEXT,
    CONSTRAINT sessions_token_hash_key UNIQUE (token_hash)
) STRICT;

CREATE INDEX IF NOT EXISTS sessions_account_active_idx
    ON sessions (account_id)
    WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS characters (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    display_name_normalized TEXT NOT NULL,
    level INTEGER NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 100),
    experience INTEGER NOT NULL DEFAULT 0 CHECK (experience >= 0),
    gold INTEGER NOT NULL DEFAULT 0
        CHECK (gold BETWEEN 0 AND 9000000000000000),
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
    creation_request_id TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
    deleted_at INTEGER,
    CONSTRAINT characters_account_id_key UNIQUE (account_id),
    CONSTRAINT characters_display_name_normalized_key UNIQUE (display_name_normalized),
    CONSTRAINT characters_creation_request_id_key UNIQUE (creation_request_id),
    CONSTRAINT characters_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(id)
) STRICT;

CREATE TABLE IF NOT EXISTS login_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    login_key_hash TEXT NOT NULL CHECK (length(login_key_hash) = 64),
    ip_hash TEXT NOT NULL CHECK (length(ip_hash) = 64),
    result TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
) STRICT;

CREATE INDEX IF NOT EXISTS login_attempts_created_at_idx
    ON login_attempts (created_at);

CREATE TABLE IF NOT EXISTS audit_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    actor_account_id TEXT REFERENCES accounts(id),
    target_account_id TEXT REFERENCES accounts(id),
    details TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(details)),
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
) STRICT;

CREATE INDEX IF NOT EXISTS audit_events_created_at_idx
    ON audit_events (created_at);

CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel TEXT NOT NULL CHECK (channel IN ('world', 'system')),
    sender_character_id TEXT REFERENCES characters(id),
    body TEXT NOT NULL,
    client_message_id TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
) STRICT;

CREATE UNIQUE INDEX IF NOT EXISTS chat_messages_sender_client_key
    ON chat_messages (sender_character_id, client_message_id)
    WHERE sender_character_id IS NOT NULL AND client_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS chat_messages_channel_created_idx
    ON chat_messages (channel, created_at DESC);

CREATE TABLE IF NOT EXISTS chat_blocks (
    account_id TEXT NOT NULL REFERENCES accounts(id),
    blocked_character_id TEXT NOT NULL REFERENCES characters(id),
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
    PRIMARY KEY (account_id, blocked_character_id)
) STRICT;

CREATE TABLE IF NOT EXISTS chat_mutes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id TEXT NOT NULL REFERENCES accounts(id),
    reason TEXT NOT NULL,
    starts_at INTEGER NOT NULL,
    ends_at INTEGER NOT NULL,
    operator_account_id TEXT REFERENCES accounts(id),
    revoked_at INTEGER,
    CHECK (ends_at > starts_at),
    CHECK (ends_at <= starts_at + 259200000)
) STRICT;

CREATE INDEX IF NOT EXISTS chat_mutes_account_active_idx
    ON chat_mutes (account_id, ends_at)
    WHERE revoked_at IS NULL;
