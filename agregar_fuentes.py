# -*- coding: utf-8 -*-
"""
HourTV - Gestor de fuentes
===========================
Programa para AÑADIR tus links de IPTV/M3U o cuentas Xtream a la app, sin tener
que escribirlos en el teléfono.

Lo que haces aquí se guarda en:  assets/data/sources.json
La app HourTV lee ese archivo al abrir y carga tus fuentes automáticamente.

COMO USARLO:
  1) Abre una terminal en la carpeta del proyecto (mi_app).
  2) Ejecuta:   python agregar_fuentes.py
  3) Pega tus links siguiendo el menú.
  4) Al terminar, recompila la app (opción 8) o manualmente:
        flutter build apk --release

No necesita instalar nada (solo Python). Si tienes requests instalado, lo usa
para verificar enlaces; si no, usa urllib.
"""

import json
import os
import sys
import subprocess
import urllib.error
import urllib.request


def configurar_consola_utf8():
    if os.name == "nt":
        try:
            import ctypes
            ctypes.windll.kernel32.SetConsoleOutputCP(65001)
            ctypes.windll.kernel32.SetConsoleCP(65001)
        except Exception:
            pass
    for stream_name in ("stdin", "stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        if stream is not None and hasattr(stream, "reconfigure"):
            try:
                stream.reconfigure(encoding="utf-8")
            except Exception:
                pass


configurar_consola_utf8()


BASE = os.path.dirname(os.path.abspath(__file__))
SOURCES = os.path.join(BASE, "assets", "data", "sources.json")


# ---------------------------------------------------------------- utilidades
def cargar():
    if not os.path.exists(SOURCES):
        return []
    try:
        with open(SOURCES, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def guardar(fuentes):
    os.makedirs(os.path.dirname(SOURCES), exist_ok=True)
    with open(SOURCES, "w", encoding="utf-8") as f:
        json.dump(fuentes, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"\n  Guardado en: {SOURCES}")


def es_url(t):
    t = t.strip()
    return t.startswith("http://") or t.startswith("https://")


def verificar_url(url):
    try:
        import requests
        response = requests.head(url, timeout=5, allow_redirects=True)
        if response.status_code in (403, 405):
            response = requests.get(url, timeout=5, stream=True, allow_redirects=True)
        return 200 <= response.status_code < 400
    except ImportError:
        return verificar_url_sin_requests(url)
    except Exception:
        return False


def verificar_url_sin_requests(url):
    headers = {"User-Agent": "Mozilla/5.0"}
    for method in ("HEAD", "GET"):
        try:
            req = urllib.request.Request(url, headers=headers, method=method)
            with urllib.request.urlopen(req, timeout=5) as response:
                return 200 <= response.status < 400
        except urllib.error.HTTPError as e:
            if e.code in (403, 405) and method == "HEAD":
                continue
            return 200 <= e.code < 400
        except Exception:
            if method == "HEAD":
                continue
            return False
    return False


def fuente_duplicada(fuentes, url):
    return any(s.get("url") == url or s.get("host") == url for s in fuentes)


def pedir(texto):
    try:
        return input(texto).strip()
    except (EOFError, KeyboardInterrupt):
        print("\nCancelado.")
        return ""


ETIQUETA = {
    "live": "Canales en vivo",
    "movie": "Películas",
    "series": "Series",
    "epg": "Guía EPG",
}


# ---------------------------------------------------------------- acciones
def agregar_m3u(fuentes, tipo):
    print(f"\n--- Añadir lista M3U ({ETIQUETA[tipo]}) ---")
    url = pedir("Pega la URL (.m3u / .m3u8):  ")
    if not es_url(url):
        print("  URL inválida (debe empezar por http:// o https://).")
        return
    if fuente_duplicada(fuentes, url):
        print("  Ese enlace ya está guardado.")
        return
    print("  Verificando enlace...")
    if not verificar_url(url):
        print("  El enlace no responde correctamente. No se guardó.")
        return
    nombre = pedir("Nombre para mostrar (Enter = automático):  ")
    if not nombre:
        nombre = f"{ETIQUETA[tipo]} {sum(1 for s in fuentes if s.get('type') == tipo) + 1}"
    fuentes.append({"name": nombre, "url": url, "type": tipo})
    guardar(fuentes)
    print(f"  + Añadida: {nombre}")


def agregar_varios(fuentes, tipo):
    print(f"\n--- Pegar VARIOS links de golpe ({ETIQUETA[tipo]}) ---")
    print("  Pega un link por línea. Cuando termines, deja una línea vacía y Enter.\n")
    nuevos = 0
    while True:
        linea = pedir("> ")
        if linea == "":
            break
        if not es_url(linea):
            print("    (ignorado, no es URL)")
            continue
        if fuente_duplicada(fuentes, linea):
            print("    (ignorado, ya existe)")
            continue
        print("    verificando...")
        if not verificar_url(linea):
            print("    (ignorado, no responde)")
            continue
        nombre = f"{ETIQUETA[tipo]} {sum(1 for s in fuentes if s.get('type') == tipo) + 1 + nuevos}"
        fuentes.append({"name": nombre, "url": linea, "type": tipo})
        nuevos += 1
        print(f"    + {nombre}")
    if nuevos:
        guardar(fuentes)
    print(f"  Total añadidos: {nuevos}")


def agregar_xtream(fuentes):
    print("\n--- Añadir cuenta Xtream ---")
    host = pedir("Servidor con puerto (ej http://servidor.com:8080):  ")
    if not es_url(host):
        print("  Servidor inválido (debe empezar por http:// o https://).")
        return
    user = pedir("Usuario:  ")
    pwd = pedir("Contraseña:  ")
    if not user or not pwd:
        print("  Falta usuario o contraseña.")
        return
    nombre = pedir("Nombre (Enter = 'Mi Xtream'):  ") or "Mi Xtream"
    fuentes.append({"name": nombre, "type": "xtream",
                    "host": host, "username": user, "password": pwd})
    guardar(fuentes)
    print(f"  + Cuenta Xtream añadida: {nombre}")


def listar(fuentes):
    print("\n--- Fuentes guardadas ---")
    if not fuentes:
        print("  (vacío)")
        return
    for i, s in enumerate(fuentes, 1):
        tipo = ETIQUETA.get(s.get("type", "live"), s.get("type"))
        destino = s.get("url") or s.get("host", "")
        print(f"  {i}. [{tipo}] {s.get('name','?')}")
        print(f"     {destino}")


def eliminar(fuentes):
    listar(fuentes)
    if not fuentes:
        return
    n = pedir("\nNúmero a eliminar (Enter = cancelar):  ")
    if not n.isdigit():
        return
    i = int(n) - 1
    if 0 <= i < len(fuentes):
        quitada = fuentes.pop(i)
        guardar(fuentes)
        print(f"  - Eliminada: {quitada.get('name','?')}")
    else:
        print("  Número fuera de rango.")


def compilar():
    print("\n--- Compilando APK (flutter build apk --release) ---")
    print("  Esto puede tardar varios minutos...\n")
    try:
        subprocess.run("flutter build apk --release", cwd=BASE, shell=True)
        apk = os.path.join(BASE, "build", "app", "outputs", "flutter-apk", "app-release.apk")
        if os.path.exists(apk):
            print(f"\n  ✓ APK generado: {apk}")
        else:
            print("\n  No se encontró el APK. Revisa los mensajes de arriba.")
    except Exception as e:
        print(f"  Error al compilar: {e}")


# ---------------------------------------------------------------- menú
def main():
    print("=" * 52)
    print("        HourTV  ·  Gestor de fuentes")
    print("=" * 52)
    while True:
        fuentes = cargar()
        print(f"\nFuentes actuales: {len(fuentes)}")
        print("""
  1) Añadir M3U de CANALES (en vivo)
  2) Añadir M3U de PELÍCULAS
  3) Añadir M3U de SERIES
  4) Añadir cuenta XTREAM
  5) Pegar VARIOS links de golpe
  6) Listar fuentes
  7) Eliminar una fuente
  8) Compilar APK ahora
  0) Salir
""")
        op = pedir("Opción:  ")
        if op == "1":
            agregar_m3u(fuentes, "live")
        elif op == "2":
            agregar_m3u(fuentes, "movie")
        elif op == "3":
            agregar_m3u(fuentes, "series")
        elif op == "4":
            agregar_xtream(fuentes)
        elif op == "5":
            print("\n  ¿De qué tipo son? 1=Canales  2=Películas  3=Series")
            t = pedir("  Tipo:  ")
            agregar_varios(fuentes, {"1": "live", "2": "movie", "3": "series"}.get(t, "live"))
        elif op == "6":
            listar(fuentes)
        elif op == "7":
            eliminar(fuentes)
        elif op == "8":
            compilar()
        elif op == "0":
            print("\n¡Listo! Recuerda compilar (opción 8) para que los cambios entren a la app.\n")
            sys.exit(0)
        else:
            print("  Opción no válida.")


if __name__ == "__main__":
    main()
