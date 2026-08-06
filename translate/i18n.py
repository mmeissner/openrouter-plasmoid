#!/usr/bin/env python3
"""
Self-contained translation toolchain for the OpenRouter plasmoid.

Deliberately depends on nothing but the Python standard library, so the widget
can be built on a machine without gettext installed.

    ./i18n.py extract          rebuild translate/template.pot from the QML sources
    ./i18n.py merge            merge new strings into every translate/po/*.po
    ./i18n.py build            compile translate/po/*.po into the package
    ./i18n.py stats            show translation coverage per language

SPDX-License-Identifier: MIT
"""

import json
import os
import re
import struct
import sys
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PACKAGE = os.path.join(ROOT, "package")
PO_DIR = os.path.join(HERE, "po")
TEMPLATE = os.path.join(HERE, "template.pot")

# Must match the plasmoid id, that is where KPackage looks for the catalogue
DOMAIN = "plasma_applet_com.github.teodorgross.openrouter"

# Start of i18n(msgid), i18nc(context, msgid), i18np(singular, plural),
# i18ncp(context, singular, plural) and the L10n wrappers tr/trc/trp/trcp that
# route the same messages through the widget's own language override.
# The closing parenthesis is found by counting, not by a lookahead: a call
# sitting in front of a ternary colon used to swallow the following one.
CALL_START_RE = re.compile(r"\b(?:i18n|tr)(?P<flags>c?p?)\s*\(")
STRING_RE = re.compile(r'"((?:[^"\\]|\\.)*)"' r"|'((?:[^'\\]|\\.)*)'")


# ----------------------------------------------------------------------
# Extraction
# ----------------------------------------------------------------------
def source_files():
    for base, _dirs, files in os.walk(PACKAGE):
        for f in sorted(files):
            if f.endswith((".qml", ".js")):
                yield os.path.join(base, f)


def strip_comments(text):
    """Blank out // and /* */ comments while preserving offsets and newlines.

    Without this, prose that merely mentions i18n() inside a comment gets
    picked up as a message.
    """
    out = []
    i = 0
    n = len(text)
    quote = None
    while i < n:
        c = text[i]
        if quote:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in "\"'`":
            quote = c
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def call_arguments(text, open_paren):
    """Return the argument text of a call whose "(" sits at open_paren.

    Walks forward counting parentheses and skipping string literals, so nested
    calls and parentheses inside messages cannot end the match early.
    """
    depth = 0
    i = open_paren
    n = len(text)
    quote = None
    while i < n:
        c = text[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in "\"'`":
            quote = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren + 1:i]
        i += 1
    return None


def leading_strings(args, count):
    """Return the first `count` string literals of an argument list.

    Adjacent literals are concatenated the way JavaScript would, so a message
    split across several source lines still yields one msgid.
    """
    out = []
    pos = 0
    while len(out) < count:
        m = STRING_RE.search(args, pos)
        if not m:
            return None
        text = m.group(1) if m.group(1) is not None else m.group(2)
        pos = m.end()
        # Swallow further literals that are only separated by whitespace or +
        while True:
            m2 = re.compile(r"\s*\+\s*").match(args, pos)
            if not m2:
                break
            m3 = STRING_RE.match(args, m2.end())
            if not m3:
                break
            text += m3.group(1) if m3.group(1) is not None else m3.group(2)
            pos = m3.end()
        out.append(unescape(text))
        m4 = re.compile(r"\s*,\s*").match(args, pos)
        if m4:
            pos = m4.end()
        elif len(out) < count:
            return None
    return out


def unescape(s):
    return (
        s.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace('\\"', '"')
        .replace("\\'", "'")
        .replace("\\\\", "\\")
    )


