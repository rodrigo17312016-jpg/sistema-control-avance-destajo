-- =============================================
-- SETUP COMPLETO - Ejecutar en Supabase SQL Editor
-- Este archivo combina todas las migraciones en orden
-- =============================================
-- IMPORTANTE: Ejecutar este archivo COMPLETO en una sola ejecucion
-- en el SQL Editor de Supabase (supabase.com > tu proyecto > SQL Editor)
-- =============================================

\i migrations/001_tables.sql
\i migrations/002_functions.sql
\i migrations/003_triggers.sql
\i migrations/004_rls_and_realtime.sql
\i migrations/005_seed.sql
