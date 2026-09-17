import importlib.util
import json
import sys
import tempfile
import tarfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest import mock


RUNNER_PATH = Path(__file__).parents[1] / "run.py"
SPEC = importlib.util.spec_from_file_location("vagrant_runner", RUNNER_PATH)
runner = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = runner
SPEC.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def test_redact_removes_sensitive_values_and_ansi(self):
        raw = ("\x1b[31mpassword: hunter2 token=abc123 licence secret-value "
               "AWS_SECRET_ACCESS_KEY=KEYVALUE42 DB_PWD=DBVALUE42 "
               "Authorization: Bearer BEARERVALUE42\x1b[0m")
        cleaned = runner.redact(raw)
        for secret in ("hunter2", "abc123", "secret-value", "KEYVALUE42", "DBVALUE42", "BEARERVALUE42"):
            self.assertNotIn(secret, cleaned)
        self.assertNotIn("\x1b", cleaned)
        self.assertEqual(cleaned.count("[REDACTED]"), 6)

    def test_matrix_rejects_missing_box_version(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "matrix.json"
            path.write_text(json.dumps({
                "schema": 1,
                "provider": "libvirt",
                "machines": {"debian": {"distribution": "Debian", "release": "13", "box": "box"}},
            }))
            with self.assertRaises(runner.HarnessError):
                runner.load_matrix(path)

    def test_junit_redacts_failure_details(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "junit.xml"
            runner.write_junit(path, [runner.Result("debian", "install", 1.2, "password: unsafe")])
            document = ET.parse(path)
            failure = document.find(".//failure")
            self.assertIsNotNone(failure)
            self.assertNotIn("unsafe", failure.text)
            self.assertIn("[REDACTED]", failure.text)

    def test_candidate_archive_contains_only_tracked_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidate.tar.gz"
            runner.create_candidate_archive(path)
            with tarfile.open(path) as archive:
                names = archive.getnames()
            self.assertIn("ansible-cycloid-onprem/tasks/main.yml", names)
            self.assertFalse(any("/.git/" in name or "/.work/" in name for name in names))

    def test_collection_phase_rejects_shell_and_path_metacharacters(self):
        with self.assertRaises(runner.HarnessError):
            runner.valid_identifier("../../raw;id", "collection phase")

    def test_ssh_config_discards_provider_warnings(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(
                runner,
                "capture",
                return_value="[fog][WARNING] provider warning\nHost debian\n  HostName 192.0.2.10",
            ):
                path = runner.ssh_config("debian", Path(directory), {})
            content = path.read_text()
            self.assertTrue(content.startswith("Host debian\n"))
            self.assertNotIn("fog", content)


if __name__ == "__main__":
    unittest.main()
