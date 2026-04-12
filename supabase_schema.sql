-- ============================================================
-- JYOTISH RESEARCH COLLECTOR — SUPABASE SCHEMA
-- ============================================================
-- Repository : https://github.com/sbhaid/JyotishResearchCollector
-- Database   : PostgreSQL (Supabase)
-- Last updated: 2026-04
--
-- TABLE OVERVIEW
-- ┌─────────────────────┬──────────────────────────────────────────┐
-- │ Table               │ Purpose                                  │
-- ├─────────────────────┼──────────────────────────────────────────┤
-- │ persons             │ One row per chart subject                │
-- │ planet_positions    │ Planetary positions across all vargas    │
-- │ chart_lords         │ House lordships per varga                │
-- │ events              │ Life events with dasha, transit, notes   │
-- └─────────────────────┴──────────────────────────────────────────┘
-- ============================================================


-- ============================================================
-- 1. PERSONS
-- Core biographical and astrological metadata per subject.
-- ============================================================

CREATE TABLE IF NOT EXISTS persons (
  -- Identity
  id            text        PRIMARY KEY,          -- uid() from JS e.g. 'lf3k2abc'
  name          text        NOT NULL,

  -- Birth data
  dob           date,                             -- Date of birth
  tob           time,                             -- Time of birth
  pob           text,                             -- Place of birth (free text)
  gender        text CHECK (gender IN ('Male','Female','Other',NULL)),

  -- Raw JHora paste (Body/Longitude/Nakshatra table)
  meta_raw      text,                             -- Full JHora karaka table paste

  -- Parsed Jyotish metadata (auto-extracted from meta_raw)
  ak            text,                             -- Atmakaraka planet
  amk           text,                             -- Amatyakaraka planet
  d1_lagna      text,                             -- D1 Lagna sign

  -- Raw varga paste (Body D-1 D-9 D-10 table)
  raw_varga     text,                             -- Full JHora varga table paste

  -- Researcher notes
  notes         text,                             -- Free-form Jyotish observations

  -- Audit
  created_at    timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_persons_name ON persons(name);
CREATE INDEX IF NOT EXISTS idx_persons_ak   ON persons(ak);
CREATE INDEX IF NOT EXISTS idx_persons_amk  ON persons(amk);
CREATE INDEX IF NOT EXISTS idx_persons_d1_lagna ON persons(d1_lagna);


-- ============================================================
-- 2. PLANET_POSITIONS
-- One row per planet per varga per person.
-- Populated by parsing the JHora varga table paste.
-- Vargas stored: D1, D9, D10, D24
-- ============================================================

CREATE TABLE IF NOT EXISTS planet_positions (
  id         bigserial    PRIMARY KEY,
  person_id  text         NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  varga      text         NOT NULL,   -- 'D1' | 'D9' | 'D10' | 'D24'
  planet     text         NOT NULL,   -- 'Lagna'|'Sun'|'Moon'|'Mars'|'Mercury'|
                                      --  'Jupiter'|'Venus'|'Saturn'|'Rahu'|'Ketu'
  sign       text         NOT NULL,   -- Full sign name e.g. 'Aries'
  house      integer,                 -- House number 1–12 (computed from lagna)
  deg        integer,                 -- Degrees within sign 0–29
  min        integer                  -- Minutes 0–59
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pp_person    ON planet_positions(person_id);
CREATE INDEX IF NOT EXISTS idx_pp_varga     ON planet_positions(varga);
CREATE INDEX IF NOT EXISTS idx_pp_planet    ON planet_positions(planet);
CREATE INDEX IF NOT EXISTS idx_pp_house     ON planet_positions(house);
CREATE INDEX IF NOT EXISTS idx_pp_sign      ON planet_positions(sign);
-- Composite — most common research query pattern
CREATE INDEX IF NOT EXISTS idx_pp_varga_house   ON planet_positions(person_id, varga, house);
CREATE INDEX IF NOT EXISTS idx_pp_varga_planet  ON planet_positions(person_id, varga, planet);


-- ============================================================
-- 3. CHART_LORDS
-- One row per house per varga per person.
-- Records the primary lord and co-lord (joint ownership system).
--
-- OWNERSHIP SYSTEM USED (Nadi / custom):
--   Rahu  — primary owner of Aquarius, joint owner of Virgo
--   Ketu  — primary owner of Scorpio,  joint owner of Pisces
--   All other signs follow standard Parashari ownership.
-- ============================================================

CREATE TABLE IF NOT EXISTS chart_lords (
  id         bigserial    PRIMARY KEY,
  person_id  text         NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  varga      text         NOT NULL,   -- 'D1' | 'D9' | 'D10' | 'D24'
  house      integer      NOT NULL,   -- 1–12
  lord       text         NOT NULL,   -- Primary lord planet name
  co_lord    text                     -- Joint owner (only for houses 6,8,11,12)
                                      -- Virgo→Rahu, Scorpio→Ketu,
                                      -- Aquarius→Rahu, Pisces→Ketu
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cl_person    ON chart_lords(person_id);
CREATE INDEX IF NOT EXISTS idx_cl_varga     ON chart_lords(varga);
CREATE INDEX IF NOT EXISTS idx_cl_house     ON chart_lords(house);
CREATE INDEX IF NOT EXISTS idx_cl_lord      ON chart_lords(lord);
-- Composite — used by research query JOIN
CREATE INDEX IF NOT EXISTS idx_cl_varga_house ON chart_lords(person_id, varga, house);


-- ============================================================
-- 4. EVENTS
-- Life events linked to a person, with dasha timing,
-- transit notes, and astrological observations.
-- ============================================================

CREATE TABLE IF NOT EXISTS events (
  -- Identity
  id            text        PRIMARY KEY,          -- uid() from JS
  person_id     text        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,

  -- Event details
  event_date    date,
  event_type    text        NOT NULL,
  -- Allowed event types:
  --   'first_job'             First employment
  --   'job_switch'            Change of employer
  --   'promotion'             Promotion / elevation
  --   'voluntary_resignation' Resigned by choice
  --   'layoff'                Involuntary job loss
  --   'move_abroad'           Relocation abroad
  --   'business_start'        Started own business
  --   'big_jump'              Significant leap (role/income/recognition)
  --   'career_break'          Gap in employment
  --   'marriage'              Marriage
  --   'child_birth'           Birth of child
  --   'illness'               Significant illness
  --   'accident'              Accident or injury
  --   'other'                 Other life event

  -- Dasha at time of event
  maha          text,                             -- Mahadasha planet
  antar         text,                             -- Antardasha planet
  pratyantar    text,                             -- Pratyantardasha planet

  -- Transit notes (manual entry — free text)
  -- e.g. "Ju 4H Cancer exalted, Sa 12H Pisces, Ra 3H Gemini"
  transit_notes text,

  -- Astrological observations (researcher's analysis of this event)
  -- Larger free-text field for pattern notes, yoga connections, etc.
  observations  text,

  -- Legacy notes field (retained for compatibility)
  notes         text
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ev_person     ON events(person_id);
CREATE INDEX IF NOT EXISTS idx_ev_date       ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_ev_type       ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_ev_maha       ON events(maha);
CREATE INDEX IF NOT EXISTS idx_ev_antar      ON events(antar);
-- Composite — research query filters
CREATE INDEX IF NOT EXISTS idx_ev_type_date  ON events(event_type, event_date);
CREATE INDEX IF NOT EXISTS idx_ev_maha_type  ON events(maha, event_type);


-- ============================================================
-- 5. RPC FUNCTION — run_research_query
-- Executes dynamic SQL from the research query builder.
-- Called by: runQB() in the frontend via sb.rpc()
--
-- SECURITY NOTE:
-- This function uses EXECUTE with user-supplied SQL.
-- It is scoped to SELECT only by the frontend query builder,
-- but the function itself does not enforce read-only access.
-- Restrict via Supabase RLS policies as needed.
-- ============================================================

CREATE OR REPLACE FUNCTION run_research_query(query_sql text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  EXECUTE 'SELECT json_agg(t) FROM (' || query_sql || ') t' INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;


-- ============================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- Supabase requires RLS to be enabled for public access.
-- These policies allow full access via the publishable key.
-- Adjust for multi-user environments.
-- ============================================================

ALTER TABLE persons          ENABLE ROW LEVEL SECURITY;
ALTER TABLE planet_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_lords      ENABLE ROW LEVEL SECURITY;
ALTER TABLE events           ENABLE ROW LEVEL SECURITY;

-- Allow all operations for now (single-user research tool)
CREATE POLICY "allow_all_persons"          ON persons          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_planet_positions" ON planet_positions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_chart_lords"      ON chart_lords      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_events"           ON events           FOR ALL USING (true) WITH CHECK (true);


-- ============================================================
-- 7. MIGRATION HISTORY
-- Run these in order if building schema from scratch,
-- or use the full CREATE TABLE statements above.
-- ============================================================

-- v1 — Initial schema (2025)
-- CREATE TABLE persons (id, name, dob, tob, pob, gender, notes, raw_varga, created_at)
-- CREATE TABLE planet_positions (id, person_id, varga, planet, sign, house, deg, min)
-- CREATE TABLE chart_lords (id, person_id, varga, house, lord, co_lord)
-- CREATE TABLE events (id, person_id, event_date, event_type, maha, antar, pratyantar, notes)
-- CREATE FUNCTION run_research_query(query_sql text)

-- v2 — Jyotish metadata fields (2026-04)
ALTER TABLE persons
  ADD COLUMN IF NOT EXISTS ak       text,
  ADD COLUMN IF NOT EXISTS amk      text,
  ADD COLUMN IF NOT EXISTS d1_lagna text,
  ADD COLUMN IF NOT EXISTS meta_raw text;

-- v3 — Event enrichment fields (2026-04)
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS transit_notes text,
  ADD COLUMN IF NOT EXISTS observations  text;


-- ============================================================
-- 8. USEFUL RESEARCH QUERIES
-- Reference queries for manual analysis and verification.
-- ============================================================

-- 8.1 All persons with AK and AmK
SELECT name, dob, d1_lagna, ak, amk
FROM persons
ORDER BY name;

-- 8.2 All events for a person
SELECT e.event_date, e.event_type, e.maha, e.antar, e.pratyantar,
       e.transit_notes, e.observations
FROM events e
JOIN persons p ON p.id = e.person_id
WHERE p.name = 'PERSON_NAME_HERE'
ORDER BY e.event_date;

-- 8.3 All promotions where Mahadasha lord rules 10H in D1
SELECT p.name, p.dob, e.event_date, e.maha, e.antar, e.transit_notes
FROM events e
JOIN persons p ON p.id = e.person_id
LEFT JOIN chart_lords cl ON cl.person_id = e.person_id
  AND cl.varga = 'D1' AND cl.house = 10
WHERE e.event_type = 'promotion'
  AND (e.maha = cl.lord OR e.maha = cl.co_lord)
ORDER BY e.event_date;

-- 8.4 All career events where Rahu is Mahadasha
SELECT p.name, p.dob, p.ak, p.amk,
       e.event_date, e.event_type, e.antar, e.transit_notes
FROM events e
JOIN persons p ON p.id = e.person_id
WHERE e.maha = 'Rahu'
  AND e.event_type IN ('first_job','promotion','job_switch','big_jump','business_start')
ORDER BY e.event_date;

-- 8.5 Events where AmK is active in Maha or Antar dasha
SELECT p.name, p.amk, e.event_date, e.event_type,
       e.maha, e.antar, e.observations
FROM events e
JOIN persons p ON p.id = e.person_id
WHERE p.amk IS NOT NULL
  AND (e.maha = p.amk OR e.antar = p.amk)
ORDER BY p.name, e.event_date;

-- 8.6 Saturn as 10L — sitting in which houses at career events
SELECT p.name, e.event_date, e.event_type, e.maha, e.antar,
       pp.house AS saturn_d1_house, pp.sign AS saturn_sign
FROM events e
JOIN persons p ON p.id = e.person_id
JOIN planet_positions pp ON pp.person_id = e.person_id
  AND pp.varga = 'D1' AND pp.planet = 'Saturn'
JOIN chart_lords cl ON cl.person_id = e.person_id
  AND cl.varga = 'D1' AND cl.house = 10
WHERE cl.lord = 'Saturn' OR cl.co_lord = 'Saturn'
ORDER BY pp.house, e.event_date;

-- 8.7 Frequency: which Mahadasha planet appears most at promotions
SELECT e.maha AS mahadasha, COUNT(*) AS count
FROM events e
WHERE e.event_type = 'promotion'
  AND e.maha IS NOT NULL
GROUP BY e.maha
ORDER BY count DESC;

-- 8.8 Frequency: event type distribution across all persons
SELECT event_type, COUNT(*) AS total_events,
       COUNT(DISTINCT person_id) AS persons_affected
FROM events
GROUP BY event_type
ORDER BY total_events DESC;

-- 8.9 D1 Lagna distribution across all persons
SELECT d1_lagna, COUNT(*) AS count
FROM persons
WHERE d1_lagna IS NOT NULL
GROUP BY d1_lagna
ORDER BY count DESC;

-- 8.10 All first jobs — planet positions at time of birth (natal snapshot)
SELECT p.name, p.dob, p.d1_lagna, p.ak, p.amk,
       e.event_date, e.maha, e.antar, e.transit_notes
FROM events e
JOIN persons p ON p.id = e.person_id
WHERE e.event_type = 'first_job'
ORDER BY e.event_date;

-- 8.11 Jupiter transit — manual verification helper
-- (transit_notes field contains manual entry like "Ju 4H Cancer exalted")
SELECT p.name, e.event_date, e.event_type,
       e.maha, e.antar, e.transit_notes
FROM events e
JOIN persons p ON p.id = e.person_id
WHERE e.transit_notes ILIKE '%Ju%'
  AND e.event_type IN ('promotion','big_jump','first_job')
ORDER BY e.event_date;

-- 8.12 Full research export — flat table (mirrors CSV export)
SELECT
  p.name          AS person_name,
  p.dob,
  p.pob,
  p.gender,
  p.ak,
  p.amk,
  p.d1_lagna,
  e.event_date,
  e.event_type,
  e.maha,
  e.antar,
  e.pratyantar,
  e.transit_notes,
  e.observations
FROM events e
JOIN persons p ON p.id = e.person_id
ORDER BY p.name, e.event_date;


-- ============================================================
-- 9. SCHEMA DIAGRAM (text)
--
--  persons
--    id ──────────────────────────────────────────────┐
--    name, dob, tob, pob, gender                      │
--    meta_raw → ak, amk, d1_lagna (parsed)            │
--    raw_varga (JHora varga table paste)               │
--    notes, created_at                                 │
--         │                                            │
--         ├── planet_positions                         │
--         │     person_id ──────────────────────── FK─┘
--         │     varga (D1/D9/D10/D24)
--         │     planet, sign, house, deg, min
--         │
--         ├── chart_lords
--         │     person_id ──────────────────────── FK
--         │     varga, house, lord, co_lord
--         │
--         └── events
--               person_id ──────────────────────── FK
--               event_date, event_type
--               maha, antar, pratyantar
--               transit_notes (manual free text)
--               observations  (researcher analysis)
--               notes (legacy)
--
-- ============================================================
-- END OF SCHEMA
-- ============================================================
