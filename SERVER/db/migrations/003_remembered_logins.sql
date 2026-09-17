CREATE TABLE IF NOT EXISTS remembered_logins (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL CHECK (length(token_hash) = 64),
    account_id TEXT NOT NULL REFERENCES accounts(id),
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    revoked_at INTEGER,
    revoke_reason TEXT,
    CONSTRAINT remembered_logins_token_hash_key UNIQUE (token_hash)
) STRICT;

CREATE INDEX IF NOT EXISTS remembered_logins_account_active_idx
    ON remembered_logins (account_id, expires_at)
    WHERE revoked_at IS NULL;
