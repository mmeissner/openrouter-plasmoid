/*
 * Pure helper functions: number crunching and formatting only.
 *
 * Nothing in here may produce user-visible words. This file is a
 * `.pragma library`, so it runs outside any QML context and has no access to
 * i18n(). Every translatable string lives in L10n.qml instead.
 *
 * SPDX-License-Identifier: MIT
 */
.pragma library

function num(v) {
    var n = Number(v);
    return isFinite(n) ? n : 0;
}

/* Group thousands with the given separator: 1234567 -> "1,234,567" */
function group(value, separator) {
    var sep = separator === undefined ? "," : separator;
    return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, sep);
}

/*
 * Format a monetary amount. `sep` and `point` come from the active locale so
 * German users see "$1.234,56" and English ones "$1,234.56".
 */
function money(v, decimals, symbol, sep, point) {
    if (v === null || v === undefined || !isFinite(Number(v))) {
        return "–";
    }
    var d = (decimals === undefined || decimals === null) ? 2 : decimals;
    var negative = Number(v) < 0;
    var parts = Math.abs(Number(v)).toFixed(d).split(".");
    var out = group(parts[0], sep) + (parts.length > 1 ? (point === undefined ? "." : point) + parts[1] : "");
    return (negative ? "-" : "") + (symbol === undefined ? "$" : symbol) + out;
}

/*
 * Model prices span several orders of magnitude, so pick the number of
 * decimals from the magnitude instead of using a fixed width.
 * Returns null for "no price at all" - the caller decides how to word that.
 */
function price(v, symbol, sep, point) {
    var n = Number(v);
    if (!isFinite(n) || n <= 0) {
        return null;
    }
    var d;
    if (n >= 100) {
        d = 1;
    } else if (n >= 1) {
        d = 2;
    } else if (n >= 0.1) {
        d = 3;
    } else {
        d = 4;
    }
    return money(n, d, symbol === undefined ? "$" : symbol, sep, point);
}

/* The API quotes prices per token; scale them to the requested unit. */
function pricePerUnit(rawPerToken, unit) {
    return num(rawPerToken) * num(unit);
}

/* 1048576 -> "1M", 131072 -> "128K" - unit letters are kept language neutral */
function tokens(n) {
    var v = num(n);
    if (v <= 0) {
        return "–";
    }
    if (v >= 1000000) {
        var m = v / 1000000;
        return (m >= 10 ? Math.round(m) : Math.round(m * 10) / 10) + "M";
    }
    if (v >= 1000) {
        return Math.round(v / 1000) + "K";
    }
    return String(v);
}

/* Cost of a hypothetical request with the given token counts */
function estimate(pricing, inTokens, outTokens) {
    return num(pricing ? pricing.prompt : 0) * num(inTokens)
         + num(pricing ? pricing.completion : 0) * num(outTokens);
}

function isFree(model) {
    if (!model || !model.pricing) {
        return false;
    }
    return num(model.pricing.prompt) === 0 && num(model.pricing.completion) === 0;
}

/* "anthropic/claude-sonnet-4.5" -> "anthropic" */
function vendor(id) {
    var s = String(id || "");
    var i = s.indexOf("/");
    return i > 0 ? s.substring(0, i) : s;
}

function splitList(csv) {
    return String(csv || "")
        .split(/[,\n]/)
        .map(function (s) { return s.trim(); })
        .filter(function (s) { return s.length > 0; });
}

function joinList(arr) {
    return (arr || []).join(",");
}

/* Date -> "YYYY-MM-DD" in UTC, matching how OpenRouter buckets days */
function isoDate(d) {
    var mm = d.getUTCMonth() + 1;
    var dd = d.getUTCDate();
    return d.getUTCFullYear() + "-" + (mm < 10 ? "0" + mm : mm)
         + "-" + (dd < 10 ? "0" + dd : dd);
}
