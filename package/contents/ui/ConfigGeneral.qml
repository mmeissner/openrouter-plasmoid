/*
 * Settings page "Account": keys, refresh interval, warning thresholds.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs as QtDialogs

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Declared so this page can honour the language override too
    property string cfg_language: ""

    L10n {
        id: l10n
        language: page.cfg_language
    }

    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_apiKeyFile: apiKeyFileField.text
    property alias cfg_managementKey: mgmtKeyField.text
    property alias cfg_managementKeyFile: mgmtKeyFileField.text
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_refreshOnOpen: refreshOnOpenBox.checked
    property alias cfg_notifyLow: notifyBox.checked

    // Fractional amounts run through cent values in the spin boxes, so they
    // have to be coupled by hand rather than by a plain alias.
    property double cfg_lowThreshold: 5.0
    property double cfg_criticalThreshold: 1.0

    onCfg_lowThresholdChanged: {
        var v = Math.round(cfg_lowThreshold * 100);
        if (lowSpin.value !== v) {
            lowSpin.value = v;
        }
    }
    onCfg_criticalThresholdChanged: {
        var v = Math.round(cfg_criticalThreshold * 100);
        if (criticalSpin.value !== v) {
            criticalSpin.value = v;
        }
    }

    property string testResult: ""
    property bool testOk: false

    /* Self-contained probe - the settings page has no access to the widget. */
    function testConnection() {
        var key = apiKeyField.text.trim();
        if (key.length === 0 && apiKeyFileField.text.trim().length === 0) {
            page.testOk = false;
            page.testResult = l10n.trc("@info:status", "Enter an API key first.");
            return;
        }
        page.testResult = l10n.trc("@info:status", "Checking…");
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            var body = null;
            try {
                body = JSON.parse(xhr.responseText);
            } catch (e) {
                body = null;
            }
            if (xhr.status === 200 && body && body.data) {
                page.testOk = true;
                page.testResult = l10n.trc("@info:status %1 is the key name, %2 an amount",
                                        "Connected - key “%1”, %2 spent so far.",
                                        body.data.label ? body.data.label
                                                        : l10n.trc("@item key without a name", "unnamed"),
                                        "$" + Number(body.data.usage || 0).toFixed(2));
            } else {
                page.testOk = false;
                var msg = (body && body.error && body.error.message) ? body.error.message : "";
                page.testResult = xhr.status === 0
                    ? l10n.trc("@info:status", "Cannot reach openrouter.ai")
                    : (msg.length > 0
                        ? l10n.trc("@info:status %1 is an HTTP status, %2 the server message",
                                "Error %1: %2", xhr.status, msg)
                        : l10n.trc("@info:status %1 is an HTTP status", "Error %1", xhr.status));
            }
        };
        xhr.open("GET", "https://openrouter.ai/api/v1/key");
        xhr.setRequestHeader("Authorization", "Bearer " + key);
        xhr.send();
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: l10n.trc("@title:group", "Credentials")
        }

        PlasmaExtras.PasswordField {
            id: apiKeyField
            Kirigami.FormData.label: l10n.trc("@label:textbox", "API key:")
            placeholderText: "sk-or-v1-…"
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }

        RowLayout {
            Kirigami.FormData.label: l10n.trc("@label:textbox", "…or from a file:")

            PlasmaComponents3.TextField {
                id: apiKeyFileField
                placeholderText: "~/.config/openrouter/apikey"
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            }

            PlasmaComponents3.Button {
                icon.name: "document-open"
                onClicked: keyFileDialog.open()
            }
        }

        PlasmaComponents3.Label {
            text: l10n.trc("@info",
                "A file takes precedence over the typed key and keeps it out of the\nPlasma configuration file. Recommended: chmod 600.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        PlasmaExtras.PasswordField {
            id: mgmtKeyField
            Kirigami.FormData.label: l10n.trc("@label:textbox", "Management key:")
            placeholderText: l10n.trc("@info:placeholder", "optional - for balance and history")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }

        RowLayout {
            Kirigami.FormData.label: l10n.trc("@label:textbox", "…or from a file:")

            PlasmaComponents3.TextField {
                id: mgmtKeyFileField
                placeholderText: "~/.config/openrouter/mgmtkey"
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 16
            }

            PlasmaComponents3.Button {
                icon.name: "document-open"
                onClicked: mgmtFileDialog.open()
            }
        }

        PlasmaComponents3.Label {
            text: l10n.trc("@info",
                "Create management keys at openrouter.ai/settings/provisioning-keys.\nSome accounts need one for /credits (balance) and /activity (history).")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        RowLayout {
            PlasmaComponents3.Button {
                text: l10n.trc("@action:button", "Test connection")
                icon.name: "network-connect"
                onClicked: page.testConnection()
            }

            PlasmaComponents3.Label {
                text: page.testResult
                visible: text.length > 0
                wrapMode: Text.WordWrap
                color: page.testOk ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: l10n.trc("@title:group", "Refreshing")
        }

        PlasmaComponents3.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: l10n.trc("@label:spinbox", "Interval:")
            from: 30
            to: 3600
            stepSize: 30
            textFromValue: function (value, locale) {
                return value < 60
                    ? l10n.trcp("@item:valuesuffix", "%1 second", "%1 seconds", value)
                    : l10n.trcp("@item:valuesuffix", "%1 minute", "%1 minutes", Math.round(value / 60));
            }
            valueFromText: function (text, locale) {
                var n = parseInt(String(text).replace(/[^0-9]/g, ""), 10);
                if (isNaN(n)) {
                    return 300;
                }
                // A bare number small enough to be minutes is read as minutes
                return n <= 60 ? n * 60 : n;
            }
        }

        PlasmaComponents3.CheckBox {
            id: refreshOnOpenBox
            text: l10n.trc("@option:check", "Refresh when the popup opens")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: l10n.trc("@title:group", "Warning thresholds")
        }

        PlasmaComponents3.SpinBox {
            id: lowSpin
            Kirigami.FormData.label: l10n.trc("@label:spinbox", "Warn below:")
            from: 0
            to: 1000000
            stepSize: 50
            value: 500
            textFromValue: function (value, locale) {
                return "$ " + (value / 100).toFixed(2);
            }
            valueFromText: function (text, locale) {
                var n = parseFloat(String(text).replace(/[^0-9.,]/g, "").replace(",", "."));
                return isNaN(n) ? 0 : Math.round(n * 100);
            }
            onValueModified: page.cfg_lowThreshold = value / 100
        }

        PlasmaComponents3.SpinBox {
            id: criticalSpin
            Kirigami.FormData.label: l10n.trc("@label:spinbox", "Critical below:")
            from: 0
            to: 1000000
            stepSize: 25
            value: 100
            textFromValue: function (value, locale) {
                return "$ " + (value / 100).toFixed(2);
            }
            valueFromText: function (text, locale) {
                var n = parseFloat(String(text).replace(/[^0-9.,]/g, "").replace(",", "."));
                return isNaN(n) ? 0 : Math.round(n * 100);
            }
            onValueModified: page.cfg_criticalThreshold = value / 100
        }

        PlasmaComponents3.CheckBox {
            id: notifyBox
            text: l10n.trc("@option:check", "Notify when credit drops below the warning threshold")
        }
    }

    QtDialogs.FileDialog {
        id: keyFileDialog
        title: l10n.trc("@title:window", "Choose the file holding the API key")
        onAccepted: apiKeyFileField.text = String(selectedFile).replace("file://", "")
    }

    QtDialogs.FileDialog {
        id: mgmtFileDialog
        title: l10n.trc("@title:window", "Choose the file holding the management key")
        onAccepted: mgmtKeyFileField.text = String(selectedFile).replace("file://", "")
    }
}
