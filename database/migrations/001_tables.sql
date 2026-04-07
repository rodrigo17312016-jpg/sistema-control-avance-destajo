-- =============================================
-- MIGRACION 001: TABLAS PRINCIPALES
-- Sistema de Control de Avance por Destajo
-- Frutas Tropicales Piura
-- =============================================

-- Tabla: trabajadores
CREATE TABLE IF NOT EXISTS public.trabajadores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    dni VARCHAR(8) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    area VARCHAR(50) NOT NULL DEFAULT 'empaque',
    estacion INTEGER,
    foto_url TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    telefono VARCHAR(15),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_trabajadores_dni UNIQUE (dni),
    CONSTRAINT chk_trabajadores_dni_length CHECK (char_length(dni) = 8),
    CONSTRAINT chk_trabajadores_dni_numeric CHECK (dni ~ '^\d{8}$')
);

CREATE INDEX IF NOT EXISTS idx_trabajadores_dni ON public.trabajadores(dni);
CREATE INDEX IF NOT EXISTS idx_trabajadores_activo ON public.trabajadores(activo);
CREATE INDEX IF NOT EXISTS idx_trabajadores_area ON public.trabajadores(area);

COMMENT ON TABLE public.trabajadores IS 'Registro de trabajadores de la empacadora';
COMMENT ON COLUMN public.trabajadores.dni IS 'Documento Nacional de Identidad (8 digitos)';
COMMENT ON COLUMN public.trabajadores.estacion IS 'Numero de estacion de empaque asignada';

-- Tabla: turnos
CREATE TABLE IF NOT EXISTS public.turnos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo_turno VARCHAR(20) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    supervisor_id UUID REFERENCES public.trabajadores(id),
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_turnos_tipo CHECK (tipo_turno IN ('manana', 'tarde', 'noche')),
    CONSTRAINT chk_turnos_horario CHECK (hora_inicio < hora_fin),
    CONSTRAINT uq_turnos_fecha_tipo UNIQUE (fecha, tipo_turno)
);

CREATE INDEX IF NOT EXISTS idx_turnos_fecha ON public.turnos(fecha);
CREATE INDEX IF NOT EXISTS idx_turnos_activo ON public.turnos(activo);
CREATE INDEX IF NOT EXISTS idx_turnos_fecha_activo ON public.turnos(fecha, activo);

-- Tabla: codigos_qr
CREATE TABLE IF NOT EXISTS public.codigos_qr (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    codigo_unico VARCHAR(300) NOT NULL,
    hash_verificacion VARCHAR(64) NOT NULL,
    trabajador_id UUID NOT NULL REFERENCES public.trabajadores(id) ON DELETE RESTRICT,
    turno_id UUID REFERENCES public.turnos(id) ON DELETE SET NULL,
    numero_caja INTEGER NOT NULL,
    lote VARCHAR(20),
    estado VARCHAR(20) NOT NULL DEFAULT 'generado',
    fecha_generacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_impresion TIMESTAMPTZ,
    fecha_escaneo TIMESTAMPTZ,
    escaneado_por UUID REFERENCES public.trabajadores(id),
    verificado BOOLEAN NOT NULL DEFAULT false,
    observaciones TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_codigos_qr_codigo UNIQUE (codigo_unico),
    CONSTRAINT uq_codigos_qr_hash UNIQUE (hash_verificacion),
    CONSTRAINT chk_codigos_qr_caja CHECK (numero_caja BETWEEN 1 AND 5000),
    CONSTRAINT chk_codigos_qr_estado CHECK (estado IN ('generado', 'impreso', 'escaneado', 'error', 'anulado'))
);

