"""Behavioral tests for the workshop's project and build boundaries."""

import contextlib
import io
import json
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from tools import ggg


class WorkshopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="godot-game-gallery-tests-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "games").mkdir()
        shutil.copytree(
            ggg.ROOT / "templates",
            self.root / "templates",
            ignore=shutil.ignore_patterns(".godot"),
        )
        shutil.copy2(ggg.ROOT / "engine.lock.json", self.root)

    def create(self, slug="moon-jumper", dimension="2d"):
        with contextlib.redirect_stdout(io.StringIO()):
            return ggg.new_game(slug, dimension, root=self.root)

    def rewrite(self, path, **changes):
        data = json.loads((path / "game.json").read_text())
        data.update(changes)
        (path / "game.json").write_text(json.dumps(data))

    def test_new_2d_and_3d_games_are_discovered_without_registration(self):
        self.create()
        self.create("sky-runner", "3d")
        games = ggg.discover(self.root)
        self.assertEqual([data["dimension"] for _, data in games], ["2d", "3d"])
        self.assertEqual(games[0][1]["title"], "Moon Jumper")

    def test_new_game_is_independent_of_template_and_other_games(self):
        first = self.create()
        second = self.create("second-game")
        (first / "player.gd").write_text("My experiment")
        self.assertNotEqual((first / "player.gd").read_text(), (second / "player.gd").read_text())
        self.assertIn("CharacterBody2D", (self.root / "templates/2d/player.gd").read_text())

    def test_game_title_is_escaped_for_godot_configuration(self):
        with contextlib.redirect_stdout(io.StringIO()):
            game = ggg.new_game("quoted", "2d", title='Moon "Jump" \\ Lab', root=self.root)
        self.assertIn(
            'config/name="Moon \\"Jump\\" \\\\ Lab"', (game / "project.godot").read_text()
        )

    def test_multiline_title_is_rejected(self):
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ggg.ArcadeError):
            ggg.new_game("multiline", "2d", title="Name\nInjected settings", root=self.root)

    def test_existing_game_is_never_overwritten(self):
        game = self.create()
        (game / "notes.txt").write_text("Keep my work")
        with self.assertRaises(ggg.ArcadeError):
            self.create()
        self.assertEqual((game / "notes.txt").read_text(), "Keep my work")

    def test_invalid_names_cannot_write_outside_games(self):
        for name in ("../escape", "/tmp/escape", "Uppercase", "two words", "a;touch-x", "-bad"):
            with self.subTest(name=name), self.assertRaises(ggg.ArcadeError):
                self.create(name)

    def test_failed_creation_leaves_no_half_created_game(self):
        with self.assertRaises(ggg.ArcadeError):
            with contextlib.redirect_stdout(io.StringIO()):
                ggg.new_game("broken", "2d", title=" " * 5, root=self.root)
        self.assertEqual(list((self.root / "games").iterdir()), [])

    def test_manifest_rejects_unsupported_versions_and_unknown_commands(self):
        game = self.create()
        self.rewrite(game, schema_version=2)
        with self.assertRaises(ggg.ArcadeError):
            ggg.discover(self.root)
        self.rewrite(game, schema_version=1, command="sh anything")
        with self.assertRaises(ggg.ArcadeError):
            ggg.discover(self.root)

    def test_manifest_rejects_non_string_fields_without_traceback(self):
        game = self.create()
        self.rewrite(game, title=None)
        with self.assertRaises(ggg.ArcadeError):
            ggg.read_game(game)

    def test_manifest_rejects_traversing_thumbnail(self):
        game = self.create()
        outside = self.root / "secret.svg"
        outside.write_text("outside")
        self.rewrite(game, thumbnail="../../secret.svg")
        with self.assertRaises(ggg.ArcadeError):
            ggg.read_game(game)

    def test_symlink_thumbnail_cannot_escape_game(self):
        game = self.create()
        outside = self.root / "outside.svg"
        outside.write_text("outside")
        (game / "tile.svg").unlink()
        (game / "tile.svg").symlink_to(outside)
        with self.assertRaises(ggg.ArcadeError):
            ggg.read_game(game)

    def test_ordinary_unfinished_folders_are_ignored(self):
        (self.root / "games/sketchbook").mkdir()
        self.assertEqual(ggg.discover(self.root), [])

    def test_game_folder_symlinks_are_rejected(self):
        self.create()
        (self.root / "games/linked-game").symlink_to(
            self.root / "games/moon-jumper", target_is_directory=True
        )
        with self.assertRaises(ggg.ArcadeError):
            ggg.discover(self.root)

    def test_engine_script_errors_fail_even_with_zero_exit_status(self):
        result = type(
            "Result", (), {"returncode": 0, "stdout": "SCRIPT ERROR: parse failed", "stderr": ""}
        )()
        with patch("tools.ggg.subprocess.run", return_value=result):
            with self.assertRaises(ggg.ArcadeError), contextlib.redirect_stdout(io.StringIO()):
                ggg.run_checked(["godot"], capture=True)

    def test_zip_traversal_is_rejected_before_extracting(self):
        archive = self.root / "bad.zip"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("../escape.txt", "oops")
        with self.assertRaises(ggg.ArcadeError):
            ggg.extract_verified(archive, self.root / "unpack")
        self.assertFalse((self.root / "escape.txt").exists())

    def test_failed_export_keeps_previous_distribution(self):
        self.create()
        shutil.copytree(
            ggg.ROOT / "launcher",
            self.root / "launcher",
            ignore=shutil.ignore_patterns(".godot"),
        )
        previous = self.root / "dist/linux"
        previous.mkdir(parents=True)
        (previous / "keep.txt").write_text("working build")
        with patch("tools.ggg.engine", return_value="godot"):
            with patch("tools.ggg.run_checked", side_effect=ggg.ArcadeError("export failed")):
                with self.assertRaises(ggg.ArcadeError):
                    ggg.build("linux", self.root)
        self.assertEqual((previous / "keep.txt").read_text(), "working build")
        self.assertEqual([p.name for p in previous.parent.iterdir()], ["linux"])


if __name__ == "__main__":
    unittest.main()
