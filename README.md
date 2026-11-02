# Cortex Code agent profiles: bootstrap example

An **agent profile** is a reusable Cortex Code configuration. It bundles three things:
- a model choice
- response instructions
- a set of skills

Each profile is stored as an `AGENT` object in `CORTEX_CODE.CONFIG`. Admins define a profile once, and every user whose role can see it gets the same behavior in the Cortex Code CLI, Desktop, and Snowsight. Users don't have to install anything.

This repo sets everything up end to end and includes one working example skill. You can use it as-is to see profiles working, then swap in your own instructions and skills.

## What's in the repo

```
01_base_setup.sql                    one-time account setup (ACCOUNTADMIN)
02_profiles.sql                      example profiles + grants (admin role)
skills/team-sql-conventions/SKILL.md example skill the TEAM_SQL profile hands out
```

| Object | Created by | Purpose |
| --- | --- | --- |
| `CORTEX_CODE.CONFIG` | 01 | The only schema Cortex Code reads profiles from. It is not created automatically. |
| `CORTEX_CODE.SKILLS.PROFILE_SKILLS` | 01 | Stage that holds skill folders your profiles reference. |
| Admin role / user role | 01 | Admins build profiles; users see and select them. The admin role inherits the user role. |
| `CORTEX_CODE.CONFIG.DEFAULT` | 02 | Model plus house style. Applied automatically when a role can see more than one profile. |
| `CORTEX_CODE.CONFIG.TEAM_SQL` | 02 | Instructions plus the example skill. |

## Setup

1. **Fill in the `SET` block** at the top of each file: `ADMIN_ROLE`, `USER_ROLE`, and in file 01 also `ADMIN_USER`. Use the same role names in both files. The values ship blank on purpose, so a missed value fails immediately.
2. **Run file 01 as ACCOUNTADMIN.**
3. **Run file 02 from the repo root.** File 02 switches to the admin role itself, so the admin role owns the profiles.
   ```
   snow sql -c <connection> -f 01_base_setup.sql
   snow sql -c <connection> -f 02_profiles.sql
   ```
   In Snowsight, run each file in a worksheet instead. Worksheets can't run `PUT`, so upload `SKILL.md` through the stage UI first (the comment in step 1 of file 02 explains how).
4. **Give people the user role:** `GRANT ROLE <USER_ROLE> TO ROLE <their functional role>;`

Both files can be re-run safely. They never use `CREATE OR REPLACE`, because replacing a profile can drop its grants.

## How a profile is chosen

| Profiles your role can see | Profile applied |
| --- | --- |
| None | No profile |
| Exactly one | That profile |
| More than one, including `DEFAULT` | `DEFAULT` |
| More than one, none named `DEFAULT` | None; choose one manually |

A choice the user makes themselves, including choosing none, always wins over the automatic pick. Switching roles can change which profile applies. A profile is a convenience, not a security control: queries still run with the user's active role.

## Verify

1. Switch to the user role.
2. Open the profile list:
   - CLI: `/profile list`
   - Desktop: Settings > Profiles
   - Snowsight: Cortex Code > Agent settings > Profiles
3. `DEFAULT` should be applied, and `TEAM_SQL` should be listed.
4. Select `TEAM_SQL`, start a **new** chat (existing chats keep their old profile), and ask for a query. The answer should end with `Conventions applied: team-sql-conventions`, which confirms the skill loaded.
5. Admins can also view and manage profiles at Snowsight > CoCo Admin > Profiles.

## Making it your own

- **Instructions:** edit `instructions.response` in file 02.
- **Your own stage skill:**
  1. Add a folder under `skills/` containing a `SKILL.md`, and make sure its `name:` field matches the name you'll use in the spec.
  2. `PUT` the folder to the stage.
  3. Add a `type: STAGE` entry to the profile's `skills` list.
- **Skill-catalog skill:**
  1. Add a `type: CORTEX_EXTENSION` entry with `path: "DB.SCHEMA.NAME"`. A commented example is in file 02.
  2. Have the skill's owner run `GRANT READ ON CORTEX EXTENSION ... TO ROLE <USER_ROLE>`.
  3. Don't use `STAGE` with a `snow://cortex_extension/...` path. That form is rejected with "agent spec is invalid".
- **Change an existing profile:** use the `ALTER AGENT ... MODIFY LIVE VERSION SET SPECIFICATION` template at the bottom of file 02. It replaces the whole spec, so run `DESCRIBE AGENT` first. Grants are preserved.
- **More profiles:** each additional profile visible to a role means that role only gets a profile automatically through `DEFAULT`. Plan which roles get which profiles.
