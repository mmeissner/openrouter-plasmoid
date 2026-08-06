#!/usr/bin/env python3
"""
Preflight check - does the package still hold together?

Everything here is a mistake that survives a casual look at the diff but breaks
the widget after installation: a config key that no longer exists in main.xml,
a settings page whose file was renamed, a translated string that was never
extracted, a stale catalogs.js. Plasma reports none of those - it just renders
an empty binding and moves on.

    tools/check.py                    run every check
    tools/check.py --require-qmllint  treat a missing qmllint as a failure (CI)

Only the QML syntax pass needs a tool that is not in the standard library
(qmllint from qt6-qtdeclarative-devel); every other check is pure Python so the
package can be verified on a machine without a Qt SDK.

SPDX-License-Identifier: MIT
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = os.path.join(ROOT, "package")
CONTENTS = os.path.join(PACKAGE, "contents")
METADATA = os.path.join(PACKAGE, "metadata.json")
PO_DIR = os.path.join(ROOT, "translate", "po")

sys.path.insert(0, os.path.join(ROOT, "translate"))
import i18n  # noqa: E402  - the translation toolchain doubles as the parser here

REQUIRED_TOP = ("KPackageStructure", "KPlugin", "X-Plasma-API", "X-Plasma-MainScript")
REQUIRED_KPLUGIN = (
    "Authors", "Category", "Description", "Icon", "Id", "License", "Name",
    "Version", "Website",
)
REQUIRED_FILES = (
    "metadata.json",
    "contents/ui/main.qml",
    "contents/ui/L10n.qml",
    "contents/config/main.xml",
    "contents/config/config.qml",
    "contents/code/catalogs.js",
    "contents/code/utils.js",
    "contents/icons/openrouter.svg",
)


def rel(path):
    return os.path.relpath(path, ROOT)


def languages():
    """The languages the widget actually ships, taken from the po files."""
    return sorted(n[:-3] for n in os.listdir(PO_DIR) if n.endswith(".po"))


def qml_sources():
    for base, _dirs, files in os.walk(CONTENTS):
        for name in sorted(files):
            if name.endswith(".qml"):
                yield os.path.join(base, name)


# ----------------------------------------------------------------------
# Checks - each returns (errors, notes)
# ----------------------------------------------------------------------
def check_metadata():
    errors, notes = [], []
    try:
        with open(METADATA, encoding="utf-8") as fh:
            meta = json.load(fh)
    except (OSError, ValueError) as exc:
        return ["metadata.json does not parse: %s" % exc], notes

    for key in REQUIRED_TOP:
        if key not in meta:
            errors.append("missing top level key %r" % key)
    plugin = meta.get("KPlugin", {})
    for key in REQUIRED_KPLUGIN:
        if key not in plugin:
            errors.append("missing KPlugin key %r" % key)

    if meta.get("KPackageStructure") != "Plasma/Applet":
        errors.append("KPackageStructure must be Plasma/Applet")

    version = plugin.get("Version", "")
    if not re.match(r"^\d+\.\d+\.\d+$", version):
        errors.append("Version %r is not MAJOR.MINOR.PATCH" % version)

    # KPackage looks up the catalogue by plugin id, so a rename here silently
    # turns off every translation
    expected_id = i18n.DOMAIN[len("plasma_applet_"):]
    if plugin.get("Id") != expected_id:
        errors.append(
            "Id %r does not match the gettext domain in i18n.py (expected %r)"
            % (plugin.get("Id"), expected_id)
        )

    main_script = meta.get("X-Plasma-MainScript", "")
    if main_script and not os.path.isfile(os.path.join(CONTENTS, main_script)):
        errors.append("X-Plasma-MainScript points at a missing file: %s" % main_script)

    icon = plugin.get("Icon", "")
    if icon and not os.path.isfile(os.path.join(CONTENTS, "icons", icon + ".svg")):
        errors.append("Icon %r has no contents/icons/%s.svg" % (icon, icon))

    # Name[xx]/Description[xx] and the po files must describe the same set of
    # languages, otherwise the widget explorer falls back to English for one of
    # the two while the popup is translated
    langs = set(languages())
    for field in ("Name", "Description"):
        tagged = {
            m.group(1)
            for key in plugin
            for m in [re.match(r"^%s\[(.+)\]$" % field, key)]
            if m
        }
        for lang in sorted(langs - tagged):
            errors.append("metadata has no %s[%s] but translate/po/%s.po exists"
                          % (field, lang, lang))
        for lang in sorted(tagged - langs):
            errors.append("metadata has %s[%s] but there is no po file for it"
                          % (field, lang))

    notes.append("version %s, %d languages" % (version, len(langs)))
    return errors, notes


def check_layout():
    errors = []
    for path in REQUIRED_FILES:
        if not os.path.isfile(os.path.join(PACKAGE, path)):
            errors.append("missing %s" % path)
    return errors, ["%d QML files" % sum(1 for _ in qml_sources())]


def check_config():
    """Every config key used by the QML has to exist in main.xml."""
    errors, notes = [], []
    schema = os.path.join(CONTENTS, "config", "main.xml")
    try:
        tree = ET.parse(schema)
    except (OSError, ET.ParseError) as exc:
        return ["config/main.xml does not parse: %s" % exc], notes

    declared = {
        el.get("name")
        for el in tree.iter()
        if el.tag.endswith("}entry") or el.tag == "entry"
    }
    declared.discard(None)

    # Three ways the QML reaches a key: Plasmoid.configuration.<key>, an alias
    # property bound to the configuration object, and the cfg_<key> properties
    # Plasma generates for the settings pages
    texts = {path: i18n.strip_comments(open(path, encoding="utf-8").read())
             for path in qml_sources()}
    aliases = {"cfg"}
    for text in texts.values():
        aliases.update(re.findall(
            r"property\s+var\s+(\w+)\s*:\s*[Pp]lasmoid\.configuration\b", text))
    alias_re = re.compile(r"\b(?:%s)\.([A-Za-z_]\w*)" % "|".join(sorted(aliases)))

    used = {}
    for path, text in texts.items():
        for m in re.finditer(r"\b[Pp]lasmoid\.configuration\.([A-Za-z_]\w*)", text):
            used.setdefault(m.group(1), set()).add(rel(path))
        for m in alias_re.finditer(text):
            used.setdefault(m.group(1), set()).add(rel(path))
        for m in re.finditer(r"\bcfg_([A-Za-z_]\w*)\b", text):
            # Plasma also generates cfg_<key>Default for every key
            key = re.sub(r"Default$", "", m.group(1))
            used.setdefault(key, set()).add(rel(path))

    for key in sorted(used):
        if key not in declared:
            errors.append("config key %r is used in %s but not declared in main.xml"
                          % (key, ", ".join(sorted(used[key]))))
    unused = sorted(declared - set(used))
    if unused:
        notes.append("declared but unused: %s" % ", ".join(unused))

    # A settings page that lost its file leaves an empty tab in the dialog
    config_qml = os.path.join(CONTENTS, "config", "config.qml")
    sources = re.findall(r'source:\s*"([^"]+)"', open(config_qml, encoding="utf-8").read())
    for src in sources:
        if not os.path.isfile(os.path.join(CONTENTS, "ui", src)):
            errors.append("config.qml lists %s, which does not exist in contents/ui" % src)

    notes.append("%d keys, %d settings pages" % (len(declared), len(sources)))
    return errors, notes


def find_qmllint():
    for candidate in ("qmllint", "qmllint6"):
        found = shutil.which(candidate)
        if found:
            return found
    for path in ("/usr/lib64/qt6/bin/qmllint", "/usr/lib/qt6/bin/qmllint",
                 "/usr/lib/qt6/bin/qmllint6"):
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    try:
        import PySide6
        path = os.path.join(os.path.dirname(PySide6.__file__), "qmllint")
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    except ImportError:
        pass
    return None


# qmllint tags every message with a category. Most of them need the Plasma and
# Kirigami modules on the import path - unavailable here and absent altogether
# on CI - so they would only produce noise. These are the ones that are decided
# from the file alone and therefore mean the same everywhere.
QMLLINT_FATAL = frozenset((
    "syntax", "invalid-lint-directive", "duplicate-property-binding",
    "duplicated-name", "duplicate-import", "duplicate-enum-entries",
    "duplicate-inline-component", "assignment-in-condition", "unterminated-case",
    "unreachable-code", "var-used-before-declaration", "eval", "with",
    "multiline-strings",
))
QMLLINT_LINE_RE = re.compile(r"^(?:Warning|Error|Info):\s*(.*)\s\[([a-z0-9-]+)\]$")


def check_qml(require_qmllint=False):
    linter = find_qmllint()
    if not linter:
        message = ("qmllint not found - install qt6-qtdeclarative-devel (Fedora) "
                   "or qt6-declarative-dev-tools (Debian)")
        return ([message] if require_qmllint else []), ([] if require_qmllint else [message])

    files = list(qml_sources())
    proc = subprocess.run(
        [linter, "-I", os.path.join(CONTENTS, "ui")] + files,
        capture_output=True, text=True,
    )
    errors = []
    for line in (proc.stdout + proc.stderr).splitlines():
        m = QMLLINT_LINE_RE.match(line.strip())
        if m and m.group(2) in QMLLINT_FATAL:
            errors.append("%s [%s]" % (m.group(1).replace(ROOT + os.sep, ""), m.group(2)))
    version = subprocess.run([linter, "--version"], capture_output=True, text=True)
    return errors, ["%d files, %s" % (len(files), version.stdout.strip() or "qmllint")]


def check_translations():
    """The generated artefacts have to match the sources they came from."""
    errors, notes = [], []
    template_path = os.path.join(ROOT, "translate", "template.pot")
    if not os.path.isfile(template_path):
        return ["translate/template.pot is missing - run translate/i18n.py extract"], notes

    extracted = i18n.extract()
    _, template = i18n.parse_po(template_path)

    def label(key):
        ctx, msgid = key
        return '"%s"%s' % (msgid, " (%s)" % ctx if ctx else "")

    for key in sorted(set(extracted) - set(template), key=label):
        errors.append("%s is in the sources but not in template.pot - run i18n.py extract"
                      % label(key))
    for key in sorted(set(template) - set(extracted), key=label):
        errors.append("%s is in template.pot but no longer in the sources - run i18n.py extract"
                      % label(key))

    catalogs = {}
    for lang in languages():
        header, entries = i18n.parse_po(os.path.join(PO_DIR, lang + ".po"))
        missing = set(template) - set(entries)
        obsolete = set(entries) - set(template)
        if missing or obsolete:
            errors.append("po/%s.po is %d messages behind and carries %d obsolete ones "
                          "- run i18n.py merge" % (lang, len(missing), len(obsolete)))
        catalogs[lang] = i18n.catalog_payload(lang, header, entries)

    # catalogs.js is committed because QML imports it statically, so a clone can
    # end up with translations that no longer match the po files
    js = os.path.join(CONTENTS, "code", "catalogs.js")
    match = re.search(r"^var CATALOGS = (.*);$", open(js, encoding="utf-8").read(), re.M)
    if not match:
        errors.append("contents/code/catalogs.js has no CATALOGS assignment")
    else:
        try:
            committed = json.loads(match.group(1))
        except ValueError as exc:
            committed = None
            errors.append("catalogs.js does not parse: %s" % exc)
        if committed is not None and committed != catalogs:
            stale = sorted(
                lang for lang in set(committed) | set(catalogs)
                if committed.get(lang) != catalogs.get(lang)
            )
            errors.append("catalogs.js is out of date for %s - run i18n.py build"
                          % ", ".join(stale))

    done = {
        lang: sum(1 for e in i18n.parse_po(os.path.join(PO_DIR, lang + ".po"))[1].values()
                  if any(e["msgstr"].values()))
        for lang in languages()
    }
    behind = [l for l, n in done.items() if n < len(template)]
    notes.append("%d messages, %d languages%s" % (
        len(template), len(done),
        ", incomplete: " + ", ".join("%s %d/%d" % (l, done[l], len(template))
                                     for l in sorted(behind)) if behind else "",
    ))
    return errors, notes


def check_shell():
    errors = []
    scripts = sorted(n for n in os.listdir(ROOT) if n.endswith(".sh"))
    for name in scripts:
        proc = subprocess.run(["bash", "-n", os.path.join(ROOT, name)],
                              capture_output=True, text=True)
        if proc.returncode != 0:
            errors.append("%s: %s" % (name, proc.stderr.strip()))
    return errors, ["%d scripts" % len(scripts)]


def check_docs():
    """Screenshots move around; README links to them should not rot."""
    errors = []
    readme = os.path.join(ROOT, "README.md")
    text = open(readme, encoding="utf-8").read()
    targets = re.findall(r"!?\[[^\]]*\]\(([^)\s]+)\)", text)
    targets += re.findall(r'src="([^"]+)"', text)
    checked = 0
    for target in targets:
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue
        checked += 1
        if not os.path.exists(os.path.join(ROOT, target.split("#")[0])):
            errors.append("README links to %s, which does not exist" % target)
    return errors, ["%d local links" % checked]


CHECKS = (
    ("metadata", check_metadata),
    ("package layout", check_layout),
    ("settings schema", check_config),
    ("QML syntax", check_qml),
    ("translations", check_translations),
    ("shell scripts", check_shell),
    ("docs links", check_docs),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("--require-qmllint", action="store_true",
                        help="fail when qmllint is unavailable instead of skipping")
    args = parser.parse_args()

    failed = 0
    for name, check in CHECKS:
        kwargs = {"require_qmllint": args.require_qmllint} if check is check_qml else {}
        try:
            errors, notes = check(**kwargs)
        except Exception as exc:  # a broken check must not look like a pass
            errors, notes = ["check crashed: %r" % exc], []
        status = "FAIL" if errors else "ok"
        print("%-16s %-5s %s" % (name, status, "; ".join(notes)))
        for error in errors:
            print("                 - %s" % error)
        failed += len(errors)

    print()
    if failed:
        print("%d problem%s found" % (failed, "" if failed == 1 else "s"))
        return 1
    print("package looks good")
    return 0


if __name__ == "__main__":
    sys.exit(main())
