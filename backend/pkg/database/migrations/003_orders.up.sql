-- ─────────────────────────────────────────────────────────────
-- Migration 003: Orders, Order Items, Cart Sessions
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- ORDERS
-- Created when Stripe confirms payment. Never created before.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             UUID        REFERENCES users(id) ON DELETE SET NULL,

    -- Stripe identifiers
    stripe_session_id   TEXT        UNIQUE,
    stripe_payment_id   TEXT,
    stripe_customer_id  TEXT,

    -- Order totals (stored at time of purchase — prices may change later)
    subtotal            NUMERIC(10,2) NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(10,2) NOT NULL DEFAULT 0,
    shipping_amount     NUMERIC(10,2) NOT NULL DEFAULT 0,
    discount_amount     NUMERIC(10,2) NOT NULL DEFAULT 0,
    total               NUMERIC(10,2) NOT NULL DEFAULT 0,

    -- Status flow: pending → paid → processing → shipped → delivered
    --              pending → failed (payment failed)
    --              paid → refunded
    status              TEXT        NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                            'pending', 'paid', 'processing',
                            'shipped', 'delivered', 'cancelled', 'refunded', 'failed'
                        )),

    -- Customer info (snapshot at time of purchase)
    customer_email      TEXT        NOT NULL,
    customer_name       TEXT,

    -- Shipping address
    shipping_name       TEXT,
    shipping_line1      TEXT,
    shipping_line2      TEXT,
    shipping_city       TEXT,
    shipping_state      TEXT,
    shipping_zip        TEXT,
    shipping_country    TEXT,

    -- Tracking
    tracking_number     TEXT,
    tracking_carrier    TEXT,
    shipped_at          TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,

    -- Internal
    notes               TEXT,        -- Merchant internal notes
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_tenant_id       ON orders(tenant_id);
CREATE INDEX idx_orders_status          ON orders(tenant_id, status);
CREATE INDEX idx_orders_stripe_session  ON orders(stripe_session_id);
CREATE INDEX idx_orders_customer_email  ON orders(tenant_id, customer_email);

-- ─────────────────────────────────────────────────────────────
-- ORDER ITEMS
-- Snapshot of what was purchased. Frozen at time of purchase.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS order_items (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id          UUID        REFERENCES products(id) ON DELETE SET NULL,
    variant_id          UUID        REFERENCES product_variants(id) ON DELETE SET NULL,

    -- Snapshot values (not foreign key lookups — prices change)
    product_name        TEXT        NOT NULL,
    variant_title       TEXT        NOT NULL DEFAULT 'Default',
    sku                 TEXT,
    quantity            INT         NOT NULL DEFAULT 1,
    unit_price          NUMERIC(10,2) NOT NULL,
    total_price         NUMERIC(10,2) NOT NULL,
    image_url           TEXT,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order_id   ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- ─────────────────────────────────────────────────────────────
-- CART SESSIONS
-- Temporary carts tied to a session token.
-- Deleted after order is created.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cart_sessions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    session_token   TEXT        NOT NULL UNIQUE,  -- Random token stored in browser
    user_id         UUID        REFERENCES users(id) ON DELETE SET NULL,
    items           JSONB       NOT NULL DEFAULT '[]',  -- Array of cart items
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cart_sessions_token     ON cart_sessions(session_token);
CREATE INDEX idx_cart_sessions_tenant_id ON cart_sessions(tenant_id);

-- RLS policies
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_tenant_isolation ON orders
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

CREATE POLICY order_items_tenant_isolation ON order_items
    USING (order_id IN (
        SELECT id FROM orders
        WHERE tenant_id = current_setting('app.current_tenant_id', true)::uuid
    ));

-- Updated_at trigger for orders
CREATE TRIGGER orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();