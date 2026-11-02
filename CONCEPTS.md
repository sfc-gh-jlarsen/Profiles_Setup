# Cortex Code agent profiles: concepts and a worked scenario

This is a companion to the setup scripts in this repo. The scripts show *how* to build a profile. This document covers *why* you would build one, and how to think about profiles once more than one team uses Cortex Code.

## The idea in one paragraph

An agent profile is a **named starting point** for Cortex Code. It sets three things:
- which model to use
- how to respond
- which skills to have on hand

An admin defines the profile once. Everyone whose role can see it gets the same experience in the CLI, Desktop, and Snowsight, without installing or configuring anything. A profile works the way a team's project template or IDE workspace settings do: it sets up the tool for the job, so people don't spend their first ten minutes recreating someone else's setup.

## What a profile is, and what it isn't

| A profile is | A profile is not |
| --- | --- |
| A convenience: sensible defaults for a kind of work | A security boundary |
| Tied to a **persona**: a way of working | Tied to data access |
| A way to share skills and conventions | A way to grant privileges |
| Something a user can switch or turn off | Something that changes what a user can do |

The most important line: **selecting a profile never grants access to data.** Every query still runs with the user's active role. If an analyst's role can't read the payroll schema, no profile will change that. To control what Cortex Code can *do*, use Snowflake RBAC and Cortex Code guardrails. Profiles control what Cortex Code is *good at* for a given person.

That split keeps profiles low-risk to roll out. You can be generous with them, because the worst case is that someone gets instructions or skills that don't fit their task.

## Think in personas, not org charts

A profile works best when it describes a way of working rather than a department. Use these questions:

- **What does this person usually ask Cortex Code to do?** Write SQL, build pipelines, review a dashboard, explain a variance?
- **What should every answer look like?** A short table first? Fully qualified object names? Plain English with no jargon?
- **What does the team keep re-explaining?** Naming conventions, the right certified tables, how fiscal periods work, brand standards for charts. Those belong in skills.

One person may wear more than one hat. That's expected: they pick the profile that fits the task at hand.

## A worked scenario: a manufacturing company

Picture a mid-sized manufacturer, call it Northwind Industrial. They run on Snowflake and roll out Cortex Code to four groups. Each group already has a functional role in Snowflake that controls its data access.

### The people

| Persona | Snowflake role (data access) | What they do in Cortex Code |
| --- | --- | --- |
| **Priya, data engineer** | `DE_ROLE` | Builds and debugs pipelines, dynamic tables, and dbt models |
| **Marcus, supply chain analyst** | `SUPPLY_ANALYST` | Asks questions about inventory, lead times, and supplier performance |
| **Elena, FP&A analyst** | `FINANCE_ANALYST` | Builds variance reports and month-end views |
| **The platform team** | `COCO_PROFILE_ADMIN` | Owns Cortex Code standards for everyone |

### Before profiles

Every user starts from a blank slate:
- Priya has installed a handful of skills locally. Her teammate has a different handful.
- Marcus doesn't know skills exist. He keeps getting queries against raw tables instead of the curated supply chain mart.
- Elena's reports use calendar months, because nothing tells Cortex Code that Northwind's fiscal year starts in October.
- The platform team writes a wiki page called "How to set up Cortex Code." Most people skim it.

Nothing here is broken. It's just inconsistent, and each person pays the setup cost on their own.

### Designing the profiles

The platform team sketches four profiles. None of them is a spec yet; this is about intent.

**`DEFAULT`: the house style for everyone**
- Instructions: be concise, lead with the answer, and name every object by its fully qualified name.
- Skills: none.
- Purpose: a good baseline for anyone who never picks a profile. Because it's named `DEFAULT`, it's applied automatically whenever a user can see more than one profile.

**`DATA_ENGINEERING`: Priya's team**
- Instructions: follow the team's SQL conventions; prefer dynamic tables over hand-scheduled tasks; never use `CREATE OR REPLACE` on objects that carry grants.
- Skills: the team's SQL conventions, and a pipeline-review checklist.
- Purpose: everyone on the team gets the same conventions on day one, including new hires.

**`SUPPLY_CHAIN`: Marcus's team**
- Instructions: explain results in plain English; show a small table before any narrative; when a supplier is mentioned, include its ID and name.
- Skills: a "where to find supply chain data" skill pointing to the certified mart, and a chart-formatting skill that applies company colors.
- Purpose: Marcus gets answers from the right tables without needing to know which tables are right.

