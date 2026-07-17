# -*- coding: utf-8 -*-
"""
Puente entre Server Hunter y HourTV AutoCatálogo
=================================================

Server Hunter (C:\\...\\PORTAFOLIO\\server-hunter-main) es una app de escritorio
que TÚ operas manualmente: pegas la URL de una página, pulsas "Iniciar
scraping" y ella detecta los reproductores/servidores ya embebidos en esa
página, agrupados por idioma. Cada resultado queda guardado en su base de
datos local (`data/server_hunter.db`) o se puede exportar a JSON desde su
interfaz.

Este script NO scrapea nada. Es solo un conversor: lee lo que Server Hunter
ya encontró, busca el `tmdbId` de cada título en TMDB, y escribe un archivo
en el formato que espera `OwnCatalogProvider`
(ver automation/src/providers/own-catalog-provider.ts y
data/provider-config.example.json), listo para publicar como OWN_CATALOG_URL.

USO:
  1) Escanea varias páginas con Server Hunter con normalidad (tu app, tu
     navegador, tu proceso manual de siempre).
  2) Desde esta carpeta (automation/tools), ejecuta:

       set TMDB_API_KEY=tu_clave_de_tmdb          (PowerShell: $env:TMDB_API_KEY="...")
       python server_hunter_sync.py

     Por defecto busca la base de datos de Server Hunter en las rutas
     habituales (instalada o en modo desarrollo). Si la tienes en otro
     sitio, indícala con --db "C:\\ruta\\a\\server_hunter.db".

  3) Revisa el archivo generado en
     automation/tools/own-catalog.generated.json:
       - "entries": coincidencias de alta confianza (título exacto en TMDB),
         listas para publicar.
       - "needsReview": coincidencias dudosas (TMDB no tuvo un título
         idéntico) — revísalas a mano antes de moverlas a "entries".
       - "unmatched": títulos que TMDB no encontró en absoluto.

  4) Cuando estés conforme, copia (o fusiona) el contenido de "entries" al
     archivo que publiques como OWN_CATALOG_URL (por ejemplo
     `data/own-catalog.json` en este mismo repo, servido vía
     raw.githubusercontent.com).

No inventa URLs ni evade nada: solo traduce datos que Server Hunter ya
extrajo de páginas que tú decidiste analizar.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterable

TMDB_BASE_URL = "https://api.themoviedb.org/3"
HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
SERVER_HUNTER_ROOT_GUESS = REPO_ROOT.parent / "server-hunter-main"

DEFAULT_DB_CANDIDATES = [
    SERVER_HUNTER_ROOT_GUESS / "data" / "server_hunter.db",
    Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "ServerHunter" / "data" / "server_hunter.db",
]

DEFAULT_OUTPUT = HERE / "own-catalog.generated.json"


def normalize_title(title: str) -> str:
    text = unicodedata.normalize("NFD", title or "")
    text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return text.strip()


def find_default_db() -> Path | None:
    for candidate in DEFAULT_DB_CANDIDATES:
        if candidate.exists():
            return candidate
    return None


def load_scrape_results_from_db(db_path: Path) -> list[dict[str, Any]]:
    connection = sqlite3.connect(str(db_path))
    connection.row_factory = sqlite3.Row
    try:
        rows = connection.execute("SELECT result_json FROM history ORDER BY detected_at ASC").fetchall()
    finally:
        connection.close()
    results = []
    for row in rows:
        try:
            results.append(json.loads(row["result_json"]))
        except (KeyError, json.JSONDecodeError):
            continue
    return results


def load_scrape_results_from_exports(exports_dir: Path) -> list[dict[str, Any]]:
    results = []
    for path in sorted(exports_dir.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(data, dict) and "languages" in data:
            results.append(data)
    return results


def tmdb_search_movie(api_key: str, title: str, language: str, year: str | None = None) -> list[dict[str, Any]]:
    params = {
        "api_key": api_key,
        "language": language,
        "query": title,
        "include_adult": "false",
    }
    if year:
        params["primary_release_year"] = year
    query = urllib.parse.urlencode(params)
    url = f"{TMDB_BASE_URL}/search/movie?{query}"
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            data = json.loads(response.read().decode("utf-8"))
            return data.get("results", [])
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as exc:
        print(f"  [!] Error consultando TMDB para \"{title}\": {exc}", file=sys.stderr)
        return []


def extract_year(text: str) -> str | None:
    match = re.search(r"\((19|20)\d{2}\)", text)
    return match.group(0).strip("()") if match else None


def clean_title_variants(raw_title: str) -> list[str]:
    """Genera variantes limpias de un título de página tipo
    'Ver Glenrothan (2026) Online Latino HD - Pelisplus', porque muchos
    sitios (incluido Pelisplus) usan el <title> de la página como nombre,
    no el título limpio de la película."""
    variants: list[str] = [raw_title.strip()]

    # Corta el sufijo del sitio: "... - Pelisplus", "... | NombreSitio"
    no_suffix = re.split(r"\s+[-|]\s+[^-|]{2,30}$", raw_title)[0].strip()
    variants.append(no_suffix)

    for base in list(variants):
        # Quita el prefijo "Ver "
        no_ver = re.sub(r"^\s*Ver\s+", "", base, flags=re.IGNORECASE).strip()
        variants.append(no_ver)
        # Corta todo lo que venga después de "Online" (idioma/calidad)
        no_online = re.split(r"\bOnline\b", no_ver, flags=re.IGNORECASE)[0].strip()
        variants.append(no_online)
        # Quita el año entre paréntesis
        no_year = re.sub(r"\(\s*(19|20)\d{2}\s*\)", "", no_online).strip()
        variants.append(no_year)

    seen: set[str] = set()
    cleaned: list[str] = []
    for v in variants:
        v = v.strip(" -|")
        key = v.lower()
        if v and key not in seen:
            seen.add(key)
            cleaned.append(v)
    return cleaned


def match_movie(api_key: str, raw_title: str, language: str) -> tuple[dict[str, Any] | None, str, str]:
    """Devuelve (resultado_tmdb_o_none, confianza: 'exact' | 'guess' | 'none', título_limpio_usado)."""
    year = extract_year(raw_title)
    variants = clean_title_variants(raw_title)

    best_guess: dict[str, Any] | None = None
    best_guess_variant = variants[0]

    for variant in variants:
        candidates = tmdb_search_movie(api_key, variant, language, year)
        if not candidates:
            continue
        if best_guess is None:
            best_guess = candidates[0]
            best_guess_variant = variant

        normalized_target = normalize_title(variant)
        for candidate in candidates:
            candidate_titles = [candidate.get("title", ""), candidate.get("original_title", "")]
            if any(normalize_title(t) == normalized_target for t in candidate_titles):
                return candidate, "exact", variant

    if best_guess is not None:
        return best_guess, "guess", best_guess_variant

    return None, "none", variants[0]


def collect_servers(result: dict[str, Any]) -> Iterable[dict[str, str]]:
    for language in result.get("languages", []):
        language_name = language.get("display_name") or language.get("code") or "Idioma sin identificar"
        for server in language.get("servers", []):
            url = server.get("url") or server.get("normalized_url")
            if not url:
                continue
            yield {
                "language": language_name,
                "serverName": server.get("display_name") or server.get("provider") or "Servidor",
                "url": url,
            }


def main() -> None:
    parser = argparse.ArgumentParser(description="Convierte resultados de Server Hunter al formato de OwnCatalogProvider")
    parser.add_argument("--db", type=str, default=None, help="Ruta a server_hunter.db")
    parser.add_argument("--exports-dir", type=str, default=None, help="Carpeta con JSON exportados manualmente desde Server Hunter")
    parser.add_argument("--tmdb-api-key", type=str, default=os.environ.get("TMDB_API_KEY", ""))
    parser.add_argument("--tmdb-language", type=str, default=os.environ.get("TMDB_LANGUAGE", "es-ES"))
    parser.add_argument("--out", type=str, default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()

    if not args.tmdb_api_key:
        print("Falta TMDB_API_KEY (variable de entorno o --tmdb-api-key).", file=sys.stderr)
        sys.exit(1)

    scrape_results: list[dict[str, Any]] = []

    if args.exports_dir:
        exports_dir = Path(args.exports_dir)
        if not exports_dir.is_dir():
            print(f"No existe la carpeta de exports: {exports_dir}", file=sys.stderr)
            sys.exit(1)
        scrape_results = load_scrape_results_from_exports(exports_dir)
        print(f"Leyendo exports JSON desde: {exports_dir} ({len(scrape_results)} archivos)")
    else:
        db_path = Path(args.db) if args.db else find_default_db()
        if not db_path or not db_path.exists():
            print(
                "No se encontró server_hunter.db automáticamente. Indica la ruta con --db "
                "o exporta resultados a JSON y usa --exports-dir.",
                file=sys.stderr,
            )
            sys.exit(1)
        scrape_results = load_scrape_results_from_db(db_path)
        print(f"Leyendo historial de Server Hunter: {db_path} ({len(scrape_results)} páginas escaneadas)")

    if not scrape_results:
        print("No hay resultados de Server Hunter para procesar todavía.")
        sys.exit(0)

    entries: list[dict[str, Any]] = []
    needs_review: list[dict[str, Any]] = []
    unmatched: list[dict[str, Any]] = []
    seen_entry_keys: set[tuple[Any, str, str]] = set()

    for result in scrape_results:
        title = (result.get("title") or "").strip()
        page_url = result.get("page_url", "")
        if not title:
            unmatched.append({"sourceTitle": title, "sourcePage": page_url, "reason": "Sin título detectado por Server Hunter"})
            continue

        servers = list(collect_servers(result))
        if not servers:
            continue

        print(f"Buscando en TMDB: \"{title}\"...")
        match, confidence, used_title = match_movie(args.tmdb_api_key, title, args.tmdb_language)

        if confidence == "none":
            unmatched.append({
                "sourceTitle": title,
                "sourcePage": page_url,
                "reason": f"TMDB no encontró resultados (probado como: \"{used_title}\")",
            })
            continue

        tmdb_id = match["id"]
        tmdb_title = match.get("title") or match.get("original_title")
        tmdb_year = (match.get("release_date") or "")[:4]

        if confidence == "exact":
            for server in servers:
                key = (tmdb_id, server["language"], server["url"])
                if key in seen_entry_keys:
                    continue
                seen_entry_keys.add(key)
                entries.append({
                    "tmdbId": tmdb_id,
                    "language": server["language"],
                    "serverName": server["serverName"],
                    "url": server["url"],
                })
            print(f"  -> Coincidencia exacta: {tmdb_title} ({tmdb_year}) [tmdbId={tmdb_id}] — {len(servers)} servidor(es)")
        else:
            needs_review.append({
                "sourceTitle": title,
                "cleanedTitle": used_title,
                "sourcePage": page_url,
                "guessedTmdbId": tmdb_id,
                "guessedTitle": tmdb_title,
                "guessedYear": tmdb_year,
                "servers": servers,
            })
            print(f"  -> Coincidencia dudosa (revisar a mano): {tmdb_title} ({tmdb_year}) [tmdbId={tmdb_id}]")

    output = {
        "_readme": (
            "Generado por automation/tools/server_hunter_sync.py a partir de Server Hunter. "
            "'entries' son coincidencias exactas listas para publicar como OWN_CATALOG_URL. "
            "'needsReview' y 'unmatched' NO se usan automáticamente: revísalas y muévelas a mano."
        ),
        "entries": entries,
        "needsReview": needs_review,
        "unmatched": unmatched,
    }

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print()
    print(f"Listo. Escrito en: {out_path}")
    print(f"  entries (listas):     {len(entries)}")
    print(f"  needsReview (dudosas): {len(needs_review)}")
    print(f"  unmatched (sin TMDB): {len(unmatched)}")


if __name__ == "__main__":
    main()
