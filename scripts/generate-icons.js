/**
 * Genera iconos SVG placeholder para la PWA
 */
const fs = require('fs');
const path = require('path');

const iconsDir = path.join(__dirname, '..', 'public', 'icons');

function createSVGIcon(size) {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <rect width="${size}" height="${size}" rx="${size * 0.15}" fill="#0a0a2e"/>
  <rect x="${size * 0.1}" y="${size * 0.1}" width="${size * 0.8}" height="${size * 0.8}" rx="${size * 0.08}" fill="#1a1a4e" stroke="#00d4ff" stroke-width="${size * 0.02}"/>
  <text x="50%" y="45%" dominant-baseline="middle" text-anchor="middle" font-family="Arial" font-weight="bold" font-size="${size * 0.25}" fill="#00d4ff">FT</text>
  <text x="50%" y="72%" dominant-baseline="middle" text-anchor="middle" font-family="Arial" font-size="${size * 0.1}" fill="#00ff88">AVANCE</text>
</svg>`;
}

[192, 512].forEach(size => {
    const filePath = path.join(iconsDir, `icon-${size}.svg`);
    fs.writeFileSync(filePath, createSVGIcon(size));
    console.log(`Icono generado: ${filePath}`);
});

console.log('Iconos SVG generados. Para produccion, convertir a PNG.');