def escape(s):
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def extract():
    """Scan every QML/JS file and collect the translatable messages."""
    messages = {}  # (context, singular) -> {plural, locations}
    for path in source_files():
        rel = os.path.relpath(path, ROOT)
        text = strip_comments(open(path, encoding="utf-8").read())
        for m in CALL_START_RE.finditer(text):
            flags = m.group("flags")
            has_ctx = "c" in flags
            has_plural = "p" in flags
            wanted = 1 + (1 if has_ctx else 0) + (1 if has_plural else 0)
            args = call_arguments(text, m.end() - 1)
            if args is None:
                continue
            parts = leading_strings(args, wanted)
            if parts is None:
                continue
            i = 0
            ctx = parts[i] if has_ctx else None
            if has_ctx:
                i += 1
            singular = parts[i]
            plural = parts[i + 1] if has_plural else None
            line = text.count("\n", 0, m.start()) + 1
            entry = messages.setdefault(
                (ctx, singular), {"plural": plural, "locations": []}
            )
            if plural and not entry["plural"]:
                entry["plural"] = plural
            entry["locations"].append("%s:%d" % (rel, line))
    return messages


def write_template(messages):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M+0000")
    out = [
        "# Translation template for the OpenRouter Plasma widget.",
        "# Copyright (C) 2026 Teodor Gross",
        "# This file is distributed under the same licence as the widget.",
        "#",
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: openrouter-plasmoid\\n"',
        '"Report-Msgid-Bugs-To: https://github.com/teodorgross/openrouter-plasmoid/issues\\n"',
        '"POT-Creation-Date: %s\\n"' % now,
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"',
        "",
    ]
    for (ctx, singular), entry in sorted(
        messages.items(), key=lambda kv: (kv[0][1], kv[0][0] or "")
    ):
        for loc in entry["locations"]:
            out.append("#: %s" % loc)
        if ctx:
            out.append('msgctxt "%s"' % escape(ctx))
        out.append('msgid "%s"' % escape(singular))
        if entry["plural"]:
            out.append('msgid_plural "%s"' % escape(entry["plural"]))
            out.append('msgstr[0] ""')
            out.append('msgstr[1] ""')
        else:
            out.append('msgstr ""')
        out.append("")
    open(TEMPLATE, "w", encoding="utf-8").write("\n".join(out))
    return len(messages)


