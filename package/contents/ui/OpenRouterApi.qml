/*
 * Data layer: wraps every OpenRouter HTTP call and the state derived from it.
 *
 * Instantiated exactly once in main.qml and handed to both representations, so
 * polling keeps running while the popup is closed (and therefore destroyed).
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtCore

import "../code/utils.js" as Utils

Item {
    id: api

    visible: false
    implicitWidth: 0
    implicitHeight: 0

    // ------------------------------------------------------------------
    // Configuration, assigned by main.qml
    // ------------------------------------------------------------------
    property string rawApiKey: ""
    property string apiKeyFile: ""
    property string rawManagementKey: ""
    property string managementKeyFile: ""
    property int refreshInterval: 300

    readonly property string baseUrl: "https://openrouter.ai/api/v1"

    readonly property string homeDir: {
        var u = String(StandardPaths.writableLocation(StandardPaths.HomeLocation));
        return u.indexOf("file://") === 0 ? u.substring(7) : u;
    }

    // A key file wins over a key typed into the settings dialog
    readonly property string inferenceKey: apiKeyFile.length > 0
        ? readKeyFile(apiKeyFile) : rawApiKey.trim()
    readonly property string managementKey: managementKeyFile.length > 0
        ? readKeyFile(managementKeyFile) : rawManagementKey.trim()

    // /credits and /activity officially require a management key, but many
    // accounts serve them for a plain inference key too - so fall back to it.
    readonly property string creditsKey: managementKey.length > 0 ? managementKey : inferenceKey
    readonly property bool configured: inferenceKey.length > 0 || managementKey.length > 0

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    property int pending: 0
    readonly property bool busy: pending > 0
    property string errorMessage: ""
    property double lastUpdate: 0

    // /credits
    property bool creditsValid: false
    property real totalCredits: 0
    property real totalUsage: 0

    // /key
    property bool keyValid: false
    property string keyLabel: ""
    property var keyLimit: null
    property var keyLimitRemaining: null
    property string keyLimitReset: ""
    property real usageAll: 0
    property real usageDaily: 0
    property real usageWeekly: 0
    property real usageMonthly: 0
    property real byokUsage: 0
    property real byokDaily: 0
    property real byokMonthly: 0
    property bool freeTier: true
    property var rateLimit: null

    // /models
    property var models: []
    property bool modelsLoaded: false
    property string modelsError: ""

    // /activity
    property var activityDays: []
    property var activityModels: []
    property real activityTotal: 0
    property int activityRequests: 0
    property string activityError: ""
    property bool activityLoaded: false

    // Account-wide period sums derived from /activity
    property real activityToday: 0
    property real activityWeek: 0
    property real activityMonth: 0
    property bool activityHasToday: false

    // ------------------------------------------------------------------
    // Derived values
    // ------------------------------------------------------------------
    readonly property bool hasData: creditsValid || keyValid

    // Prefer the account balance, fall back to what is left on this key
    readonly property bool hasBalance: creditsValid
        || (keyValid && keyLimitRemaining !== null && keyLimitRemaining !== undefined)
    readonly property real balance: creditsValid
        ? (totalCredits - totalUsage)
        : ((keyLimitRemaining !== null && keyLimitRemaining !== undefined) ? Number(keyLimitRemaining) : 0)

    readonly property real usedFraction: (creditsValid && totalCredits > 0)
        ? Math.min(1, Math.max(0, totalUsage / totalCredits))
        : ((keyValid && keyLimit) ? Math.min(1, Math.max(0, usageAll / Number(keyLimit))) : 0)

    /*
     * /key only counts what THIS key spent - anyone juggling several keys sees
     * zeroes there. /activity is account-wide but stops at the last completed
     * UTC day. So: prefer the account-wide sums and top up today from /key.
     */
    readonly property bool accountWide: activityLoaded
    readonly property real usageTodayEff: activityLoaded
        ? (activityHasToday ? activityToday : usageDaily)
        : usageDaily
    readonly property real usageWeekEff: activityLoaded
        ? activityWeek + (activityHasToday ? 0 : usageDaily)
        : usageWeekly
    readonly property real usageMonthEff: activityLoaded
        ? activityMonth + (activityHasToday ? 0 : usageDaily)
        : usageMonthly
    readonly property real usageTotalEff: creditsValid ? totalUsage : usageAll

    signal balanceUpdated(real value)

    property L10n l10n: L10n {}

    // ------------------------------------------------------------------
    // Public actions
    // ------------------------------------------------------------------
    function refresh() {
        if (!configured) {
            errorMessage = i18n("No API key configured - add one in the settings");
            return;
        }
        errorMessage = "";
        fetchKeyInfo();
        fetchCredits();
        fetchActivity();
    }

    function refreshAll() {
        refresh();
        fetchModels();
    }

    function modelById(id) {
        for (var i = 0; i < models.length; ++i) {
            if (models[i].id === id) {
                return models[i];
            }
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------
    function readKeyFile(path) {
        var p = String(path || "").trim();
        if (p.length === 0) {
            return "";
        }
        if (p.indexOf("~/") === 0) {
            p = api.homeDir + p.substring(1);
        }
        var url = p.indexOf("file://") === 0 ? p : "file://" + p;
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", url, false);
            xhr.send();
            if (xhr.status === 200 || xhr.status === 0) {
                // First non-empty, non-comment line wins
                var lines = String(xhr.responseText || "").split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var l = lines[i].trim();
                    if (l.length > 0 && l.indexOf("#") !== 0) {
                        return l;
                    }
                }
            }
        } catch (e) {
            // Unreadable file is treated the same as "no key"
        }
        return "";
    }

    function request(path, key, onOk, onErr) {
        api.pending = api.pending + 1;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            api.pending = Math.max(0, api.pending - 1);
            var body = null;
            try {
                body = JSON.parse(xhr.responseText);
            } catch (e) {
                body = null;
            }
            if (xhr.status >= 200 && xhr.status < 300 && body !== null) {
                onOk(body);
            } else {
                var msg = (body && body.error && body.error.message) ? body.error.message : "";
                onErr(xhr.status, msg);
            }
        };
        xhr.open("GET", api.baseUrl + path);
        if (key && key.length > 0) {
            xhr.setRequestHeader("Authorization", "Bearer " + key);
        }
        xhr.setRequestHeader("Accept", "application/json");
        xhr.setRequestHeader("HTTP-Referer", "https://github.com/teodorgross/openrouter-plasmoid");
        xhr.setRequestHeader("X-Title", "OpenRouter Plasma Widget");
        xhr.send();
    }

    function stamp() {
        api.lastUpdate = new Date().getTime();
    }

    // ------------------------------------------------------------------
    // Individual endpoints
    // ------------------------------------------------------------------
    function fetchCredits() {
        if (creditsKey.length === 0) {
            return;
        }
        request("/credits", creditsKey, function (body) {
            var d = body.data || {};
            api.totalCredits = Utils.num(d.total_credits);
            api.totalUsage = Utils.num(d.total_usage);
            api.creditsValid = true;
            api.stamp();
            api.balanceUpdated(api.balance);
        }, function (status, msg) {
            api.creditsValid = false;
            // 403 only means "needs a management key" - the /key data stays
            // usable, so this is not a hard error worth shouting about.
            if (status !== 403) {
                api.errorMessage = api.l10n.errorText(status, msg);
            }
        });
    }

    function fetchKeyInfo() {
        if (inferenceKey.length === 0) {
            return;
        }
        request("/key", inferenceKey, function (body) {
            var d = body.data || {};
            api.keyLabel = d.label || "";
            api.keyLimit = (d.limit === null || d.limit === undefined) ? null : Number(d.limit);
            api.keyLimitRemaining = (d.limit_remaining === null || d.limit_remaining === undefined)
                ? null : Number(d.limit_remaining);
            api.keyLimitReset = d.limit_reset || "";
            api.usageAll = Utils.num(d.usage);
            api.usageDaily = Utils.num(d.usage_daily);
            api.usageWeekly = Utils.num(d.usage_weekly);
            api.usageMonthly = Utils.num(d.usage_monthly);
            api.byokUsage = Utils.num(d.byok_usage);
            api.byokDaily = Utils.num(d.byok_usage_daily);
            api.byokMonthly = Utils.num(d.byok_usage_monthly);
            api.freeTier = d.is_free_tier === true;
            api.rateLimit = d.rate_limit || null;
            api.keyValid = true;
            api.errorMessage = "";
            api.stamp();
            api.balanceUpdated(api.balance);
        }, function (status, msg) {
            api.keyValid = false;
            api.errorMessage = api.l10n.errorText(status, msg);
        });
    }

    function fetchModels() {
        // Public endpoint - works without any key at all
        request("/models", "", function (body) {
            var list = body.data || [];
            list.sort(function (a, b) {
                return String(a.name || a.id).localeCompare(String(b.name || b.id));
            });
            api.models = list;
            api.modelsLoaded = true;
            api.modelsError = "";
        }, function (status, msg) {
            api.modelsError = api.l10n.errorText(status, msg);
        });
    }

    function fetchActivity() {
        // Documented as management-key only, but many accounts answer for a
        // plain key - so try, and only show the hint on a real 403.
        if (creditsKey.length === 0) {
            return;
        }
        request("/activity", creditsKey, function (body) {
            api.parseActivity(body.data || []);
            api.activityError = "";
            api.activityLoaded = true;
        }, function (status, msg) {
            api.activityLoaded = false;
            api.activityError = api.l10n.errorText(status, msg);
        });
    }

    /*
     * Activity rows arrive split by day and endpoint. Field names are read
     * defensively so a small API change cannot blank out the whole tab.
     */
    function parseActivity(rows) {
        var byDate = {};
        var byModel = {};
        var total = 0;
        var requests = 0;

        for (var i = 0; i < rows.length; ++i) {
            var r = rows[i];
            var date = String(r.date || r.day || "").substring(0, 10);
            var spend = Utils.num(r.usage) + Utils.num(r.byok_usage_inference);
            var reqs = Utils.num(r.requests);
            var pt = Utils.num(r.prompt_tokens);
            var ct = Utils.num(r.completion_tokens) + Utils.num(r.reasoning_tokens);
            var name = r.model || r.model_permaslug || r.endpoint_id || "?";

            total += spend;
            requests += reqs;

            if (date.length > 0) {
                if (!byDate[date]) {
                    byDate[date] = { date: date, usage: 0, requests: 0, prompt: 0, completion: 0 };
                }
                byDate[date].usage += spend;
                byDate[date].requests += reqs;
                byDate[date].prompt += pt;
                byDate[date].completion += ct;
            }

            if (!byModel[name]) {
                byModel[name] = { model: name, usage: 0, requests: 0, prompt: 0, completion: 0 };
            }
            byModel[name].usage += spend;
            byModel[name].requests += reqs;
            byModel[name].prompt += pt;
            byModel[name].completion += ct;
        }

        var days = [];
        for (var d in byDate) {
            days.push(byDate[d]);
        }
        days.sort(function (a, b) { return a.date < b.date ? -1 : (a.date > b.date ? 1 : 0); });

        var mods = [];
        for (var m in byModel) {
            mods.push(byModel[m]);
        }
        mods.sort(function (a, b) { return b.usage - a.usage; });

        // Period sums in UTC, because that is how OpenRouter cuts its days
        var now = new Date();
        var todayStr = Utils.isoDate(now);
        var monthPrefix = todayStr.substring(0, 7);
        // Week starts on Monday, same as OpenRouter
        var dow = (now.getUTCDay() + 6) % 7;
        var weekStartStr = Utils.isoDate(new Date(Date.UTC(
            now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - dow)));

        var sToday = 0, sWeek = 0, sMonth = 0, hasToday = false;
        for (var k = 0; k < days.length; ++k) {
            var day = days[k];
            if (day.date === todayStr) {
                sToday += day.usage;
                hasToday = true;
            }
            if (day.date >= weekStartStr) {
                sWeek += day.usage;
            }
            if (day.date.indexOf(monthPrefix) === 0) {
                sMonth += day.usage;
            }
        }

        api.activityToday = sToday;
        api.activityWeek = sWeek;
        api.activityMonth = sMonth;
        api.activityHasToday = hasToday;

        api.activityDays = days;
        api.activityModels = mods;
        api.activityTotal = total;
        api.activityRequests = requests;
    }

    // ------------------------------------------------------------------
    // Scheduling
    // ------------------------------------------------------------------
    Timer {
        interval: Math.max(30, api.refreshInterval) * 1000
        repeat: true
        running: api.configured
        triggeredOnStart: false
        onTriggered: api.refresh()
    }

    // The model catalogue rarely changes, so reload it far less often
    Timer {
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: api.fetchModels()
    }

    // Refetch when the keys change, debounced so typing in the settings
    // dialog does not fire a request per keystroke
    Timer {
        id: keyDebounce
        interval: 800
        repeat: false
        onTriggered: {
            api.creditsValid = false;
            api.keyValid = false;
            api.refresh();
        }
    }

    onInferenceKeyChanged: keyDebounce.restart()
    onManagementKeyChanged: keyDebounce.restart()

    Component.onCompleted: {
        fetchModels();
        if (configured) {
            refresh();
        } else {
            errorMessage = i18n("No API key configured - add one in the settings");
        }
    }
}
