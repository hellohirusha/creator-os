-- ─────────────────────────────────────────────────────────────
-- Migration 002: Products, Variants, Images
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- CATEGORIES
-- Optional grouping for products (e.g. "Stickers", "T-Shirts")
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name        TEXT        NOT NULL,
    slug        TEXT        NOT NULL,
    position    INT         NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, slug)
);

CREATE INDEX idx_categories_tenant_id ON categories(tenant_id);

-- ─────────────────────────────────────────────────────────────
-- PRODUCTS
-- Core product record. Variants hold actual purchasable items.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category_id     UUID        REFERENCES categories(id) ON DELETE SET NULL,

    name            TEXT        NOT NULL,
    slug            TEXT        NOT NULL,         -- URL-safe name e.g. "vinyl-sticker-sheet"
    description     TEXT,
    short_desc      TEXT,                          -- One-liner for product cards

    base_price      NUMERIC(10,2) NOT NULL DEFAULT 0,
    compare_price   NUMERIC(10,2),                 -- "Was $X" crossed-out price

    status          TEXT        NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'active', 'archived')),

    is_featured     BOOLEAN     NOT NULL DEFAULT false,
    tags            TEXT[]      NOT NULL DEFAULT '{}',  -- e.g. {"stickers","vinyl","custom"}

    seo_title       TEXT,
    seo_description TEXT,

    -- AI-generated fields (populated on Day 8)
    ai_description  TEXT,
    ai_generated_at TIMESTAMPTZ,
    ai_quality_score NUMERIC(3,2),                 -- 0.00 to 1.00

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(tenant_id, slug)
);

CREATE INDEX idx_products_tenant_id    ON products(tenant_id);
CREATE INDEX idx_products_status       ON products(tenant_id, status);
CREATE INDEX idx_products_featured     ON products(tenant_id, is_featured);

-- ─────────────────────────────────────────────────────────────
-- PRODUCT IMAGES
-- Multiple images per product. position controls display order.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_images (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id  UUID        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    url         TEXT        NOT NULL,              -- Cloudinary URL
    alt_text    TEXT,
    position    INT         NOT NULL DEFAULT 0,    -- 0 = primary image
    width       INT,
    height      INT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_product_images_product_id ON product_images(product_id);

-- ─────────────────────────────────────────────────────────────
-- PRODUCT VARIANTS
-- Every purchasable item is a variant. A product with no
-- variations still gets one default variant.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_variants (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id      UUID        NOT NULL REFERENCES products(id) ON DELETE CASCADE,

    sku             TEXT        NOT NULL UNIQUE,   -- Stock keeping unit
    title           TEXT        NOT NULL DEFAULT 'Default',  -- e.g. "Large / Red"

    -- Option values — flexible key-value pairs
    option1_name    TEXT,                          -- e.g. "Size"
    option1_value   TEXT,                          -- e.g. "Large"
    option2_name    TEXT,                          -- e.g. "Color"
    option2_value   TEXT,                          -- e.g. "Red"
    option3_name    TEXT,
    option3_value   TEXT,

    price           NUMERIC(10,2) NOT NULL,
    compare_price   NUMERIC(10,2),
    cost_price      NUMERIC(10,2),                 -- Your cost (for margin calculation)

    stock_quantity  INT         NOT NULL DEFAULT 0,
    low_stock_alert INT         NOT NULL DEFAULT 5, -- Alert when stock <= this
    track_inventory BOOLEAN     NOT NULL DEFAULT true,
    allow_backorder BOOLEAN     NOT NULL DEFAULT false,

    weight_grams    INT,                           -- For shipping calculations
    image_url       TEXT,                          -- Variant-specific image (optional)

    is_active       BOOLEAN     NOT NULL DEFAULT true,
    position        INT         NOT NULL DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_variants_product_id ON product_variants(product_id);
CREATE INDEX idx_variants_sku        ON product_variants(sku);

-- RLS for new tables
ALTER TABLE categories      ENABLE ROW LEVEL SECURITY;
ALTER TABLE products        ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images  ENABLE ROW LEVEL SECURITY;

CREATE POLICY category_tenant_isolation ON categories
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

CREATE POLICY product_tenant_isolation ON products
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- Product images follow their product's tenant
CREATE POLICY product_image_isolation ON product_images
    USING (product_id IN (
        SELECT id FROM products
        WHERE tenant_id = current_setting('app.current_tenant_id', true)::uuid
    ));

-- Updated_at triggers
CREATE TRIGGER products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER variants_updated_at
    BEFORE UPDATE ON product_variants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();