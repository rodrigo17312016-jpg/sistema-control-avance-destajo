-- =============================================
-- MIGRACION 002: FUNCIONES
-- =============================================

-- Funcion: updated_at automatico
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Funcion: auditoria automatica
CREATE OR REPLACE FUNCTION public.fn_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.auditoria (tabla, operacion, registro_id, datos_nuevos)
        VALUES (TG_TABLE_NAME, 'INSERT', NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.auditoria (tabla, operacion, registro_id, datos_anteriores, datos_nuevos)
        VALUES (TG_TABLE_NAME, 'UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.auditoria (tabla, operacion, registro_id, datos_anteriores)
        VALUES (TG_TABLE_NAME, 'DELETE', OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Funcion: detectar velocidad sospechosa
CREATE OR REPLACE FUNCTION public.fn_detectar_velocidad_sospechosa()
RETURNS TRIGGER AS $$
DECLARE
    v_conteo INTEGER;
    v_nombre TEXT;
BEGIN
    SELECT COUNT(*) INTO v_conteo
    FROM public.avance_produccion
    WHERE trabajador_id = NEW.trabajador_id
      AND fecha_hora_registro > (NOW() - INTERVAL '10 seconds');

    IF v_conteo > 5 THEN
        SELECT nombres || ' ' || apellidos INTO v_nombre
        FROM public.trabajadores WHERE id = NEW.trabajador_id;

        INSERT INTO public.alertas (tipo, severidad, mensaje, detalle, trabajador_id)
        VALUES (
            'velocidad_sospechosa',
            'alta',
            format('%s registro %s cajas en menos de 10 segundos. Verificar.', v_nombre, v_conteo),
            jsonb_build_object('conteo', v_conteo, 'intervalo_segundos', 10),
            NEW.trabajador_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Funcion: actualizar metas diarias automaticamente
CREATE OR REPLACE FUNCTION public.fn_actualizar_meta_diaria()
RETURNS TRIGGER AS $$
DECLARE
    v_meta INTEGER;
    v_cajas INTEGER;
    v_porcentaje DECIMAL(6,2);
    v_bono_previo BOOLEAN;
    v_nombre TEXT;
BEGIN
    -- Crear meta si no existe
    INSERT INTO public.metas_diarias (trabajador_id, fecha, turno_id, meta_cajas)
    VALUES (NEW.trabajador_id, NEW.fecha, NEW.turno_id, 200)
    ON CONFLICT (trabajador_id, fecha, turno_id) DO NOTHING;

    -- Contar cajas del dia para este turno
    SELECT COUNT(*) INTO v_cajas
    FROM public.avance_produccion
    WHERE trabajador_id = NEW.trabajador_id
      AND fecha = NEW.fecha
      AND (turno_id = NEW.turno_id OR (turno_id IS NULL AND NEW.turno_id IS NULL));

    -- Obtener meta y estado previo del bono
    SELECT meta_cajas, bono_alcanzado INTO v_meta, v_bono_previo
    FROM public.metas_diarias
    WHERE trabajador_id = NEW.trabajador_id
      AND fecha = NEW.fecha
      AND (turno_id = NEW.turno_id OR (turno_id IS NULL AND NEW.turno_id IS NULL));

    IF v_meta IS NULL THEN v_meta := 200; END IF;

    v_porcentaje := ROUND((v_cajas::DECIMAL / GREATEST(v_meta, 1)) * 100, 2);

    -- Actualizar meta
    UPDATE public.metas_diarias
    SET cajas_completadas = v_cajas,
        porcentaje_avance = v_porcentaje,
        bono_alcanzado = (v_cajas >= v_meta),
        updated_at = NOW()
    WHERE trabajador_id = NEW.trabajador_id
      AND fecha = NEW.fecha
      AND (turno_id = NEW.turno_id OR (turno_id IS NULL AND NEW.turno_id IS NULL));

    -- Alerta si acaba de alcanzar la meta
    IF v_cajas >= v_meta AND (v_bono_previo IS NULL OR v_bono_previo = false) THEN
        SELECT nombres || ' ' || apellidos INTO v_nombre
        FROM public.trabajadores WHERE id = NEW.trabajador_id;

        INSERT INTO public.alertas (tipo, severidad, mensaje, detalle, trabajador_id)
        VALUES (
            'meta_alcanzada', 'baja',
            format('%s alcanzo su meta de %s cajas!', v_nombre, v_meta),
            jsonb_build_object('meta', v_meta, 'cajas', v_cajas),
            NEW.trabajador_id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Funcion RPC: registrar escaneo con validacion completa
CREATE OR REPLACE FUNCTION public.fn_registrar_escaneo(
    p_codigo_qr TEXT,
    p_escaneado_por UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_qr RECORD;
    v_trabajador RECORD;
    v_avance_id UUID;
BEGIN
    -- Buscar el codigo QR
    SELECT * INTO v_qr
    FROM public.codigos_qr
    WHERE codigo_unico = p_codigo_qr;

    -- QR no encontrado
    IF NOT FOUND THEN
        INSERT INTO public.alertas (tipo, severidad, mensaje, detalle)
        VALUES ('qr_invalido', 'alta', 'Codigo QR no encontrado en el sistema',
                jsonb_build_object('codigo_escaneado', left(p_codigo_qr, 100)));
        RETURN jsonb_build_object(
            'exito', false,
            'error', 'CODIGO QR NO ENCONTRADO',
            'codigo', 'QR_NOT_FOUND'
        );
    END IF;

    -- QR ya escaneado
    IF v_qr.estado = 'escaneado' THEN
        INSERT INTO public.alertas (tipo, severidad, mensaje, detalle, trabajador_id, codigo_qr_id)
        VALUES ('duplicado', 'critica',
                format('Intento de escaneo duplicado: caja %s', v_qr.numero_caja),
                jsonb_build_object('primera_lectura', v_qr.fecha_escaneo, 'caja', v_qr.numero_caja),
                v_qr.trabajador_id, v_qr.id);
        RETURN jsonb_build_object(
            'exito', false,
            'error', 'ESTE QR YA FUE ESCANEADO',
            'codigo', 'QR_ALREADY_SCANNED',
            'primera_lectura', v_qr.fecha_escaneo
        );
    END IF;

    -- QR anulado o con error
    IF v_qr.estado IN ('error', 'anulado') THEN
        RETURN jsonb_build_object(
            'exito', false,
            'error', 'ESTE QR ESTA ' || UPPER(v_qr.estado),
            'codigo', 'QR_INVALID_STATE'
        );
    END IF;

    -- Obtener datos del trabajador
    SELECT * INTO v_trabajador
    FROM public.trabajadores
    WHERE id = v_qr.trabajador_id AND activo = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'exito', false,
            'error', 'TRABAJADOR NO ENCONTRADO O INACTIVO',
            'codigo', 'WORKER_NOT_FOUND'
        );
    END IF;

    -- Todo OK: marcar QR como escaneado
    UPDATE public.codigos_qr
    SET estado = 'escaneado',
        fecha_escaneo = NOW(),
        escaneado_por = p_escaneado_por,
        verificado = true
    WHERE id = v_qr.id;

    -- Registrar avance
    INSERT INTO public.avance_produccion (
        trabajador_id, turno_id, codigo_qr_id, numero_caja, fecha, metodo_registro, validado
    ) VALUES (
        v_qr.trabajador_id, v_qr.turno_id, v_qr.id, v_qr.numero_caja,
        CURRENT_DATE, 'qr_scan', true
    ) RETURNING id INTO v_avance_id;

    RETURN jsonb_build_object(
        'exito', true,
        'mensaje', format('Caja %s registrada correctamente', v_qr.numero_caja),
        'codigo', 'OK',
        'avance_id', v_avance_id,
        'trabajador_id', v_trabajador.id,
        'trabajador_nombre', v_trabajador.nombres || ' ' || v_trabajador.apellidos,
        'trabajador_dni', v_trabajador.dni,
        'numero_caja', v_qr.numero_caja
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcion RPC: registro manual (sin QR)
CREATE OR REPLACE FUNCTION public.fn_registro_manual(
    p_dni VARCHAR(8),
    p_numero_caja INTEGER,
    p_observaciones TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_trabajador RECORD;
    v_turno_id UUID;
BEGIN
    -- Buscar trabajador
    SELECT * INTO v_trabajador
    FROM public.trabajadores
    WHERE dni = p_dni AND activo = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'exito', false,
            'error', 'DNI NO ENCONTRADO O TRABAJADOR INACTIVO',
            'codigo', 'DNI_NOT_FOUND'
        );
    END IF;

    -- Obtener turno activo
    SELECT id INTO v_turno_id
    FROM public.turnos
    WHERE fecha = CURRENT_DATE AND activo = true
    ORDER BY hora_inicio
    LIMIT 1;

    -- Registrar avance manual
    INSERT INTO public.avance_produccion (
        trabajador_id, turno_id, numero_caja, fecha, metodo_registro, observaciones
    ) VALUES (
        v_trabajador.id, v_turno_id, p_numero_caja, CURRENT_DATE, 'manual',
        COALESCE(p_observaciones, 'Registro manual sin QR')
    );

    RETURN jsonb_build_object(
        'exito', true,
        'mensaje', format('Caja %s registrada manualmente para %s %s',
                         p_numero_caja, v_trabajador.nombres, v_trabajador.apellidos),
        'codigo', 'OK',
        'trabajador_nombre', v_trabajador.nombres || ' ' || v_trabajador.apellidos,
        'numero_caja', p_numero_caja
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funcion RPC: obtener ranking en tiempo real
CREATE OR REPLACE FUNCTION public.fn_obtener_ranking(p_fecha DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    trabajador_id UUID,
    dni VARCHAR(8),
    nombres VARCHAR(100),
    apellidos VARCHAR(100),
    nombre_completo TEXT,
    area VARCHAR(50),
    estacion INTEGER,
    foto_url TEXT,
    meta_cajas INTEGER,
    cajas_completadas INTEGER,
    porcentaje_avance DECIMAL(6,2),
    bono_alcanzado BOOLEAN,
    posicion INTEGER,
    cajas_por_hora DECIMAL(6,1)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id,
        t.dni,
        t.nombres,
        t.apellidos,
        (t.nombres || ' ' || t.apellidos)::TEXT,
        t.area,
        t.estacion,
        t.foto_url,
        COALESCE(m.meta_cajas, 200),
        COALESCE(m.cajas_completadas, 0),
        COALESCE(m.porcentaje_avance, 0.00),
        COALESCE(m.bono_alcanzado, false),
        ROW_NUMBER() OVER (ORDER BY COALESCE(m.cajas_completadas, 0) DESC)::INTEGER,
        CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - (p_fecha + '06:00'::TIME))) > 0
            THEN ROUND(
                COALESCE(m.cajas_completadas, 0)::DECIMAL /
                GREATEST(EXTRACT(EPOCH FROM (NOW() - (p_fecha + '06:00'::TIME))) / 3600.0, 0.1),
                1
            )
            ELSE 0.0
        END
    FROM public.trabajadores t
    LEFT JOIN public.metas_diarias m
        ON t.id = m.trabajador_id AND m.fecha = p_fecha
    WHERE t.activo = true
    ORDER BY COALESCE(m.cajas_completadas, 0) DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Funcion RPC: estadisticas generales del dia
CREATE OR REPLACE FUNCTION public.fn_estadisticas_generales(p_fecha DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_trabajadores', COUNT(DISTINCT CASE WHEN m.cajas_completadas > 0 THEN m.trabajador_id END),
        'total_cajas', COALESCE(SUM(m.cajas_completadas), 0),
        'promedio_cajas', ROUND(COALESCE(AVG(CASE WHEN m.cajas_completadas > 0 THEN m.cajas_completadas END), 0), 1),
        'maximo_cajas', COALESCE(MAX(m.cajas_completadas), 0),
        'minimo_cajas', COALESCE(MIN(CASE WHEN m.cajas_completadas > 0 THEN m.cajas_completadas END), 0),
        'trabajadores_meta_cumplida', COUNT(CASE WHEN m.bono_alcanzado THEN 1 END),
        'total_trabajadores_activos', (SELECT COUNT(*) FROM public.trabajadores WHERE activo = true),
        'porcentaje_meta_global', ROUND(
            COALESCE(
                COUNT(CASE WHEN m.bono_alcanzado THEN 1 END)::DECIMAL /
                NULLIF((SELECT COUNT(*) FROM public.trabajadores WHERE activo = true), 0) * 100
            , 0), 1
        ),
        'alertas_pendientes', (SELECT COUNT(*) FROM public.alertas WHERE fecha_hora::DATE = p_fecha AND NOT resuelta),
        'fecha', p_fecha,
        'hora_servidor', NOW()
    ) INTO v_result
    FROM public.metas_diarias m
    WHERE m.fecha = p_fecha;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;
