-- =============================================================================
-- 02_profiles.sql
-- Cortex Code agent profiles: create example profiles and share them
--
-- What a profile is
--   An AGENT object in CORTEX_CODE.CONFIG whose specification bundles:
--     models.orchestration   which model Cortex Code uses ("auto" = let it pick)
--     instructions.response  guidance applied to every conversation
--     skills                 skills Cortex Code loads on demand when relevant
--   Those are the only supported keys. Don't put secrets in a spec.
--
-- What this file builds
--   DEFAULT   model + house style, no skills. Applied automatically when a
--             role can see more than one profile.
--   TEAM_SQL  adds an example skill (skills/team-sql-conventions) served
--             from the stage created in 01_base_setup.sql.
--
-- How users get a profile
--   Profiles your role can see      -> profile applied
--   none                            -> no profile
--   exactly one                     -> that one
--   several, one named DEFAULT      -> DEFAULT
--   several, none named DEFAULT     -> none; user picks one
--   Picking a profile never grants data access; queries still run as the
--   user's active role.
--
-- Run as : ADMIN_ROLE from 01 (so the admin role, not ACCOUNTADMIN, owns profiles)
-- Run from the repo root so the PUT below finds skills/.
-- Re-run : safe. CREATE ... IF NOT EXISTS leaves existing profiles untouched.
--          Never use CREATE OR REPLACE on a profile: it can drop its grants.
--          To change a profile, use the ALTER template at the bottom.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Settings: same values as 01_base_setup.sql. Blank fails loudly on purpose.
-- -----------------------------------------------------------------------------
SET ADMIN_ROLE = '';   -- e.g. COCO_PROFILE_ADMIN
SET USER_ROLE  = '';   -- e.g. COCO_PROFILE_USER

USE ROLE IDENTIFIER($ADMIN_ROLE);

-- -----------------------------------------------------------------------------
-- 1. Upload the example skill
--    A skill is a folder with a SKILL.md at its root. The SKILL.md "name:"
--    must match the skill name used in the profile spec below.
--    PUT works from the Snowflake CLI (snow sql -f). In a Snowsight worksheet,
--    PUT isn't available: upload skills/team-sql-conventions/SKILL.md through
--    Data > Databases > CORTEX_CODE > SKILLS > Stages > PROFILE_SKILLS, into
--    a folder named team-sql-conventions, then skip this step.
-- -----------------------------------------------------------------------------
PUT file://skills/team-sql-conventions/SKILL.md
    @CORTEX_CODE.SKILLS.PROFILE_SKILLS/team-sql-conventions/
    AUTO_COMPRESS = FALSE OVERWRITE = TRUE;
ALTER STAGE CORTEX_CODE.SKILLS.PROFILE_SKILLS REFRESH;
LIST @CORTEX_CODE.SKILLS.PROFILE_SKILLS;

-- -----------------------------------------------------------------------------
-- 2. DEFAULT profile
--    The name must be exactly DEFAULT (uppercase, unquoted) to be auto-applied.
-- -----------------------------------------------------------------------------
CREATE AGENT IF NOT EXISTS CORTEX_CODE.CONFIG.DEFAULT
  COMMENT = 'Cortex Code profile: house style, no skills'
  FROM SPECIFICATION
$$
models:
  orchestration: auto
instructions:
  response: |
    Be concise. Lead with the answer, then supporting detail.
    Name every Snowflake object you used by its fully qualified name.
$$;

-- -----------------------------------------------------------------------------
-- 3. TEAM_SQL profile: instructions + one skill from the stage
--    Skill sources:
--      Stage            type: STAGE             path: "@DB.SCHEMA.STAGE/<folder>/"
--      Skill catalog    type: CORTEX_EXTENSION  path: "DB.SCHEMA.EXTENSION_NAME"
--    (Some PrPr docs show STAGE with a snow://cortex_extension/... path for
--    catalog skills. That form is rejected with "agent spec is invalid".)
-- -----------------------------------------------------------------------------
CREATE AGENT IF NOT EXISTS CORTEX_CODE.CONFIG.TEAM_SQL
  COMMENT = 'Cortex Code profile: team SQL conventions'
  FROM SPECIFICATION
$$
models:
  orchestration: auto
instructions:
  response: |
    You help the team write and review Snowflake SQL.
    Follow the team-sql-conventions skill for any SQL you produce.
skills:
  - name: team-sql-conventions
    source:
      type: STAGE
      path: "@CORTEX_CODE.SKILLS.PROFILE_SKILLS/team-sql-conventions/"
  # Optional: add a skill published to the skill catalog.
  # - name: <name from its SKILL.md>
  #   source:
  #     type: CORTEX_EXTENSION
  #     path: "<DB>.<SCHEMA>.<EXTENSION_NAME>"
$$;

-- -----------------------------------------------------------------------------
-- 4. Share the profiles
--    USAGE on the profile makes it visible to the role. Users also need read
--    access to every skill source (stage READ was granted in 01). For a
--    catalog skill, its owner runs:
--      GRANT READ ON CORTEX EXTENSION <DB>.<SCHEMA>.<NAME> TO ROLE <USER_ROLE>;
--    Note: granting a role a second profile changes what it gets automatically
--    unless one of its profiles is named DEFAULT.
-- -----------------------------------------------------------------------------
GRANT USAGE ON AGENT CORTEX_CODE.CONFIG.DEFAULT  TO ROLE IDENTIFIER($USER_ROLE);
GRANT USAGE ON AGENT CORTEX_CODE.CONFIG.TEAM_SQL TO ROLE IDENTIFIER($USER_ROLE);

-- -----------------------------------------------------------------------------
-- 5. Check
-- -----------------------------------------------------------------------------
SHOW AGENTS IN SCHEMA CORTEX_CODE.CONFIG;
DESCRIBE AGENT CORTEX_CODE.CONFIG.TEAM_SQL;
SHOW GRANTS ON AGENT CORTEX_CODE.CONFIG.DEFAULT;
SHOW GRANTS ON AGENT CORTEX_CODE.CONFIG.TEAM_SQL;

-- -----------------------------------------------------------------------------
-- 6. Changing a profile later (template; don't run as-is)
--    SET SPECIFICATION replaces the whole spec, so include every field you
--    want to keep. Save the current spec first (DESCRIBE AGENT). Grants stay.
-- -----------------------------------------------------------------------------
-- ALTER AGENT CORTEX_CODE.CONFIG.TEAM_SQL
--   MODIFY LIVE VERSION SET SPECIFICATION =
-- $$
-- models:
--   orchestration: auto
-- instructions:
--   response: |
--     ...
-- skills:
--   - name: team-sql-conventions
--     source:
--       type: STAGE
--       path: "@CORTEX_CODE.SKILLS.PROFILE_SKILLS/team-sql-conventions/"
-- $$;
--
-- Remove a profile (save its spec and grants first):
-- DROP AGENT CORTEX_CODE.CONFIG.TEAM_SQL;
