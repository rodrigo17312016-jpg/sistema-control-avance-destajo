/**
 * Configuracion centralizada de Supabase
 * Este archivo es importado como modulo ES6 por todas las apps
 */

// IMPORTANTE: Reemplazar con tus credenciales reales de Supabase
const SUPABASE_CONFIG = {
    url: 'https://TU_PROYECTO.supabase.co',
    anonKey: 'TU_ANON_KEY_AQUI',
};

// Inicializar cliente Supabase
function initSupabase() {
    if (!window.supabase) {
        console.error('Supabase JS no cargado. Incluir el script CDN primero.');
        return null;
    }
    return window.supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
}

// Exportar para uso global
window.SUPABASE_CONFIG = SUPABASE_CONFIG;
window.initSupabase = initSupabase;
