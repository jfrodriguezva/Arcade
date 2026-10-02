"""Ajustes a la versión web después de exportar con Godot (build/web).

Uso (después de `godot --headless --export-release "Web" build/web/index.html`):

    py tools/postexport_web.py

1. Motor en caché aparte: el service worker que genera Godot borra TODO su
   caché en cada versión nueva, así que tras cada actualización el
   navegador volvía a bajar también el motor (index.wasm, ~10 MB) aunque
   no cambió. Aquí se le da al motor su propio caché, con nombre según su
   contenido: solo se vuelve a descargar si cambia la versión de Godot.
2. Archivos que viajan aparte del paquete: la música de Invasión Espacial
   (3.6 MB) se excluye del .pck (exclude_filter del preset Web) y se copia
   junto a index.html; el juego la pide al entrar.
3. Mensaje en la pantalla de carga explicando que la primera vez tarda.
"""
import hashlib
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"
LAZY_FILES = {
    "musica_fondo.mp3": ROOT / "games/arcade/invasion_espacial/assets/sonidos/musica_fondo.mp3",
}
LOADING_NOTE = (
    '<style>#carga-nota{position:absolute;bottom:12%;left:0;right:0;text-align:center;'
    'font-family:sans-serif;color:#9aa3c7;font-size:15px;padding:0 24px;}</style>'
    '<script>window.addEventListener("DOMContentLoaded",function(){var s=document.getElementById("status");'
    'if(!s)return;var d=document.createElement("div");d.id="carga-nota";'
    'd.textContent="Cargando la plataforma de juegos... La primera vez (y después de cada actualización) '
    'tarda un poco; luego abre al instante.";s.appendChild(d);});</script>'
)


def patch_service_worker() -> None:
    sw_path = WEB / "index.service.worker.js"
    sw = sw_path.read_text(encoding="utf-8")
    if "ENGINE_CACHE" in sw:
        return
    wasm_hash = hashlib.sha256((WEB / "index.wasm").read_bytes()).hexdigest()[:16]
    sw = sw.replace(
        "const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;",
        "const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;\n"
        "// Motor en caché propio (nombre = su contenido): sobrevive a las actualizaciones del juego.\n"
        f"const ENGINE_CACHE = CACHE_PREFIX + 'engine-{wasm_hash}';\n"
        "function cacheFor(name) { return caches.open(name === 'index.wasm' ? ENGINE_CACHE : CACHE_NAME); }",
    )
    sw = sw.replace(
        "key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)",
        "key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME && key !== ENGINE_CACHE)",
    )
    sw = sw.replace(
        "const fullCache = await Promise.all(FULL_CACHE.map((name) => cache.match(name)));",
        "const fullCache = await Promise.all(FULL_CACHE.map((name) => cacheFor(name).then((c) => c.match(name))));",
    )
    sw = sw.replace(
        "const cache = await caches.open(CACHE_NAME);",
        "const cache = await cacheFor(local);",
    )
    for needle in ("ENGINE_CACHE", "cacheFor(local)", "key !== ENGINE_CACHE"):
        assert needle in sw, f"no se pudo parchar el service worker ({needle})"
    sw_path.write_text(sw, encoding="utf-8")
    print(f"service worker: motor en caché propio (engine-{wasm_hash})")


def copy_lazy_files() -> None:
    for name, src in LAZY_FILES.items():
        shutil.copyfile(src, WEB / name)
        print(f"copiado aparte: {name} ({src.stat().st_size // 1024} KB)")


def add_loading_note() -> None:
    html_path = WEB / "index.html"
    html = html_path.read_text(encoding="utf-8")
    if "carga-nota" in html:
        return
    html = html.replace("</head>", LOADING_NOTE + "\n</head>", 1)
    html_path.write_text(html, encoding="utf-8")
    print("index.html: mensaje de carga agregado")


if __name__ == "__main__":
    patch_service_worker()
    copy_lazy_files()
    add_loading_note()
