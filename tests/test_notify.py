import importlib.util
import io
import sys
import tempfile
import types
import unittest
from contextlib import contextmanager
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NOTIFY_PATH = ROOT / "scripts" / "notify.py"

spec = importlib.util.spec_from_file_location("holyclaude_notify", NOTIFY_PATH)
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)


class FakeAppriseClient:
    def add(self, url):
        return url.startswith(("tgram://", "discord://"))

    def notify(self, **_kwargs):
        return True


@contextmanager
def fake_apprise():
    previous = sys.modules.get("apprise")
    sys.modules["apprise"] = types.SimpleNamespace(Apprise=FakeAppriseClient)
    try:
        yield
    finally:
        if previous is None:
            sys.modules.pop("apprise", None)
        else:
            sys.modules["apprise"] = previous


class NotifyTests(unittest.TestCase):
    def test_normalizes_legacy_telegram_scheme(self):
        self.assertEqual(
            notify.normalize_notify_url("tg://123456:abcdef/987654"),
            "tgram://123456:abcdef/987654",
        )
        self.assertEqual(
            notify.normalize_notify_url("TG://123456:abcdef/987654"),
            "tgram://123456:abcdef/987654",
        )
        self.assertEqual(
            notify.normalize_notify_url("tgram://123456:abcdef/987654"),
            "tgram://123456:abcdef/987654",
        )

    def test_collect_urls_splits_and_normalizes_notify_urls(self):
        environ = {
            "NOTIFY_TELEGRAM": "tg://123456:abcdef/987654",
            "NOTIFY_URLS": " discord://webhook_id/webhook_token, TG://111111:token/222222 ",
            "OTHER_SETTING": "tg://ignored",
        }

        self.assertEqual(
            notify.collect_notify_urls(environ),
            [
                "tgram://123456:abcdef/987654",
                "discord://webhook_id/webhook_token",
                "tgram://111111:token/222222",
            ],
        )

    def test_empty_environment_has_no_notification_urls(self):
        self.assertEqual(notify.collect_notify_urls({"TZ": "UTC"}), [])

    def test_dry_run_reports_status_without_secret_values(self):
        with tempfile.NamedTemporaryFile() as flag_file, fake_apprise():
            stream = io.StringIO()
            exit_code = notify.run_dry_run(
                flag_file.name,
                {"NOTIFY_TELEGRAM": "tg://123456:abcdef/987654"},
                debug=True,
                stream=stream,
            )

        output = stream.getvalue()
        self.assertEqual(exit_code, 0)
        self.assertIn("[notify] flag: present", output)
        self.assertIn("[notify] tgram: ok", output)
        self.assertNotIn("123456", output)
        self.assertNotIn("abcdef", output)
        self.assertNotIn("987654", output)
        self.assertNotIn("tg://", output)

    def test_dry_run_fails_when_no_urls_are_configured(self):
        with tempfile.NamedTemporaryFile() as flag_file, fake_apprise():
            stream = io.StringIO()
            exit_code = notify.run_dry_run(
                flag_file.name,
                {"TZ": "UTC"},
                debug=True,
                stream=stream,
            )

        self.assertEqual(exit_code, 1)
        self.assertIn("[notify] urls: 0", stream.getvalue())


if __name__ == "__main__":
    unittest.main()
