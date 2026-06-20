-- ============================================
--  Disaster Relief Volunteer Registry
--  Database: dbproject
--  PostgreSQL DDL
-- ============================================

-- Drop tables if re-running (order matters due to FKs)
DROP TABLE IF EXISTS DISASTEREVENT_SKILLS;
DROP TABLE IF EXISTS VOLUNTEER_SKILLS;
DROP TABLE IF EXISTS VOLUNTEER_PHONE;
DROP TABLE IF EXISTS VOLUNTEER;
DROP TABLE IF EXISTS DISASTEREVENT;
DROP TABLE IF EXISTS SKILL;

-- ============================================
--  SKILL
-- ============================================
CREATE TABLE SKILL (
    id      SERIAL PRIMARY KEY,
    name    VARCHAR(100) NOT NULL,
    category VARCHAR(100)
);

-- ============================================
--  DISASTEREVENT
-- ============================================
CREATE TABLE DISASTEREVENT (
    id          SERIAL PRIMARY KEY,
    description TEXT,
    lat         DOUBLE PRECISION,
    long        DOUBLE PRECISION,
    status      VARCHAR(50)  NOT NULL DEFAULT 'active',
    start_date  DATE         NOT NULL,
    end_date    DATE
);

-- ============================================
--  VOLUNTEER
-- ============================================
CREATE TABLE VOLUNTEER (
    ssn     VARCHAR(20)  PRIMARY KEY,
    name    VARCHAR(100) NOT NULL,
    status  VARCHAR(50)  NOT NULL DEFAULT 'available',
    id      INT REFERENCES DISASTEREVENT(id) ON DELETE SET NULL
);

-- ============================================
--  VOLUNTEER_PHONE  (multivalued attribute)
-- ============================================
CREATE TABLE VOLUNTEER_PHONE (
    phone   VARCHAR(20),
    ssn     VARCHAR(20) REFERENCES VOLUNTEER(ssn) ON DELETE CASCADE,
    PRIMARY KEY (phone, ssn)
);

-- ============================================
--  VOLUNTEER_SKILLS  (M:N junction)
-- ============================================
CREATE TABLE VOLUNTEER_SKILLS (
    ssn      VARCHAR(20) REFERENCES VOLUNTEER(ssn)  ON DELETE CASCADE,
    skill_id INT         REFERENCES SKILL(id)        ON DELETE CASCADE,
    PRIMARY KEY (ssn, skill_id)
);

-- ============================================
--  DISASTEREVENT_SKILLS  (M:N junction)
-- ============================================
CREATE TABLE DISASTEREVENT_SKILLS (
    event_id INT REFERENCES DISASTEREVENT(id) ON DELETE CASCADE,
    skill_id INT REFERENCES SKILL(id)         ON DELETE CASCADE,
    PRIMARY KEY (event_id, skill_id)
);

-- ============================================
--  SAMPLE DATA
-- ============================================
INSERT INTO SKILL (name, category) VALUES
    ('Nursing',          'Medical'),
    ('CDL License',      'Transport'),
    ('First Aid',        'Medical'),
    ('Search & Rescue',  'Emergency'),
    ('Arabic',           'Language');

INSERT INTO DISASTEREVENT (description, lat, long, status, start_date, end_date) VALUES
    ('Flood in Alexandria', 31.2001, 29.9187, 'active',   '2025-01-10', NULL),
    ('Earthquake response', 30.0626, 31.2497, 'resolved', '2024-11-01', '2024-11-20');

INSERT INTO VOLUNTEER (ssn, name, status, id) VALUES
    ('123-45-6789', 'Ahmed Hassan',  'deployed',  1),
    ('987-65-4321', 'Sara Mohamed',  'available', NULL),
    ('111-22-3333', 'Omar Khalil',   'available', NULL);

INSERT INTO VOLUNTEER_PHONE (phone, ssn) VALUES
    ('01012345678', '123-45-6789'),
    ('01098765432', '987-65-4321'),
    ('01111223333', '111-22-3333');

INSERT INTO VOLUNTEER_SKILLS (ssn, skill_id) VALUES
    ('123-45-6789', 1),
    ('123-45-6789', 2),
    ('987-65-4321', 1),
    ('987-65-4321', 3),
    ('111-22-3333', 4);

INSERT INTO DISASTEREVENT_SKILLS (event_id, skill_id) VALUES
    (1, 1),
    (1, 2),
    (2, 4);