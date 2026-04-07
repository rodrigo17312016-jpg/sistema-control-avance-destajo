/**
 * Theme Toggle - Modo Claro/Oscuro
 * Incluir en todas las paginas del sistema
 */
(function() {
    const STORAGE_KEY = 'ft-piura-theme';

    function getPreferredTheme() {
        const saved = localStorage.getItem(STORAGE_KEY);
        if (saved) return saved;
        return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    }

    function applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem(STORAGE_KEY, theme);
        const btn = document.getElementById('themeToggle');
        if (btn) {
            btn.innerHTML = theme === 'dark'
                ? '<span style="font-size:1.2rem">&#9788;</span> Claro'
                : '<span style="font-size:1.2rem">&#9789;</span> Oscuro';
            btn.title = theme === 'dark' ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro';
        }
    }

    function toggleTheme() {
        const current = document.documentElement.getAttribute('data-theme') || 'dark';
        applyTheme(current === 'dark' ? 'light' : 'dark');
    }

    function createToggleButton() {
        const btn = document.createElement('button');
        btn.id = 'themeToggle';
        btn.setAttribute('aria-label', 'Cambiar tema');
        btn.style.cssText = 'position:fixed;top:15px;right:15px;z-index:10000;padding:8px 16px;border-radius:25px;border:2px solid rgba(128,128,128,0.3);background:rgba(128,128,128,0.15);color:inherit;font-size:0.85rem;font-weight:600;font-family:inherit;cursor:pointer;display:flex;align-items:center;gap:6px;transition:all 0.3s;backdrop-filter:blur(8px);';
        btn.addEventListener('click', toggleTheme);
        btn.addEventListener('mouseenter', function() { this.style.transform = 'scale(1.1)'; });
        btn.addEventListener('mouseleave', function() { this.style.transform = 'scale(1)'; });
        document.body.appendChild(btn);
    }

    // CSS custom properties for light/dark
    const style = document.createElement('style');
    style.textContent = `
        :root, [data-theme="dark"] {
            --bg-primary: #0a0a2e;
            --bg-secondary: #1a1a4e;
            --bg-card: linear-gradient(135deg, #1a1a4e, #252560);
            --bg-input: #0d0d35;
            --text-primary: #ffffff;
            --text-secondary: #8888aa;
            --text-muted: #555577;
            --border-color: #333366;
            --accent: #00d4ff;
            --accent-glow: rgba(0, 212, 255, 0.2);
            --success: #00ff88;
            --warning: #ffaa00;
            --danger: #ff0055;
            --shadow: rgba(0, 0, 0, 0.3);
        }
        [data-theme="light"] {
            --bg-primary: #f0f2f5;
            --bg-secondary: #ffffff;
            --bg-card: linear-gradient(135deg, #ffffff, #f8f9fa);
            --bg-input: #f0f2f5;
            --text-primary: #1a1a2e;
            --text-secondary: #555577;
            --text-muted: #888899;
            --border-color: #d0d5dd;
            --accent: #0077cc;
            --accent-glow: rgba(0, 119, 204, 0.15);
            --success: #00a855;
            --warning: #e09500;
            --danger: #dd0044;
            --shadow: rgba(0, 0, 0, 0.08);
        }
        @media print { #themeToggle { display: none !important; } }
    `;
    document.head.appendChild(style);

    // Apply on load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            applyTheme(getPreferredTheme());
            createToggleButton();
        });
    } else {
        applyTheme(getPreferredTheme());
        createToggleButton();
    }
})();
