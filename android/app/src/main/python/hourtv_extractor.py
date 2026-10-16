"""HourTV-owned bridge. Resolve metadata only; never download or bypass DRM."""
import json
import re
from urllib.parse import urlsplit


def valid_url(value):
    if not isinstance(value, str):
        return False
    try:
        parsed = urlsplit(value)
        return (parsed.scheme == "https" and bool(parsed.hostname)
                and parsed.username is None and parsed.password is None)
    except ValueError:
        return False


def safe_headers(raw_headers):
    if not isinstance(raw_headers, dict):
        return {}
    return {
        key: value
        for key, value in raw_headers.items()
        if isinstance(key, str)
        and isinstance(value, str)
        and key.lower() in ("referer", "origin", "user-agent", "accept")
        and "\r" not in value
        and "\n" not in value
    }


def select_subtitles(info, fallback_headers):
    raw_subtitles = info.get("subtitles")
    if not isinstance(raw_subtitles, dict):
        return []

    format_by_extension = {
        "vtt": "vtt",
        "webvtt": "vtt",
        "srt": "srt",
        "subrip": "srt",
        "ass": "ass",
        "ssa": "ass",
    }
    extension_priority = {"vtt": 0, "webvtt": 1, "srt": 2, "subrip": 3, "ass": 4, "ssa": 5}
    tracks = []
    seen_urls = set()

    for language, entries in raw_subtitles.items():
        if (
            not isinstance(language, str)
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", language)
            or not isinstance(entries, list)
        ):
            continue
        choices = sorted(
            (entry for entry in entries if isinstance(entry, dict)),
            key=lambda entry: extension_priority.get(str(entry.get("ext", "")).lower(), 99),
        )
        for entry in choices:
            extension = str(entry.get("ext", "")).lower()
            subtitle_url = entry.get("url")
            if extension not in format_by_extension or not valid_url(subtitle_url):
                continue
            if subtitle_url in seen_urls:
                break
            headers = dict(fallback_headers)
            headers.update(safe_headers(entry.get("http_headers")))
            tracks.append({
                "url": subtitle_url,
                "language": language,
                "ext": format_by_extension[extension],
                "headers": headers,
                "isDefault": entry.get("default") is True,
            })
            seen_urls.add(subtitle_url)
            break
        if len(tracks) >= 12:
            break
    return tracks


def select_source(info):
    if not isinstance(info, dict) or info.get("has_drm"):
        return None
    # A playlist is not a selected episode. Never pick an arbitrary entry.
    if info.get("_type") in ("playlist", "multi_video"):
        return None
    candidates = [info] + list(reversed(info.get("formats") or []))
    for item in candidates:
        if not isinstance(item, dict) or item.get("has_drm"):
            continue
        if not valid_url(item.get("url")):
            continue
        # Reject split video/audio sources: current player expects a muxed URL.
        if item.get("vcodec") == "none" or item.get("acodec") == "none":
            continue
        if item.get("protocol", "").startswith(("http_dash_segments", "mhtml")):
            continue
        headers = safe_headers(item.get("http_headers"))
        protocol = str(item.get("protocol") or "").lower()
        ext = str(item.get("ext") or "").lower()
        path = urlsplit(item["url"]).path.lower()
        format_hint = None
        if (
            protocol.startswith(("m3u8", "hls"))
            or ext == "m3u8"
            or path.endswith(".m3u8")
        ):
            format_hint = "hls"
        elif (
            protocol.startswith("dash")
            or ext == "mpd"
            or path.endswith(".mpd")
        ):
            format_hint = "dash"
        elif (
            protocol.startswith(("ism", "smoothstreaming"))
            or ext in ("ism", "isml")
        ):
            format_hint = "ss"
        return {
            "url": item["url"],
            "headers": headers,
            "formatHint": format_hint,
            "subtitles": select_subtitles(info, headers),
        }
    return None


class QuietLogger:
    def debug(self, message):
        pass

    info = warning = error = debug


def resolve(url):
    if not valid_url(url):
        return "null"
    from yt_dlp import YoutubeDL
    options = {
        "quiet": True, "no_warnings": True, "logger": QuietLogger(),
        "skip_download": True, "noplaylist": True,
        "format": "best[vcodec!=none][acodec!=none]/best",
        "socket_timeout": 8, "retries": 0, "extractor_retries": 0,
        "cachedir": False, "ignoreconfig": True,
    }
    try:
        with YoutubeDL(options) as extractor:
            info = extractor.extract_info(url, download=False)
        return json.dumps(select_source(info))
    except Exception:
        # Never expose provider credentials, signed links or verbose errors.
        return "null"
