-- ─────────────────────────────────────────────────────────────
-- Migration 004: Notify — Email Templates, Campaigns, Logs
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- EMAIL TEMPLATES
-- Reusable HTML templates with variable placeholders.
-- Variables use {{.VariableName}} syntax (Go templates).
-- Example: "Hello {{.FirstName}}, your order #{{.OrderID}} is confirmed."
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_templates (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,

    name            TEXT        NOT NULL,         -- Internal name: "Order Confirmation"
    slug            TEXT        NOT NULL,         -- Machine name: "order_confirmation"
    description     TEXT,

    subject         TEXT        NOT NULL,         -- Email subject line (can use variables)
    html_body       TEXT        NOT NULL,         -- Full HTML email body
    text_body       TEXT,                         -- Plain text fallback
    preview_text    TEXT,                         -- Shown in email clients before open

    -- Available variables documented as JSON array
    -- e.g. ["FirstName","OrderID","OrderTotal","StoreName"]
    variables       JSONB       NOT NULL DEFAULT '[]',

    -- System templates cannot be deleted
    is_system       BOOLEAN     NOT NULL DEFAULT false,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(tenant_id, slug)
);

CREATE INDEX idx_email_templates_tenant ON email_templates(tenant_id);

-- ─────────────────────────────────────────────────────────────
-- EMAIL CAMPAIGNS
-- A campaign is a scheduled bulk send to a list of recipients.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_campaigns (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    template_id     UUID        REFERENCES email_templates(id) ON DELETE SET NULL,

    name            TEXT        NOT NULL,
    subject         TEXT        NOT NULL,         -- Override template subject for campaigns

    -- Recipient targeting
    -- "all" = all users in tenant
    -- "tag:vip" = users with specific tag
    -- "segment:purchased_last_30_days" = custom segment
    recipient_type  TEXT        NOT NULL DEFAULT 'all'
                    CHECK (recipient_type IN ('all', 'tag', 'segment', 'manual')),
    recipient_filter JSONB      NOT NULL DEFAULT '{}',
    recipient_count INT         NOT NULL DEFAULT 0,   -- Populated on send

    -- Schedule
    status          TEXT        NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'cancelled', 'failed')),
    scheduled_at    TIMESTAMPTZ,                  -- NULL = send immediately
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,

    -- Metrics (updated as emails are sent and events received)
    sent_count      INT         NOT NULL DEFAULT 0,
    delivered_count INT         NOT NULL DEFAULT 0,
    opened_count    INT         NOT NULL DEFAULT 0,
    clicked_count   INT         NOT NULL DEFAULT 0,
    bounced_count   INT         NOT NULL DEFAULT 0,
    unsubscribed_count INT      NOT NULL DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_campaigns_tenant   ON email_campaigns(tenant_id);
CREATE INDEX idx_campaigns_status   ON email_campaigns(tenant_id, status);
CREATE INDEX idx_campaigns_schedule ON email_campaigns(scheduled_at)
    WHERE status = 'scheduled';    -- Partial index — only scheduled ones

-- ─────────────────────────────────────────────────────────────
-- EMAIL LOGS
-- One row per email sent. Records delivery status and engagement.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_logs (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    campaign_id     UUID        REFERENCES email_campaigns(id) ON DELETE SET NULL,
    template_id     UUID        REFERENCES email_templates(id) ON DELETE SET NULL,

    -- Recipient
    to_email        TEXT        NOT NULL,
    to_name         TEXT,

    -- Email content snapshot
    subject         TEXT        NOT NULL,
    resend_message_id TEXT,                       -- Resend's internal message ID

    -- Delivery status
    status          TEXT        NOT NULL DEFAULT 'queued'
                    CHECK (status IN (
                        'queued', 'sent', 'delivered',
                        'opened', 'clicked', 'bounced',
                        'complained', 'unsubscribed', 'failed'
                    )),

    -- Engagement tracking
    opened_at       TIMESTAMPTZ,
    clicked_at      TIMESTAMPTZ,
    bounced_at      TIMESTAMPTZ,
    complained_at   TIMESTAMPTZ,

    -- Link clicked (if status = clicked)
    clicked_url     TEXT,

    -- Error info (if status = failed or bounced)
    error_message   TEXT,

    -- Context
    order_id        UUID        REFERENCES orders(id) ON DELETE SET NULL,

    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_email_logs_tenant    ON email_logs(tenant_id);
CREATE INDEX idx_email_logs_campaign  ON email_logs(campaign_id);
CREATE INDEX idx_email_logs_email     ON email_logs(to_email);
CREATE INDEX idx_email_logs_status    ON email_logs(tenant_id, status);
CREATE INDEX idx_email_logs_resend_id ON email_logs(resend_message_id);

-- ─────────────────────────────────────────────────────────────
-- SUPPRESSION LIST
-- Emails we must never send to again (bounces, spam complaints,
-- manual unsubscribes). Applied before every send.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_suppressions (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email       TEXT        NOT NULL,
    reason      TEXT        NOT NULL   -- 'bounce', 'complaint', 'unsubscribe', 'manual'
                CHECK (reason IN ('bounce', 'complaint', 'unsubscribe', 'manual')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

CREATE INDEX idx_suppressions_tenant_email ON email_suppressions(tenant_id, email);

-- RLS
ALTER TABLE email_templates   ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaigns   ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_suppressions ENABLE ROW LEVEL SECURITY;

CREATE POLICY email_templates_isolation ON email_templates
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

CREATE POLICY email_campaigns_isolation ON email_campaigns
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

CREATE POLICY email_logs_isolation ON email_logs
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

CREATE POLICY suppressions_isolation ON email_suppressions
    USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- Updated_at triggers
CREATE TRIGGER email_templates_updated_at
    BEFORE UPDATE ON email_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER email_campaigns_updated_at
    BEFORE UPDATE ON email_campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────────────────────
-- SEED SYSTEM TEMPLATES
-- Insert default templates every tenant gets on signup.
-- The application seeds these per tenant when a tenant is created.
-- ─────────────────────────────────────────────────────────────
-- (Templates are seeded programmatically in Go, not SQL,
--  because they need the tenant_id at runtime)