**`FINANCE`: Elena's team**
- Instructions: use the fiscal calendar (FY starts October 1); show currency with two decimals; flag any number pulled from a non-certified source.
- Skills: a fiscal calendar skill, and a variance-report template.
- Purpose: month-end work comes out in the shape Finance expects, every time.

### Wiring personas to profiles

Each profile gets granted to a role, and that's how it reaches the right people. The platform team keeps it simple:
- Grant `DEFAULT` to everyone who uses Cortex Code.
- Grant each persona profile to the matching functional role.

| Role | Profiles it can see | What happens automatically |
| --- | --- | --- |
| `DE_ROLE` | `DEFAULT`, `DATA_ENGINEERING` | `DEFAULT` is applied. Priya switches to `DATA_ENGINEERING` once, and that choice sticks. |
| `SUPPLY_ANALYST` | `DEFAULT`, `SUPPLY_CHAIN` | `DEFAULT` is applied, and Marcus picks `SUPPLY_CHAIN` |
| `FINANCE_ANALYST` | `DEFAULT`, `FINANCE` | `DEFAULT` is applied, and Elena picks `FINANCE` |
| Anyone else | `DEFAULT` only | `DEFAULT` is applied with no choice needed |

**Design choice.** If you want each persona's profile applied with zero clicks, give that role exactly one profile, its own, and skip `DEFAULT` for it. A role that sees exactly one profile gets it automatically. A role that sees several gets the one named `DEFAULT`, or none if there isn't one. Pick whichever behavior suits your rollout. Either way, have one profile per persona, so users aren't left choosing between profiles the way they used to choose between settings.

### A day with profiles

- **Monday, 9:00.** Marcus asks, "Which suppliers missed their lead time most often last quarter?" The `SUPPLY_CHAIN` profile's data-location skill points Cortex Code at the certified mart rather than the raw tables. The answer comes back as a small table with supplier IDs and names, followed by two sentences of explanation. Marcus never opened a settings screen.
- **Monday, 11:00.** Priya reviews a teammate's pipeline. The `DATA_ENGINEERING` profile loads the pipeline-review skill only because the request is about reviewing a pipeline. Skills load on demand, not all at once. The review flags a `CREATE OR REPLACE` on a table with grants.
- **Tuesday.** Month-end. Elena asks for an OpEx variance by cost center for "last month". Because the `FINANCE` profile carries the fiscal calendar skill, "last month" resolves to the correct fiscal period.
- **Wednesday.** Elena needs a quick SQL fix and looks for the `DATA_ENGINEERING` profile. It isn't there: her role wasn't granted it. She still gets a perfectly good answer under `FINANCE` or `DEFAULT`. **And even if she could see it, she would only gain conventions, not access**: her queries still run as `FINANCE_ANALYST`.

### When the standards change

Finance updates its rule: numbers from non-certified sources must now be excluded, not just flagged. The platform team changes the instructions in the `FINANCE` profile, and every finance user picks it up in their next new chat. There's no wiki update and no "please reinstall this skill" email. The same applies when a skill is improved: update it once in its stage or catalog location, and every profile that references it serves the new version.

## Things to keep in mind

- **One persona, one profile.** The point is to remove choices. If users routinely have to decide which profile to use, the profiles are probably too fine-grained.
- **`DEFAULT` is a design decision.** Adding a second visible profile to a role changes what that role gets automatically, unless one of its profiles is named `DEFAULT`. Decide on purpose.
- **Users stay in control.** Someone can pick a different visible profile, or choose none. Their explicit choice always beats the automatic one.
- **Choices are per client.** A profile picked in Desktop doesn't necessarily carry over to the CLI or Snowsight.
- **Changes apply to new chats.** A chat already in progress keeps the profile version it started with.
- **Keep secrets out.** Profile specs hold instructions and skill references, never credentials.
- **Skills need read access too.** A profile can list a skill, but the user's role still needs read access to the stage or catalog object that holds it.

## Where to go next

- `01_base_setup.sql` and `02_profiles.sql` build a working `DEFAULT` profile and an example persona profile (`TEAM_SQL`) with one skill.
- To model the scenario above, copy the `TEAM_SQL` block in `02_profiles.sql` once per persona, then change the instructions and skills, and the role you grant it to.
