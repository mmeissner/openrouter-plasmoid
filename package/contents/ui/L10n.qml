/*
 * Every translatable helper, plus the widget's own language override.
 *
 * Two reasons this exists:
 *
 *  - utils.js cannot call i18n(): it is a `.pragma library` and therefore has
 *    no QML context. All wording lives here instead.
 *  - Plasma resolves i18n() against the desktop locale, which cannot be
 *    changed per widget. When the user picks a language in the settings, the
 *    wrappers below look the message up in code/catalogs.js and only fall back
 *    to i18n() for the system default. That module is imported statically
 *    because Qt refuses XMLHttpRequest on local files inside plasmashell.
 *
 * Call sites therefore use l10n.tr / trc / trp / trcp rather than the global
 * i18n functions. The extractor in translate/i18n.py knows both spellings.
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick

import "../code/utils.js" as Utils
import "../code/catalogs.js" as Catalogs

QtObject {
    id: l10n

    /* Empty string means "follow the Plasma locale". */
    property string language: ""

    /*
     * Reading this inside every wrapper is deliberate: QML then records it as a
     * binding dependency, so switching the language re-evaluates every string
     * in the interface without a restart.
     */
    readonly property var catalog: language.length > 0 ? Catalogs.catalog(language) : null

    /*
     * The source strings are already English, so no catalogue is shipped for
     * it. Without this, picking English would find nothing and fall back to
     * KI18n - which serves the desktop locale and thus the wrong language.
     */
    readonly property string sourceLanguage: "en"
    readonly property bool useSource: language === sourceLanguage

    readonly property string effectiveLanguage: language.length > 0
        ? language : String(Qt.locale().name).split("_")[0]

    // Number separators follow the chosen language, falling back to the locale
    readonly property string groupSeparator: useSource ? ","
        : (catalog && catalog.groupSeparator ? catalog.groupSeparator : Qt.locale().groupSeparator)
    readonly property string decimalPoint: useSource ? "."
        : (catalog && catalog.decimalPoint ? catalog.decimalPoint : Qt.locale().decimalPoint)

    // ------------------------------------------------------------------
    // Translation wrappers
    // ------------------------------------------------------------------
    /*
     * The KI18n fallbacks are handed every wrapper argument so KLocalizedContext
     * can substitute %1…%9 itself. Calling i18n/i18nc without the trailing
     * values converted the message with unfilled placeholders, and KI18n then
     * rendered "(I18N_ARGUMENT_MISSING)" wherever "System language" was picked.
     */
    function tr(msgid) {
        var text = useSource
            ? msgid
            : (lookup(null, msgid, null, 1)
                || i18n.apply(null, Array.prototype.slice.call(arguments)));
        return format(text, arguments, 1);
    }

    function trc(context, msgid) {
        var text = useSource
            ? msgid
            : (lookup(context, msgid, null, 1)
                || i18nc.apply(null, Array.prototype.slice.call(arguments)));
        return format(text, arguments, 2);
    }

    function trp(singular, plural, n) {
        var text = useSource
            ? (Number(n) === 1 ? singular : plural)
            : (lookup(null, singular, plural, n)
                || i18np.apply(null, Array.prototype.slice.call(arguments)));
        return format(text, arguments, 2);
    }

    function trcp(context, singular, plural, n) {
        var text = useSource
            ? (Number(n) === 1 ? singular : plural)
            : (lookup(context, singular, plural, n)
                || i18ncp.apply(null, Array.prototype.slice.call(arguments)));
        return format(text, arguments, 3);
    }

    /* Replace %1…%9 with the trailing arguments, like KLocalizedString does. */
    function format(text, args, offset) {
        var out = String(text);
        for (var i = offset; i < args.length; ++i) {
            out = out.split("%" + (i - offset + 1)).join(String(args[i]));
        }
        return out;
    }

    /* gettext joins context and message id with EOT, same as msgctxt does. */
    readonly property string contextGlue: "\u0004"

    /* Catalogue lookup; returns null so callers can fall back to KI18n. */
    function lookup(context, msgid, plural, n) {
        var cat = catalog;
        if (!cat) {
            return null;
        }
        var key = context ? context + contextGlue + msgid : msgid;
        if (plural !== null && plural !== undefined) {
            var forms = cat.plurals ? cat.plurals[key] : undefined;
            if (!forms) {
                return null;
            }
            var idx = pluralIndex(cat.pluralRule, Number(n));
            return forms[Math.min(idx, forms.length - 1)] || null;
        }
        var hit = cat.messages ? cat.messages[key] : undefined;
        return hit ? hit : null;
    }

    /*
     * Plural selection. The rule name is written into the catalogue by
     * translate/i18n.py, derived from the PO header, so no expression has to be
     * evaluated at runtime.
     */
    function pluralIndex(rule, n) {
        switch (rule) {
        case "single":
            return 0;
        case "gt1":
            return n > 1 ? 1 : 0;
        case "slavic":
            if (n % 10 === 1 && n % 100 !== 11) {
                return 0;
            }
            if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
                return 1;
            }
            return 2;
        default:
            return n !== 1 ? 1 : 0;
        }
    }

    /* Languages the widget ships, for the settings drop-down. */
    function availableLanguages() {
        return [
            { code: "", label: trc("@item:inlistbox", "System language") },
            { code: "en", label: "English" },
            { code: "de", label: "Deutsch" },
            { code: "es", label: "Español" },
            { code: "fr", label: "Français" },
            { code: "it", label: "Italiano" },
            { code: "nl", label: "Nederlands" },
            { code: "pl", label: "Polski" },
            { code: "pt_BR", label: "Português (BR)" },
            { code: "ru", label: "Русский" },
            { code: "tr", label: "Türkçe" },
            { code: "zh_CN", label: "中文 (简体)" },
            { code: "ja", label: "日本語" }
        ];
    }

    // ------------------------------------------------------------------
    // Formatting helpers
    // ------------------------------------------------------------------
    function money(value, decimals, symbol) {
        return Utils.money(value, decimals, symbol, groupSeparator, decimalPoint);
    }

    function count(value) {
        return Utils.group(Math.round(Utils.num(value)), groupSeparator);
    }

    /* Formatted price, or the word for "no charge" when the model is free */
    function price(value, symbol) {
        var text = Utils.price(value, symbol, groupSeparator, decimalPoint);
        return text === null ? trc("@item price of a free model", "free") : text;
    }

    function unitLabel(unit) {
        return unit >= 1000000
            ? trc("@label token pricing unit", "1M tokens")
            : trc("@label token pricing unit", "1K tokens");
    }

    /*
     * Every metric the panel can display. Shared by the panel itself and the
     * appearance settings page so both lists can never drift apart.
     */
    function metricDefs() {
        return [
            {
                key: "balance",
                label: trc("@item:inlistbox panel metric", "Available credit"),
                short: trc("@label very short panel caption for available credit", "Free"),
                money: true
            },
            {
                key: "limit",
                label: trc("@item:inlistbox panel metric", "Remaining key limit"),
                short: trc("@label very short panel caption for the key limit", "Limit"),
                money: true
            },
            {
                key: "today",
                label: trc("@item:inlistbox panel metric", "Spent today"),
                short: trc("@label very short panel caption for today", "Today"),
                money: true
            },
            {
                key: "week",
                label: trc("@item:inlistbox panel metric", "Spent this week"),
                short: trc("@label very short panel caption for this week", "Week"),
                money: true
            },
            {
                key: "month",
                label: trc("@item:inlistbox panel metric", "Spent this month"),
                short: trc("@label very short panel caption for this month", "Month"),
                money: true
            },
            {
                key: "total",
                label: trc("@item:inlistbox panel metric", "Spent in total"),
                short: trc("@label very short panel caption for the total", "Total"),
                money: true
            },
            {
                key: "credits",
                label: trc("@item:inlistbox panel metric", "Credit purchased"),
                short: trc("@label very short panel caption for purchased credit", "Bought"),
                money: true
            },
            {
                key: "requests",
                label: trc("@item:inlistbox panel metric", "Requests (30 days)"),
                short: trc("@label very short panel caption for the request count", "Req."),
                money: false
            }
        ];
    }

    function metricDef(key) {
        var defs = metricDefs();
        for (var i = 0; i < defs.length; ++i) {
            if (defs[i].key === key) {
                return defs[i];
            }
        }
        return null;
    }

    /* Turn an HTTP status into something a user can act on */
    function errorText(status, message) {
        if (status === 0) {
            return tr("Cannot reach openrouter.ai");
        }
        if (status === 401) {
            return tr("API key is missing or invalid");
        }
        if (status === 403) {
            return message && message.length > 0
                ? message
                : tr("Access denied - this endpoint needs a management key");
        }
        if (status === 404) {
            return tr("Endpoint not found");
        }
        if (status === 429) {
            return tr("Rate limit reached - try again later");
        }
        if (status >= 500) {
            return tr("OpenRouter reported a server error (%1)", status);
        }
        return message && message.length > 0
            ? tr("Error %1: %2", status, message)
            : tr("Error %1", status);
    }

    /* Relative time for the "last updated" line */
    function ago(msDiff) {
        var s = Math.max(0, Math.round(msDiff / 1000));
        if (s < 10) {
            return tr("just now");
        }
        if (s < 60) {
            return trp("%1 second ago", "%1 seconds ago", s);
        }
        var m = Math.round(s / 60);
        if (m < 60) {
            return trp("%1 minute ago", "%1 minutes ago", m);
        }
        var h = Math.round(m / 60);
        if (h < 24) {
            return trp("%1 hour ago", "%1 hours ago", h);
        }
        return trp("%1 day ago", "%1 days ago", Math.round(h / 24));
    }

    /* "2026-08-06" -> short date in the active locale */
    function shortDate(iso) {
        var parts = String(iso).split("-");
        if (parts.length < 3) {
            return iso;
        }
        var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return d.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }
}
