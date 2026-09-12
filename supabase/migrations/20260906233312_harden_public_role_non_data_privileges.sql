-- Defense-in-depth hardening for PostgREST-exposed public tables.
-- RLS remains the primary row-level control. These grants remove schema-level
-- capabilities that runtime clients do not need.

REVOKE REFERENCES, TRIGGER, TRUNCATE
ON ALL TABLES IN SCHEMA public
FROM anon, authenticated;

-- Anonymous users never need direct table writes. Public reads remain
-- controlled by existing RLS policies and public RPCs/views.
REVOKE INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
FROM anon;
