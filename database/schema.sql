-- ============================================================
-- Clínica Vida · Schema do banco PostgreSQL
-- Sistema de atendimento WhatsApp + n8n + Google Calendar
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- PACIENTES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE NOT NULL,             -- ex: 5511999998888 (sem +)
    name VARCHAR(120),
    email VARCHAR(120),
    birth_date DATE,
    insurance VARCHAR(80),                          -- convênio
    insurance_number VARCHAR(60),
    notes TEXT,
    consent_lgpd BOOLEAN DEFAULT false,             -- consentimento LGPD
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_patients_phone ON patients(phone);
CREATE INDEX idx_patients_name ON patients(name);

-- ------------------------------------------------------------
-- MÉDICOS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(120) NOT NULL,
    specialty VARCHAR(80) NOT NULL,
    registry VARCHAR(30),                          -- CRM
    google_calendar_id VARCHAR(200),               -- email do calendar dedicado
    default_duration_min INT DEFAULT 30,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seeds iniciais (ajuste conforme sua clínica)
INSERT INTO doctors (name, specialty, registry, google_calendar_id, default_duration_min) VALUES
    ('Dr. Carlos Andrade',  'Clínico Geral', 'CRM-SP 123456', 'clinico-geral@clinica.com.br', 30),
    ('Dra. Beatriz Lima',   'Cardiologia',   'CRM-SP 234567', 'cardio@clinica.com.br',        40),
    ('Dr. Roberto Santos',  'Dermatologia',  'CRM-SP 345678', 'derma@clinica.com.br',         30),
    ('Dra. Ana Costa',      'Ginecologia',   'CRM-SP 456789', 'gineco@clinica.com.br',        40),
    ('Dra. Juliana Pereira','Pediatria',     'CRM-SP 567890', 'pediatra@clinica.com.br',      30),
    ('Dr. Marcos Oliveira', 'Ortopedia',     'CRM-SP 678901', 'orto@clinica.com.br',          40)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- AGENDAMENTOS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES patients(id) ON DELETE SET NULL,
    phone VARCHAR(20) NOT NULL,
    patient_name VARCHAR(120) NOT NULL,

    specialty VARCHAR(80) NOT NULL,
    doctor VARCHAR(120),

    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,

    calendar_event_id VARCHAR(200),                -- ID do evento no Google Calendar
    calendar_id VARCHAR(200),                      -- Calendar usado

    status VARCHAR(20) DEFAULT 'confirmed',       -- pending | confirmed | cancelled | completed | no_show

    notes TEXT,
    insurance VARCHAR(80),

    -- Lembretes
    reminder_24h_sent BOOLEAN DEFAULT false,
    reminder_24h_sent_at TIMESTAMPTZ,
    reminder_2h_sent BOOLEAN DEFAULT false,
    reminder_2h_sent_at TIMESTAMPTZ,

    -- Feedback
    feedback_sent BOOLEAN DEFAULT false,
    feedback_sent_at TIMESTAMPTZ,
    feedback_rating SMALLINT,                       -- 1 a 5
    feedback_comment TEXT,

    -- Auditoria
    source VARCHAR(40) DEFAULT 'whatsapp',         -- whatsapp | site | telefone | presencial
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    cancelled_at TIMESTAMPTZ,
    rescheduled_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_appts_phone ON appointments(phone);
CREATE INDEX idx_appts_status ON appointments(status);
CREATE INDEX idx_appts_start ON appointments(start_time);
CREATE INDEX idx_appts_patient ON appointments(patient_id);

-- ------------------------------------------------------------
-- ESTADO DA CONVERSA (state machine)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversation_state (
    phone VARCHAR(20) PRIMARY KEY,
    state VARCHAR(40) NOT NULL DEFAULT 'INITIAL',  -- INITIAL, MENU, AWAITING_SPECIALTY, AWAITING_DATE, AWAITING_TIME, AWAITING_NAME, AWAITING_CONFIRM, IN_HUMAN_QUEUE
    context JSONB DEFAULT '{}'::jsonb,             -- dados coletados durante o fluxo
    last_intent VARCHAR(40),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '30 minutes'
);

CREATE INDEX idx_conv_state_expires ON conversation_state(expires_at);

-- ------------------------------------------------------------
-- LOG DE CONVERSAS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversation_log (
    id BIGSERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    intent VARCHAR(40),
    confidence DECIMAL(3,2),
    message_text TEXT,
    response_text TEXT,
    message_id VARCHAR(80),                        -- ID da msg do WhatsApp
    direction VARCHAR(10) DEFAULT 'inbound',       -- inbound | outbound
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conv_log_phone ON conversation_log(phone);
CREATE INDEX idx_conv_log_created ON conversation_log(created_at DESC);

-- ------------------------------------------------------------
-- FOLLOW-UPS (lembretes personalizados)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS followups (
    id BIGSERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    patient_name VARCHAR(120),
    message TEXT NOT NULL,
    scheduled_for TIMESTAMPTZ NOT NULL,
    sent BOOLEAN DEFAULT false,
    sent_at TIMESTAMPTZ,
    appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_followups_due ON followups(scheduled_for) WHERE sent = false;

-- ------------------------------------------------------------
-- TRANSFERÊNCIAS PARA HUMANO (fila)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS human_queue (
    id BIGSERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    patient_name VARCHAR(120),
    reason VARCHAR(120),
    last_message TEXT,
    assigned_to VARCHAR(80),                       -- atendente
    status VARCHAR(20) DEFAULT 'pending',          -- pending | in_service | resolved | abandoned
    priority VARCHAR(20) DEFAULT 'normal',         -- low | normal | high | urgent
    created_at TIMESTAMPTZ DEFAULT NOW(),
    picked_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_human_queue_status ON human_queue(status, priority);

-- ------------------------------------------------------------
-- VIEW: dashboard simples
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_daily_metrics AS
SELECT
    DATE(start_time) AS day,
    COUNT(*) AS total_appointments,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed,
    COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled,
    COUNT(*) FILTER (WHERE status = 'no_show') AS no_show,
    COUNT(*) FILTER (WHERE source = 'whatsapp') AS from_whatsapp,
    ROUND(AVG(feedback_rating)::numeric, 2) AS avg_rating
FROM appointments
WHERE start_time >= NOW() - INTERVAL '90 days'
GROUP BY DATE(start_time)
ORDER BY day DESC;

-- ------------------------------------------------------------
-- TRIGGER: updated_at automático
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS patients_updated ON patients;
CREATE TRIGGER patients_updated BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION trg_updated_at();

DROP TRIGGER IF EXISTS appts_updated ON appointments;
CREATE TRIGGER appts_updated BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION trg_updated_at();

DROP TRIGGER IF EXISTS conv_state_updated ON conversation_state;
CREATE TRIGGER conv_state_updated BEFORE UPDATE ON conversation_state
    FOR EACH ROW EXECUTE FUNCTION trg_updated_at();

-- ============================================================
-- FIM · pronto pra `psql -f schema.sql`
-- ============================================================