# ----------------------------------------------------------------------
# PO parsing
# ----------------------------------------------------------------------
def parse_po(path):
    """Return (header_dict, entries) where entries maps (ctx, msgid) -> dict."""
    entries = {}
    header = {}
    ctx = msgid = plural = None
    msgstrs = {}
    current = None

    def flush():
        nonlocal ctx, msgid, plural, msgstrs, current
        if msgid is not None:
            if msgid == "" and ctx is None:
                for line in msgstrs.get(0, "").split("\n"):
                    if ":" in line:
                        k, v = line.split(":", 1)
                        header[k.strip()] = v.strip()
            else:
                entries[(ctx, msgid)] = {"plural": plural, "msgstr": dict(msgstrs)}
        ctx = msgid = plural = None
        msgstrs = {}
        current = None

    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            if not line.strip():
                flush()
            continue
        m = re.match(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+"(.*)"$', line)
        if m:
            kind = m.group(1)
            text = unescape(m.group(3))
            if kind == "msgctxt":
                flush() if msgid is not None else None
                ctx = text
                current = ("ctx",)
            elif kind == "msgid":
                msgid = text
                current = ("id",)
            elif kind == "msgid_plural":
                plural = text
                current = ("plural",)
            else:
                idx = int(m.group(2) or 0)
                msgstrs[idx] = text
                current = ("str", idx)
            continue
        m = re.match(r'^"(.*)"$', line.strip())
        if m and current:
            text = unescape(m.group(1))
            if current[0] == "ctx":
                ctx += text
            elif current[0] == "id":
                msgid += text
            elif current[0] == "plural":
                plural += text
            else:
                msgstrs[current[1]] = msgstrs.get(current[1], "") + text
    flush()
    return header, entries


# ----------------------------------------------------------------------
# MO writing (GNU gettext binary format)
# ----------------------------------------------------------------------
def write_mo(path, header, entries):
    items = []
    header_text = "".join("%s: %s\n" % (k, v) for k, v in sorted(header.items()))
    items.append(("", header_text))

    for (ctx, msgid), entry in entries.items():
        strs = entry["msgstr"]
        if entry["plural"]:
            translated = [strs.get(i, "") for i in sorted(strs)]
            if not any(translated):
                continue
            key = msgid + "\x00" + entry["plural"]
            value = "\x00".join(translated)
        else:
            if not strs.get(0):
                continue
            key = msgid
            value = strs[0]
        if ctx:
            key = ctx + "\x04" + key
        items.append((key, value))

    items.sort(key=lambda kv: kv[0].encode("utf-8"))
    keys = [k.encode("utf-8") for k, _ in items]
    values = [v.encode("utf-8") for _, v in items]

    n = len(items)
    key_table_off = 28
    val_table_off = key_table_off + n * 8
    data_off = val_table_off + n * 8

    offsets, blob = [], b""
    for k in keys:
        offsets.append((len(k), data_off + len(blob)))
        blob += k + b"\x00"
    val_offsets = []
    for v in values:
        val_offsets.append((len(v), data_off + len(blob)))
        blob += v + b"\x00"

    # MO header: magic, revision, string count, offset of the original table,
    # offset of the translation table, hash table size, hash table offset.
    # All seven fields are 4 bytes wide - 28 in total.
    out = struct.pack("<Iiiiiii", 0x950412DE, 0, n, key_table_off, val_table_off, 0, 0)
    for length, off in offsets:
        out += struct.pack("<ii", length, off)
    for length, off in val_offsets:
        out += struct.pack("<ii", length, off)
    out += blob

    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(out)
    return n - 1  # minus the header entry


# ----------------------------------------------------------------------
# Commands
# ----------------------------------------------------------------------
def cmd_extract():
    messages = extract()
    count = write_template(messages)
    print("extracted %d messages -> %s" % (count, os.path.relpath(TEMPLATE, ROOT)))


def cmd_merge():
    if not os.path.exists(TEMPLATE):
        cmd_extract()
    _, template = parse_po(TEMPLATE)
    for name in sorted(os.listdir(PO_DIR)):
        if not name.endswith(".po"):
            continue
        path = os.path.join(PO_DIR, name)
        header, entries = parse_po(path)
        added = 0
        for key, entry in template.items():
            if key not in entries:
                entries[key] = {"plural": entry["plural"], "msgstr": {}}
                added += 1
        obsolete = [k for k in entries if k not in template]
        for key in obsolete:
            del entries[key]
        write_po(path, header, entries)
        print(
            "%-8s %d new, %d obsolete removed, %d total"
            % (name, added, len(obsolete), len(entries))
        )


def write_po(path, header, entries):
    out = ['msgid ""', 'msgstr ""']
    for k, v in sorted(header.items()):
        out.append('"%s: %s\\n"' % (k, escape(v)))
    out.append("")
    for (ctx, msgid), entry in sorted(
        entries.items(), key=lambda kv: (kv[0][1], kv[0][0] or "")
    ):
        if ctx:
            out.append('msgctxt "%s"' % escape(ctx))
        out.append('msgid "%s"' % escape(msgid))
        if entry["plural"]:
            out.append('msgid_plural "%s"' % escape(entry["plural"]))
            # Write as many forms as the language actually declares
            count = max(2, (max(entry["msgstr"]) + 1) if entry["msgstr"] else 2)
            for i in range(count):
                out.append('msgstr[%d] "%s"' % (i, escape(entry["msgstr"].get(i, ""))))
        else:
            out.append('msgstr "%s"' % escape(entry["msgstr"].get(0, "")))
        out.append("")
    open(path, "w", encoding="utf-8").write("\n".join(out))


def plural_rule(header):
    """Classify the PO plural rule into a name the QML side understands."""
    forms = header.get("Plural-Forms", "")
    nplurals = 2
    m = re.search(r"nplurals\s*=\s*(\d+)", forms)
    if m:
        nplurals = int(m.group(1))
    if nplurals == 1:
        return "single"
    if nplurals >= 3:
        return "slavic"
    return "gt1" if "n > 1" in forms.replace(" ", " ") else "ne1"


# Number formatting per language, so a chosen language also changes separators
SEPARATORS = {
    "de": (".", ","), "es": (".", ","), "fr": (" ", ","), "it": (".", ","),
    "nl": (".", ","), "pl": (" ", ","), "pt_BR": (".", ","), "ru": (" ", ","),
    "tr": (".", ","), "en": (",", "."), "zh_CN": (",", "."), "ja": (",", "."),
}


def catalog_payload(lang, header, entries):
    """Runtime catalogue for the widget's own language override.

    KLocalizedString always follows the desktop locale, so the widget cannot
    switch languages through it. L10n.qml reads this data instead.
    """
    messages, plurals = {}, {}
    for (ctx, msgid), entry in entries.items():
        key = (ctx + "\u0004" + msgid) if ctx else msgid
        strs = entry["msgstr"]
        if entry["plural"]:
            forms = [strs.get(i, "") for i in sorted(strs)]
            if any(forms):
                plurals[key] = forms
        elif strs.get(0):
            messages[key] = strs[0]

    group, point = SEPARATORS.get(lang, (",", "."))
    payload = {
        "language": lang,
        "pluralRule": plural_rule(header),
        "groupSeparator": group,
        "decimalPoint": point,
        "messages": messages,
        "plurals": plurals,
    }
    return payload


def cmd_build():
    catalogs = {}
    total = 0
    for name in sorted(os.listdir(PO_DIR)):
        if not name.endswith(".po"):
            continue
        lang = name[:-3]
        header, entries = parse_po(os.path.join(PO_DIR, name))
        target = os.path.join(
            PACKAGE, "contents", "locale", lang, "LC_MESSAGES", DOMAIN + ".mo"
        )
        count = write_mo(target, header, entries)
        catalogs[lang] = catalog_payload(lang, header, entries)
        total += 1
        print("%-8s %3d translated -> contents/locale/%s/…" % (lang, count, lang))
    write_catalog_module(catalogs)
    print("built %d catalogues + contents/code/catalogs.js" % total)


def write_catalog_module(catalogs):
    """Emit the JS module L10n.qml imports for the in-widget language switch.

    A static import is the only reliable option: Qt refuses XMLHttpRequest on
    local files inside plasmashell, so the data cannot be loaded at runtime.
    """
    path = os.path.join(PACKAGE, "contents", "code", "catalogs.js")
    body = json.dumps(catalogs, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("/*\n")
        fh.write(" * Generated by translate/i18n.py - do not edit by hand.\n")
        fh.write(" *\n")
        fh.write(" * Holds every shipped translation so the widget can switch language on\n")
        fh.write(" * its own. Plasma resolves i18n() against the desktop locale only.\n")
        fh.write(" *\n")
        fh.write(" * SPDX-License-Identifier: MIT\n")
        fh.write(" */\n")
        fh.write(".pragma library\n\n")
        fh.write("var CATALOGS = %s;\n\n" % body)
        fh.write("function catalog(lang) {\n")
        fh.write("    return Object.prototype.hasOwnProperty.call(CATALOGS, lang)\n")
        fh.write("        ? CATALOGS[lang] : null;\n")
        fh.write("}\n")
        fh.write("\nfunction languages() {\n")
        fh.write("    return Object.keys(CATALOGS).sort();\n")
        fh.write("}\n")


def cmd_stats():
    _, template = parse_po(TEMPLATE) if os.path.exists(TEMPLATE) else ({}, {})
    total = len(template)
    for name in sorted(os.listdir(PO_DIR)):
        if not name.endswith(".po"):
            continue
        _, entries = parse_po(os.path.join(PO_DIR, name))
        done = sum(1 for e in entries.values() if any(e["msgstr"].values()))
        pct = (100.0 * done / total) if total else 0
        print("%-8s %3d/%d  %5.1f%%" % (name[:-3], done, total, pct))


COMMANDS = {
    "extract": cmd_extract,
    "merge": cmd_merge,
    "build": cmd_build,
    "stats": cmd_stats,
}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd not in COMMANDS:
        print(__doc__)
        sys.exit(1)
    COMMANDS[cmd]()
