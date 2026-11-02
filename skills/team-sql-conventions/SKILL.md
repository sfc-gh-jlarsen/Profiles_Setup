---
name: team-sql-conventions
description: Apply the team's Snowflake SQL conventions when writing, reviewing, or fixing SQL. Use when the user asks for a query, view, or DDL, or asks to clean up SQL.
---

# Team SQL conventions

This is an example skill delivered through a Cortex Code agent profile.
Replace these rules with your team's own.

## Rules

1. Always use fully qualified names: `DATABASE.SCHEMA.OBJECT`.
2. Uppercase SQL keywords; lowercase column aliases in `snake_case`.
3. Use CTEs instead of nested subqueries when a query has more than one step.
4. Never use `SELECT *` in views or saved queries; list the columns.
5. Put a `LIMIT` on exploratory queries.
6. Prefer `CREATE ... IF NOT EXISTS` or `CREATE OR ALTER` over `CREATE OR REPLACE`
   for objects that carry grants.

## Output

When you write SQL, finish with one line: `Conventions applied: team-sql-conventions`.
That line lets you confirm the profile's skill was actually used.