CREATE INDEX IF NOT EXISTS idx_qr_codigo ON public.codigos_qr(codigo_unico);
CREATE INDEX IF NOT EXISTS idx_qr_hash ON public.codigos_qr(hash_verificacion);
CREATE INDEX IF NOT EXISTS idx_qr_trabajador ON public.codigos_qr(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_qr_estado ON public.codigos_qr(estado);
CREATE INDEX IF NOT EXISTS idx_qr_lote ON public.codigos_qr(lote);
CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_trabajador_caja_turno
    ON public.codigos_qr(trabajador_id, numero_caja, turno_id);

-- Tabla: avance_produccion (tabla principal de registros)
CREATE TABLE IF NOT EXISTS public.avance_produccion (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    trabajador_id UUID NOT NULL REFERENCES public.trabajadores(id) ON DELETE RESTRICT,
    turno_id UUID REFERENCES public.turnos(id) ON DELETE SET NULL,
    codigo_qr_id UUID REFERENCES public.codigos_qr(id) ON DELETE SET NULL,
    numero_caja INTEGER NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_hora_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metodo_registro VARCHAR(20) NOT NULL DEFAULT 'qr_scan',
    validado BOOLEAN NOT NULL DEFAULT false,
    observaciones TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_avance_metodo CHECK (metodo_registro IN ('qr_scan', 'manual', 'sensor', 'correccion'))
);

CREATE INDEX IF NOT EXISTS idx_avance_trabajador ON public.avance_produccion(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_avance_fecha ON public.avance_produccion(fecha);
CREATE INDEX IF NOT EXISTS idx_avance_turno ON public.avance_produccion(turno_id);
CREATE INDEX IF NOT EXISTS idx_avance_fecha_trabajador ON public.avance_produccion(fecha, trabajador_id);
CREATE INDEX IF NOT EXISTS idx_avance_fecha_hora ON public.avance_produccion(fecha_hora_registro);

-- Tabla: metas_diarias
CREATE TABLE IF NOT EXISTS public.metas_diarias (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    trabajador_id UUID NOT NULL REFERENCES public.trabajadores(id) ON DELETE RESTRICT,
    turno_id UUID REFERENCES public.turnos(id) ON DELETE SET NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    meta_cajas INTEGER NOT NULL DEFAULT 200,
    cajas_completadas INTEGER NOT NULL DEFAULT 0,
    porcentaje_avance DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    bono_alcanzado BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_metas_trabajador_fecha_turno UNIQUE (trabajador_id, fecha, turno_id),
    CONSTRAINT chk_metas_cajas_positivas CHECK (meta_cajas > 0),
    CONSTRAINT chk_metas_completadas_positivas CHECK (cajas_completadas >= 0)
);

CREATE INDEX IF NOT EXISTS idx_metas_fecha ON public.metas_diarias(fecha);
CREATE INDEX IF NOT EXISTS idx_metas_trabajador ON public.metas_diarias(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_metas_fecha_turno ON public.metas_diarias(fecha, turno_id);

-- Tabla: alertas
CREATE TABLE IF NOT EXISTS public.alertas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tipo VARCHAR(30) NOT NULL,
    severidad VARCHAR(10) NOT NULL DEFAULT 'media',
    mensaje TEXT NOT NULL,
    detalle JSONB,
    trabajador_id UUID REFERENCES public.trabajadores(id) ON DELETE SET NULL,
    codigo_qr_id UUID REFERENCES public.codigos_qr(id) ON DELETE SET NULL,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resuelta BOOLEAN NOT NULL DEFAULT false,
    resuelta_por UUID REFERENCES public.trabajadores(id),
    fecha_resolucion TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_alertas_tipo CHECK (tipo IN (
        'duplicado', 'error_impresion', 'velocidad_sospechosa',
        'meta_alcanzada', 'meta_superada', 'qr_invalido', 'sistema'
    )),
    CONSTRAINT chk_alertas_severidad CHECK (severidad IN ('baja', 'media', 'alta', 'critica'))
);

CREATE INDEX IF NOT EXISTS idx_alertas_tipo ON public.alertas(tipo);
CREATE INDEX IF NOT EXISTS idx_alertas_resuelta ON public.alertas(resuelta);
CREATE INDEX IF NOT EXISTS idx_alertas_fecha ON public.alertas(fecha_hora DESC);
CREATE INDEX IF NOT EXISTS idx_alertas_trabajador ON public.alertas(trabajador_id);

-- Tabla: configuracion
CREATE TABLE IF NOT EXISTS public.configuracion (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    clave VARCHAR(50) NOT NULL,
    valor JSONB NOT NULL,
    descripcion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_configuracion_clave UNIQUE (clave)
);

-- Tabla: auditoria (log de todas las acciones para trazabilidad 100%)
CREATE TABLE IF NOT EXISTS public.auditoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabla VARCHAR(50) NOT NULL,
    operacion VARCHAR(10) NOT NULL,
    registro_id UUID,
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    usuario_id UUID,
    ip_address INET,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_auditoria_operacion CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX IF NOT EXISTS idx_auditoria_tabla ON public.auditoria(tabla);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON public.auditoria(fecha_hora DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_registro ON public.auditoria(registro_id);
