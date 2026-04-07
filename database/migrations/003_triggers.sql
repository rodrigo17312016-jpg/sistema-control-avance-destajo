-- =============================================
-- MIGRACION 003: TRIGGERS
-- =============================================

-- Updated_at automatico
CREATE TRIGGER trg_trabajadores_updated_at
    BEFORE UPDATE ON public.trabajadores
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_metas_updated_at
    BEFORE UPDATE ON public.metas_diarias
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_configuracion_updated_at
    BEFORE UPDATE ON public.configuracion
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Auditoria en tablas criticas
CREATE TRIGGER trg_audit_avance
    AFTER INSERT OR UPDATE OR DELETE ON public.avance_produccion
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

CREATE TRIGGER trg_audit_codigos_qr
    AFTER INSERT OR UPDATE OR DELETE ON public.codigos_qr
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

CREATE TRIGGER trg_audit_trabajadores
    AFTER INSERT OR UPDATE OR DELETE ON public.trabajadores
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

-- Validacion de velocidad sospechosa
CREATE TRIGGER trg_velocidad_sospechosa
    AFTER INSERT ON public.avance_produccion
    FOR EACH ROW EXECUTE FUNCTION public.fn_detectar_velocidad_sospechosa();

-- Actualizacion automatica de metas
CREATE TRIGGER trg_actualizar_meta
    AFTER INSERT ON public.avance_produccion
    FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_meta_diaria();
