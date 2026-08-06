/*
 * Every translatable helper lives here.
 *
 * utils.js cannot call i18n() because it is a `.pragma library` without a QML
 * context, so all wording is produced by this object. It is cheap and stateless
 * - instantiate one wherever you need it rather than sharing a singleton.
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick

import "../code/utils.js" as Utils

QtObject {
    id: l10n

    // Number separators follow the user's locale, not the source language
    readonly property string groupSeparator: Qt.locale().groupSeparator
    readonly property string decimalPoint: Qt.locale().decimalPoint

    function money(value, decimals, symbol) {
        return Utils.money(value, decimals, symbol, groupSeparator, decimalPoint);
    }

    function count(value) {
        return Utils.group(Math.round(Utils.num(value)), groupSeparator);
    }

    /* Formatted price, or the word for "no charge" when the model is free */
    function price(value, symbol) {
        var text = Utils.price(value, symbol, groupSeparator, decimalPoint);
        return text === null ? i18nc("@item price of a free model", "free") : text;
    }

    function unitLabel(unit) {
        return unit >= 1000000
            ? i18nc("@label token pricing unit", "1M tokens")
            : i18nc("@label token pricing unit", "1K tokens");
    }

    /*
     * Every metric the panel can display. Shared by the panel itself and the
     * appearance settings page so both lists can never drift apart.
     */
    function metricDefs() {
        return [
            {
                key: "balance",
                label: i18nc("@item:inlistbox panel metric", "Available credit"),
                short: i18nc("@label very short panel caption for available credit", "Free"),
                money: true
            },
            {
                key: "limit",
                label: i18nc("@item:inlistbox panel metric", "Remaining key limit"),
                short: i18nc("@label very short panel caption for the key limit", "Limit"),
                money: true
            },
            {
                key: "today",
                label: i18nc("@item:inlistbox panel metric", "Spent today"),
                short: i18nc("@label very short panel caption for today", "Today"),
                money: true
            },
            {
                key: "week",
                label: i18nc("@item:inlistbox panel metric", "Spent this week"),
                short: i18nc("@label very short panel caption for this week", "Week"),
                money: true
            },
            {
                key: "month",
                label: i18nc("@item:inlistbox panel metric", "Spent this month"),
                short: i18nc("@label very short panel caption for this month", "Month"),
                money: true
            },
            {
                key: "total",
                label: i18nc("@item:inlistbox panel metric", "Spent in total"),
                short: i18nc("@label very short panel caption for the total", "Total"),
                money: true
            },
            {
                key: "credits",
                label: i18nc("@item:inlistbox panel metric", "Credit purchased"),
                short: i18nc("@label very short panel caption for purchased credit", "Bought"),
                money: true
            },
            {
                key: "requests",
                label: i18nc("@item:inlistbox panel metric", "Requests (30 days)"),
                short: i18nc("@label very short panel caption for the request count", "Req."),
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
            return i18n("Cannot reach openrouter.ai");
        }
        if (status === 401) {
            return i18n("API key is missing or invalid");
        }
        if (status === 403) {
            return message && message.length > 0
                ? message
                : i18n("Access denied - this endpoint needs a management key");
        }
        if (status === 404) {
            return i18n("Endpoint not found");
        }
        if (status === 429) {
            return i18n("Rate limit reached - try again later");
        }
        if (status >= 500) {
            return i18n("OpenRouter reported a server error (%1)", status);
        }
        return message && message.length > 0
            ? i18n("Error %1: %2", status, message)
            : i18n("Error %1", status);
    }

    /* Relative time for the "last updated" line */
    function ago(msDiff) {
        var s = Math.max(0, Math.round(msDiff / 1000));
        if (s < 10) {
            return i18n("just now");
        }
        if (s < 60) {
            return i18np("%1 second ago", "%1 seconds ago", s);
        }
        var m = Math.round(s / 60);
        if (m < 60) {
            return i18np("%1 minute ago", "%1 minutes ago", m);
        }
        var h = Math.round(m / 60);
        if (h < 24) {
            return i18np("%1 hour ago", "%1 hours ago", h);
        }
        return i18np("%1 day ago", "%1 days ago", Math.round(h / 24));
    }

    /* "2026-08-06" -> short date in the user's locale */
    function shortDate(iso) {
        var parts = String(iso).split("-");
        if (parts.length < 3) {
            return iso;
        }
        var d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return d.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }
}
