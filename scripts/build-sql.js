/**
 * Combina todas las migraciones SQL en un solo archivo
 * para ejecutar directamente en Supabase SQL Editor
 */
const fs = require('fs');
const path = require('path');

const migrationsDir = path.join(__dirname, '..', 'database', 'migrations');
const outputFile = path.join(__dirname, '..', 'database', 'EJECUTAR_EN_SUPABASE.sql');

const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql'))
    .sort();

let combined = `-- =============================================
-- SCRIPT COMPLETO PARA SUPABASE
-- Sistema de Control de Avance por Destajo
-- Frutas Tropicales Piura
-- Generado: ${new Date().toISOString()}
-- =============================================
-- INSTRUCCIONES:
-- 1. Ir a https://supabase.com/dashboard
-- 2. Seleccionar tu proyecto
-- 3. Ir a SQL Editor (menu izquierdo)
-- 4. Crear nuevo query
-- 5. Pegar TODO este contenido
-- 6. Hacer clic en "Run" (o Ctrl+Enter)
-- =============================================

`;

files.forEach(file => {
    const content = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
    combined += `\n-- =============================================\n`;
    combined += `-- ARCHIVO: ${file}\n`;
    combined += `-- =============================================\n\n`;
    combined += content;
    combined += '\n\n';
});

fs.writeFileSync(outputFile, combined);
console.log(`SQL combinado generado: ${outputFile}`);
console.log(`Archivos incluidos: ${files.join(', ')}`);
console.log(`Tamano: ${(combined.length / 1024).toFixed(1)} KB`);
