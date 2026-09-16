CREATE TABLE IF NOT EXISTS character_states (
    character_id TEXT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    state_json TEXT NOT NULL CHECK (json_valid(state_json)),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
) STRICT;

CREATE TABLE IF NOT EXISTS game_commands (
    character_id TEXT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    request_id TEXT NOT NULL,
    command TEXT NOT NULL,
    result_json TEXT NOT NULL CHECK (json_valid(result_json)),
    created_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000),
    PRIMARY KEY (character_id, request_id)
) STRICT;

CREATE INDEX IF NOT EXISTS game_commands_created_at_idx
    ON game_commands (created_at);

CREATE TABLE IF NOT EXISTS auction_listings (
    id TEXT PRIMARY KEY,
    seller_character_id TEXT NOT NULL REFERENCES characters(id),
    seller_name TEXT NOT NULL,
    item_kind TEXT NOT NULL CHECK (item_kind IN ('equipment', 'item', 'gem')),
    item_json TEXT NOT NULL CHECK (json_valid(item_json)),
    item_count INTEGER NOT NULL CHECK (item_count >= 1),
    buyout_price INTEGER NOT NULL CHECK (buyout_price >= 1 AND buyout_price <= 9000000000000000),
    fee_rate INTEGER NOT NULL DEFAULT 5 CHECK (fee_rate = 5),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'claimable', 'sold', 'cancelled', 'expired', 'claimed')),
    buyer_character_id TEXT REFERENCES characters(id),
    claim_character_id TEXT REFERENCES characters(id),
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL CHECK (expires_at > created_at),
    sold_at INTEGER,
    client_request_id TEXT NOT NULL,
    CONSTRAINT auction_listing_request_key UNIQUE (seller_character_id, client_request_id)
) STRICT;

CREATE INDEX IF NOT EXISTS auction_active_idx
    ON auction_listings (status, created_at DESC);

CREATE INDEX IF NOT EXISTS auction_seller_idx
    ON auction_listings (seller_character_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS auction_claim_idx
    ON auction_listings (claim_character_id, status, expires_at);
