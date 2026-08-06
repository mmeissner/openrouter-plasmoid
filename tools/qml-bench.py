#!/usr/bin/env python3
"""
Load the widget's QML outside plasmashell so warnings actually become visible.

Why this exists: `plasmawindowed` swallows QML output on a stock Plasma setup
(Qt logs to journald when stderr is not a TTY), and even a deliberately broken
binding produced no output there. This bench builds a throwaway copy of
contents/ui, swaps the `Plasmoid` attached object for a plain singleton stub,
and loads it in a PySide6 QML engine - so every warning lands on stderr and the
whole widget can be rendered to a PNG without a real OpenRouter account.

    tools/qml-bench.py                    run and print warnings
    tools/qml-bench.py --shot out.png     also render a screenshot

Requires python3-pyside6. Expected noise: "kf.i18n: Domain is not set" - the
translation domain is only registered by Plasma, not by this bench.

SPDX-License-Identifier: MIT
"""

import argparse
import os
import re
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "package", "contents", "ui")
CODE = os.path.join(ROOT, "package", "contents", "code")
ICONS = os.path.join(ROOT, "package", "contents", "icons")
LOCALE = os.path.join(ROOT, "package", "contents", "locale")
TOOLS = os.path.join(ROOT, "tools")


def build_tree(tmp):
    """Copy the widget sources and drop in the Plasmoid stub."""
    os.makedirs(os.path.join(tmp, "ui"))
    shutil.copytree(CODE, os.path.join(tmp, "code"))
    shutil.copytree(ICONS, os.path.join(tmp, "icons"))
    # Needed so the widget's own language override can be exercised
    if os.path.isdir(LOCALE):
        shutil.copytree(LOCALE, os.path.join(tmp, "locale"))
    for name in os.listdir(UI):
        if not name.endswith(".qml") or name == "main.qml":
            continue
        text = open(os.path.join(UI, name), encoding="utf-8").read()
        # The attached object only exists inside plasmashell. A singleton of the
        # same name resolves identically in QML, so the stub can stand in for it.
        text = re.sub(r"^import org\.kde\.plasma\.plasmoid\n", "", text, flags=re.M)
        open(os.path.join(tmp, "ui", name), "w", encoding="utf-8").write(text)
    for name in ("Plasmoid.qml", "qmldir", "TestMain.qml"):
        shutil.copy(os.path.join(TOOLS, name), os.path.join(tmp, "ui", name))


def main():
    parser = argparse.ArgumentParser(description="QML test bench for the widget")
    parser.add_argument("--shot", help="write a PNG of the rendered bench")
    parser.add_argument("--seconds", type=int, default=9, help="run time before quitting")
    parser.add_argument("--entry", default="TestMain.qml", help="QML file to load")
    args = parser.parse_args()

    from PySide6.QtCore import QTimer, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    tmp = tempfile.mkdtemp(prefix="openrouter-bench-")
    try:
        build_tree(tmp)
        entry = os.path.join(tmp, "ui", args.entry)

        if args.shot:
            # The bench reads its output path from a QML property
            text = open(entry, encoding="utf-8").read()
            text = re.sub(
                r'property string shotPath: "[^"]*"',
                'property string shotPath: "%s"' % os.path.abspath(args.shot),
                text,
            )
            open(entry, "w", encoding="utf-8").write(text)

        app = QGuiApplication(sys.argv[:1])
        engine = QQmlApplicationEngine()
        engine.addImportPath("/usr/lib64/qt6/qml")
        engine.load(QUrl.fromLocalFile(entry))

        if not engine.rootObjects():
            print("QML failed to load", file=sys.stderr)
            return 2

        QTimer.singleShot(args.seconds * 1000, app.quit)
        return app.exec()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
