-- =============================================================================
-- 01_base_setup.sql
-- Cortex Code agent profiles: one-time account setup
--
-- What this does
--   1. Creates the CORTEX_CODE.CONFIG schema, where Cortex Code looks for
--      profiles. A profile is an ordinary AGENT object in that schema.
--   2. Creates CORTEX_CODE.SKILLS with a stage to hold skills your profiles
--      hand out (an alternative to the skill catalog).
--   3. Creates two roles:
--        ADMIN_ROLE - builds and maintains profiles
--        USER_ROLE  - can see and select profiles
--      ADMIN_ROLE inherits USER_ROLE, so admins can test what they build.
--
-- Run as : ACCOUNTADMIN (only this file needs it; profiles do not)
-- Re-run : safe. Everything is IF NOT EXISTS, and grants are idempotent.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Settings. Fill these in. They ship blank so a missed value fails loudly
--    instead of creating objects under a name you didn't intend.
-- -----------------------------------------------------------------------------
SET ADMIN_ROLE = '';   -- e.g. COCO_PROFILE_ADMIN
SET USER_ROLE  = '';   -- e.g. COCO_PROFILE_USER
SET ADMIN_USER = '';   -- the user who will administer profiles

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------------------------------
-- 1. Profile container
--    The database and schema names are fixed: Cortex Code only reads profiles
--    from CORTEX_CODE.CONFIG. They are not created automatically. If they are
--    missing, every role (even ACCOUNTADMIN) gets an error when opening profiles.
-- -----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS CORTEX_CODE;
CREATE SCHEMA   IF NOT EXISTS CORTEX_CODE.CONFIG;

-- -----------------------------------------------------------------------------
-- 2. Skill stage (our naming; change it if you like, and update 02 to match)
--    Server-side encryption + directory table so skill files can be listed
--    and read by Cortex Code.
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS CORTEX_CODE.SKILLS;
CREATE STAGE  IF NOT EXISTS CORTEX_CODE.SKILLS.PROFILE_SKILLS
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  DIRECTORY  = (ENABLE = TRUE)
  COMMENT    = 'Skill folders (each with a SKILL.md) referenced by Cortex Code agent profiles';

-- -----------------------------------------------------------------------------
-- 3. Cross-region inference
--    Cortex Code needs it. Check the value; change it only if it is DISABLED,
--    choosing the broadest setting your data residency rules allow.
-- -----------------------------------------------------------------------------
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'AWS_US';

-- -----------------------------------------------------------------------------
-- 4. Roles
-- -----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS IDENTIFIER($ADMIN_ROLE);
CREATE ROLE IF NOT EXISTS IDENTIFIER($USER_ROLE);
GRANT ROLE IDENTIFIER($USER_ROLE)  TO ROLE IDENTIFIER($ADMIN_ROLE);  -- admins inherit user access
GRANT ROLE IDENTIFIER($ADMIN_ROLE) TO ROLE SYSADMIN;                 -- keep the hierarchy tidy
GRANT ROLE IDENTIFIER($ADMIN_ROLE) TO USER IDENTIFIER($ADMIN_USER);
-- Give USER_ROLE to the people (or functional roles) who should get profiles:
-- GRANT ROLE IDENTIFIER($USER_ROLE) TO ROLE <ANALYST_ROLE>;

-- -----------------------------------------------------------------------------
-- 5. Grants
--    Users: see the schema and read skill files.
--    Admins: create profiles (AGENT objects) and upload skills.
--    Profile-level USAGE is granted per profile in 02_profiles.sql.
-- -----------------------------------------------------------------------------
GRANT USAGE ON DATABASE CORTEX_CODE        TO ROLE IDENTIFIER($USER_ROLE);
GRANT USAGE ON SCHEMA   CORTEX_CODE.CONFIG TO ROLE IDENTIFIER($USER_ROLE);
GRANT USAGE ON SCHEMA   CORTEX_CODE.SKILLS TO ROLE IDENTIFIER($USER_ROLE);
GRANT READ  ON STAGE    CORTEX_CODE.SKILLS.PROFILE_SKILLS TO ROLE IDENTIFIER($USER_ROLE);

GRANT CREATE AGENT ON SCHEMA CORTEX_CODE.CONFIG TO ROLE IDENTIFIER($ADMIN_ROLE);
-- Internal stages require READ to be granted directly before WRITE
-- (READ inherited through USER_ROLE doesn't satisfy this).
GRANT READ, WRITE ON STAGE CORTEX_CODE.SKILLS.PROFILE_SKILLS TO ROLE IDENTIFIER($ADMIN_ROLE);

-- -----------------------------------------------------------------------------
-- 6. Check
-- -----------------------------------------------------------------------------
SHOW SCHEMAS IN DATABASE CORTEX_CODE;
SHOW GRANTS ON SCHEMA CORTEX_CODE.CONFIG;
SHOW GRANTS ON STAGE  CORTEX_CODE.SKILLS.PROFILE_SKILLS;
