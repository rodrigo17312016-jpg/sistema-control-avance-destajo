-- =============================================
-- MIGRACION 004: ROW LEVEL SECURITY + REALTIME
-- =============================================

-- Habilitar RLS
ALTER TABLE public.trabajadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.turnos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.codigos_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avance_produccion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.metas_diarias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alertas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;

-- Politicas de lectura publica (necesario para dashboard y apps)
CREATE POLICY "allow_select_trabajadores" ON public.trabajadores FOR SELECT USING (true);
CREATE POLICY "allow_select_turnos" ON public.turnos FOR SELECT USING (true);
CREATE POLICY "allow_select_codigos_qr" ON public.codigos_qr FOR SELECT USING (true);
CREATE POLICY "allow_select_avance" ON public.avance_produccion FOR SELECT USING (true);
CREATE POLICY "allow_select_metas" ON public.metas_diarias FOR SELECT USING (true);
CREATE POLICY "allow_select_alertas" ON public.alertas FOR SELECT USING (true);
CREATE POLICY "allow_select_config" ON public.configuracion FOR SELECT USING (true);
CREATE POLICY "allow_select_auditoria" ON public.auditoria FOR SELECT USING (true);

-- Politicas de escritura (via anon key para las apps)
CREATE POLICY "allow_insert_avance" ON public.avance_produccion FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_insert_codigos_qr" ON public.codigos_qr FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_codigos_qr" ON public.codigos_qr FOR UPDATE USING (true);
CREATE POLICY "allow_insert_alertas" ON public.alertas FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_alertas" ON public.alertas FOR UPDATE USING (true);
CREATE POLICY "allow_insert_metas" ON public.metas_diarias FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_metas" ON public.metas_diarias FOR UPDATE USING (true);
CREATE POLICY "allow_all_trabajadores" ON public.trabajadores FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_trabajadores" ON public.trabajadores FOR UPDATE USING (true);
CREATE POLICY "allow_all_turnos" ON public.turnos FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_turnos" ON public.turnos FOR UPDATE USING (true);
CREATE POLICY "allow_insert_config" ON public.configuracion FOR INSERT WITH CHECK (true);
CREATE POLICY "allow_update_config" ON public.configuracion FOR UPDATE USING (true);

-- Habilitar Realtime en tablas criticas
ALTER PUBLICATION supabase_realtime ADD TABLE public.avance_produccion;
ALTER PUBLICATION supabase_realtime ADD TABLE public.metas_diarias;
ALTER PUBLICATION supabase_realtime ADD TABLE public.alertas;
