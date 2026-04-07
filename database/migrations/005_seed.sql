-- =============================================
-- MIGRACION 005: DATOS INICIALES (SEED)
-- =============================================

-- Configuracion por defecto
INSERT INTO public.configuracion (clave, valor, descripcion) VALUES
('meta_default', '{"cajas": 200}', 'Meta diaria por defecto de cajas por trabajador'),
('tema_dashboard', '{"fondo":"#0a0a2e","primario":"#00d4ff","exito":"#00ff88","alerta":"#ffaa00","peligro":"#ff0055","card":"#1a1a4e"}', 'Colores del dashboard'),
('refresh_interval', '{"segundos": 3}', 'Intervalo de actualizacion del dashboard'),
('ranking_limite', '{"top": 20}', 'Cantidad de trabajadores visibles en ranking'),
('velocidad_alerta', '{"max_cajas": 5, "intervalo_segundos": 10}', 'Umbral para alerta de velocidad sospechosa'),
('empresa', '{"nombre":"Frutas Tropicales Piura","ruc":"","direccion":"Curumuy, Piura, Peru","telefono":""}', 'Datos de la empresa')
ON CONFLICT (clave) DO NOTHING;

-- Turnos por defecto para hoy
INSERT INTO public.turnos (fecha, tipo_turno, hora_inicio, hora_fin) VALUES
(CURRENT_DATE, 'manana', '06:00', '14:00'),
(CURRENT_DATE, 'tarde', '14:00', '22:00')
ON CONFLICT (fecha, tipo_turno) DO NOTHING;

-- Trabajadores de prueba (para testing)
INSERT INTO public.trabajadores (dni, nombres, apellidos, area, estacion) VALUES
('70000001', 'Carlos Alberto', 'Ramirez Flores', 'empaque', 1),
('70000002', 'Maria Elena', 'Garcia Lopez', 'empaque', 2),
('70000003', 'Jose Luis', 'Torres Mendoza', 'empaque', 3),
('70000004', 'Ana Patricia', 'Diaz Huaman', 'empaque', 4),
('70000005', 'Pedro Miguel', 'Castillo Ramos', 'empaque', 5),
('70000006', 'Rosa Isabel', 'Vargas Quispe', 'empaque', 6),
('70000007', 'Juan Carlos', 'Morales Silva', 'empaque', 7),
('70000008', 'Luz Marina', 'Fernandez Cruz', 'empaque', 8),
('70000009', 'Roberto Daniel', 'Gutierrez Pena', 'empaque', 9),
('70000010', 'Carmen Rosa', 'Sanchez Vega', 'empaque', 10)
ON CONFLICT (dni) DO NOTHING;

-- Generar metas para los trabajadores de prueba
INSERT INTO metas_diarias (trabajador_id, fecha, meta_cajas)
SELECT id, CURRENT_DATE, 200
FROM trabajadores WHERE activo = true
ON CONFLICT (trabajador_id, fecha, turno_id) DO NOTHING;
