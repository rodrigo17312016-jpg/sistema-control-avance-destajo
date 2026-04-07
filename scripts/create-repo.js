/**
 * Crea un repositorio en GitHub usando la API REST
 * Usa el token de git credential manager de Windows
 */
const https = require('https');
const { execSync } = require('child_process');

const REPO_NAME = 'sistema-control-avance-destajo';
const REPO_DESC = 'Sistema de Control de Avance por Destajo en Tiempo Real - Frutas Tropicales Piura | Supabase + QR + Dashboard TV';

// Intentar obtener token del credential manager
function getToken() {
    try {
        const result = execSync(
            'printf "protocol=https\\nhost=github.com\\n\\n" | git credential fill',
            { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
        );
        const match = result.match(/password=(.+)/);
        return match ? match[1].trim() : null;
    } catch {
        return null;
    }
}

function createRepo(token) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            name: REPO_NAME,
            description: REPO_DESC,
            private: false,
            auto_init: false
        });

        const options = {
            hostname: 'api.github.com',
            path: '/user/repos',
            method: 'POST',
            headers: {
                'Authorization': `token ${token}`,
                'User-Agent': 'Node.js',
                'Content-Type': 'application/json',
                'Content-Length': data.length,
                'Accept': 'application/vnd.github.v3+json'
            }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                const json = JSON.parse(body);
                if (res.statusCode === 201) {
                    resolve(json);
                } else if (res.statusCode === 422 && body.includes('already exists')) {
                    console.log('El repositorio ya existe. Continuando con push...');
                    resolve({ html_url: `https://github.com/${json.message ? '' : json.full_name}`, already_exists: true });
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${json.message || body}`));
                }
            });
        });

        req.on('error', reject);
        req.write(data);
        req.end();
    });
}

async function main() {
    console.log('Obteniendo token de GitHub...');
    const token = getToken();

    if (!token) {
        console.error('No se pudo obtener el token de GitHub.');
        console.log('');
        console.log('Opciones:');
        console.log('1. Crear el repo manualmente en https://github.com/new');
        console.log(`   Nombre: ${REPO_NAME}`);
        console.log('   NO inicializar con README');
        console.log('2. Luego ejecutar: git push -u origin master');
        process.exit(1);
    }

    console.log('Token obtenido. Creando repositorio...');

    try {
        const repo = await createRepo(token);
        console.log('');
        console.log('Repositorio creado exitosamente!');
        console.log(`URL: ${repo.html_url}`);
        console.log('');
        console.log('Ejecutando git push...');

        execSync('git push -u origin master', {
            stdio: 'inherit',
            cwd: process.cwd()
        });

        console.log('');
        console.log('Push completado!');
        console.log(`Repositorio: ${repo.html_url}`);
    } catch (err) {
        console.error('Error:', err.message);
        process.exit(1);
    }
}

main();
