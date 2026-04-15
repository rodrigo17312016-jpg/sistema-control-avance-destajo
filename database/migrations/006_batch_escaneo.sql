-- =============================================
-- MIGRACION 006: FUNCION BATCH PARA ESCANEO MASIVO
-- Optimizada para scanner industrial Zebra DS9308
-- =============================================

-- Funcion batch: registrar multiples escaneos en una sola llamada
-- Acepta un array JSON de codigos QR y los procesa en una sola transaccion
-- Esto reduce la latencia de N llamadas individuales a 1 sola llamada
CREATE OR REPLACE FUNCTION public.fn_registrar_escaneo_batch(
    p_codigos JSONB  -- Array de objetos: [{"codigo": "...", "timestamp": "..."}, ...]
)
RETURNS JSONB AS $$
DECLARE
    v_item JSONB;
    v_codigo TEXT;
    v_ts TIMESTAMPTZ;
    v_qr RECORD;
    v_trabajador RECORD;
    v_avance_id UUID;
    v_resultados JSONB := '[]'::JSONB;
    v_exitos INT := 0;
    v_errores INT := 0;
    v_resultado JSONB;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_codigos)
    LOOP
        v_codigo := v_item->>'codigo';
        v_ts := COALESCE((v_item->>'timestamp')::TIMESTAMPTZ, NOW());

        -- Buscar QR
        SELECT * INTO v_qr
        FROM public.codigos_qr
        WHERE codigo_unico = v_codigo;

        IF NOT FOUND THEN
            v_errores := v_errores + 1;
            v_resultado := jsonb_build_object(
                'codigo', v_codigo, 'exito', false,
                'error', 'QR_NOT_FOUND'
            );
        ELSIF v_qr.estado = 'escaneado' THEN
            v_errores := v_errores + 1;
            v_resultado := jsonb_build_object(
                'codigo', v_codigo, 'exito', false,
                'error', 'DUPLICADO', 'numero_caja', v_qr.numero_caja
            );
        ELSIF v_qr.estado IN ('error', 'anulado') THEN
            v_errores := v_errores + 1;
            v_resultado := jsonb_build_object(
                'codigo', v_codigo, 'exito', false,
                'error', 'QR_INVALID_STATE'
            );
        ELSE
            -- Obtener trabajador
            SELECT * INTO v_trabajador
            FROM public.trabajadores
            WHERE id = v_qr.trabajador_id AND activo = true;

            IF NOT FOUND THEN
                v_errores := v_errores + 1;
                v_resultado := jsonb_build_object(
                    'codigo', v_codigo, 'exito', false,
                    'error', 'WORKER_NOT_FOUND'
                );
            ELSE
                -- Marcar QR como escaneado
                UPDATE public.codigos_qr
                SET estado = 'escaneado',
                    fecha_escaneo = v_ts,
                    verificado = true
                WHERE id = v_qr.id;

                -- Registrar avance
                INSERT INTO public.avance_produccion (
                    trabajador_id, turno_id, codigo_qr_id, numero_caja,
                    fecha, fecha_hora_registro, metodo_registro, validado
                ) VALUES (
                    v_qr.trabajador_id, v_qr.turno_id, v_qr.id, v_qr.numero_caja,
                    CURRENT_DATE, v_ts, 'qr_scan', true
                ) RETURNING id INTO v_avance_id;

                v_exitos := v_exitos + 1;
                v_resultado := jsonb_build_object(
                    'codigo', v_codigo, 'exito', true,
                    'numero_caja', v_qr.numero_caja,
                    'trabajador_nombre', v_trabajador.nombres || ' ' || v_trabajador.apellidos,
                    'trabajador_dni', v_trabajador.dni,
                    'avance_id', v_avance_id
                );
            END IF;
        END IF;

        v_resultados := v_resultados || v_resultado;
    END LOOP;

    RETURN jsonb_build_object(
        'exitos', v_exitos,
        'errores', v_errores,
        'total', v_exitos + v_errores,
        'resultados', v_resultados
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
