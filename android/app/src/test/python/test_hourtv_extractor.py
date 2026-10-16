import importlib.util
from pathlib import Path
import unittest

source = Path(__file__).resolve().parents[2] / "main/python/hourtv_extractor.py"
spec = importlib.util.spec_from_file_location("hourtv_extractor", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SourceTests(unittest.TestCase):
    def test_muxed_source(self):
        result = module.select_source({
            "url": "https://cdn.test/master.m3u8",
            "http_headers": {"Referer": "https://provider.test/", "Cookie": "secret"},
        })
        self.assertEqual(result["url"], "https://cdn.test/master.m3u8")
        self.assertEqual(result["formatHint"], "hls")
        self.assertNotIn("Cookie", result["headers"])

    def test_protocol_hint_survives_an_opaque_signed_url(self):
        result = module.select_source({
            "url": "https://cdn.test/play?id=123&sig=x",
            "protocol": "m3u8_native",
            "ext": "mp4",
        })
        self.assertEqual(result["formatHint"], "hls")

    def test_regular_mp4_keeps_platform_autodetection(self):
        result = module.select_source({
            "url": "https://cdn.test/video.mp4",
            "protocol": "https",
            "ext": "mp4",
        })
        self.assertIsNone(result["formatHint"])

    def test_sidecar_subtitles_keep_language_format_and_safe_headers(self):
        result = module.select_source({
            "url": "https://cdn.test/video.mp4",
            "http_headers": {"User-Agent": "HourTV", "Cookie": "secret"},
            "subtitles": {
                "es": [
                    {"url": "https://cdn.test/captions.srt", "ext": "srt"},
                    {
                        "url": "https://cdn.test/captions.vtt?sig=x",
                        "ext": "vtt",
                        "http_headers": {"Referer": "https://cdn.test/", "Cookie": "secret"},
                    },
                ],
                "fr": [{"url": "http://cdn.test/fr.vtt", "ext": "vtt"}],
            },
            "automatic_captions": {
                "en": [{"url": "https://cdn.test/auto.vtt", "ext": "vtt"}],
            },
        })
        self.assertEqual(len(result["subtitles"]), 1)
        track = result["subtitles"][0]
        self.assertEqual(track["language"], "es")
        self.assertEqual(track["ext"], "vtt")
        self.assertEqual(track["headers"]["User-Agent"], "HourTV")
        self.assertEqual(track["headers"]["Referer"], "https://cdn.test/")
        self.assertNotIn("Cookie", track["headers"])

    def test_automatic_captions_are_not_misrepresented_as_provider_subtitles(self):
        result = module.select_source({
            "url": "https://cdn.test/video.mp4",
            "automatic_captions": {
                "es": [{"url": "https://cdn.test/auto.vtt", "ext": "vtt"}],
            },
        })
        self.assertEqual(result["subtitles"], [])

    def test_invalid_subtitle_language_is_dropped_instead_of_truncated(self):
        result = module.select_source({
            "url": "https://cdn.test/video.mp4",
            "subtitles": {
                "es\r\n": [{"url": "https://cdn.test/invalid.vtt", "ext": "vtt"}],
                "x" * 33: [{"url": "https://cdn.test/long.vtt", "ext": "vtt"}],
            },
        })
        self.assertEqual(result["subtitles"], [])

    def test_drm_rejected(self):
        self.assertIsNone(module.select_source({"url": "https://cdn.test/v", "has_drm": True}))

    def test_playlist_rejected(self):
        self.assertIsNone(module.select_source({"_type": "playlist", "url": "https://cdn.test/v"}))

    def test_split_tracks_rejected(self):
        for key in ("vcodec", "acodec"):
            self.assertIsNone(module.select_source({"url": "https://cdn.test/v", key: "none"}))

    def test_unsafe_url_rejected(self):
        for url in ("blob:https://cdn.test/id", "http://cdn.test/v", "https://u:p@cdn.test/v"):
            self.assertIsNone(module.select_source({"url": url}))

    def test_format_fallback(self):
        result = module.select_source({"formats": [
            {"url": "https://cdn.test/a.mp4", "acodec": "aac", "vcodec": "h264"},
            {"url": "https://cdn.test/split.mp4", "acodec": "none"}]})
        self.assertEqual(result["url"], "https://cdn.test/a.mp4")

    def test_header_injection_rejected(self):
        result = module.select_source({"url": "https://cdn.test/v",
            "http_headers": {"Referer": "https://p.test/\r\nCookie: secret"}})
        self.assertEqual(result["headers"], {})
