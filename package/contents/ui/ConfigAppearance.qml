/*
 * Settings page "Appearance": which metrics the panel shows, and how.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "../code/utils.js" as Utils

KCM.SimpleKCM {
    id: page

    property alias cfg_showIcon: iconBox.checked
    property alias cfg_compactLabels: labelBox.checked
    property alias cfg_compactStacked: stackedBox.checked
    property alias cfg_colorize: colorBox.checked
    property alias cfg_compactPrefix: prefixField.text
    property alias cfg_compactSeparator: separatorField.text
    property alias cfg_currencySymbol: symbolField.text
    property alias cfg_decimals: decimalsSpin.value

    // Multiple choice, stored as a comma separated list
    property string cfg_compactItems: "balance"

    L10n {
        id: l10n
    }

    readonly property var metrics: l10n.metricDefs()

    function isSelected(key) {
        return Utils.splitList(cfg_compactItems).indexOf(key) >= 0;
    }

    /*
     * Panel order follows the order in which entries were ticked, so users can
     * arrange their own bar.
     */
    function setSelected(key, on) {
        var list = Utils.splitList(cfg_compactItems);
        var i = list.indexOf(key);
        if (on && i < 0) {
            list.push(key);
        } else if (!on && i >= 0) {
            list.splice(i, 1);
        }
        cfg_compactItems = Utils.joinList(list);
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Show in the panel")
        }

        Repeater {
            model: page.metrics

            PlasmaComponents3.CheckBox {
                required property var modelData
                required property int index

                Kirigami.FormData.label: index === 0 ? i18nc("@label", "Metrics:") : ""
                text: modelData.label
                checked: page.isSelected(modelData.key)
                onToggled: page.setSelected(modelData.key, checked)
            }
        }

        PlasmaComponents3.Label {
            text: i18nc("@info",
                "Multiple choice - everything ticked appears side by side in the bar.\nWith nothing ticked only the icon is left.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        // Preview of the assembled panel text
        PlasmaComponents3.Label {
            Kirigami.FormData.label: i18nc("@label", "Preview:")
            text: {
                var keys = Utils.splitList(page.cfg_compactItems);
                if (keys.length === 0) {
                    return i18nc("@info nothing but the icon is shown", "(icon only)");
                }
                var parts = [];
                var demo = { balance: 3.5, limit: 8.5, today: 0.42, week: 3.1,
                             month: 12.7, total: 21.5, credits: 25, requests: 1483 };
                for (var i = 0; i < keys.length; ++i) {
                    var def = l10n.metricDef(keys[i]);
                    if (def === null) {
                        continue;
                    }
                    var v = def.money
                        ? l10n.money(demo[def.key], page.cfg_decimals, page.cfg_currencySymbol)
                        : l10n.count(demo[def.key]);
                    parts.push((page.cfg_compactLabels ? def.short + " " : "") + v);
                }
                return parts.join(page.cfg_compactStacked
                    ? "\n" : (" " + page.cfg_compactSeparator + " "));
            }
            font.weight: Font.Bold
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Presentation")
        }

        PlasmaComponents3.CheckBox {
            id: iconBox
            text: i18nc("@option:check", "Show icon")
        }

        PlasmaComponents3.CheckBox {
            id: labelBox
            text: i18nc("@option:check", "Short caption before each value (Today, Month …)")
        }

        PlasmaComponents3.CheckBox {
            id: stackedBox
            text: i18nc("@option:check", "Stack values instead of placing them side by side")
        }

        PlasmaComponents3.CheckBox {
            id: colorBox
            text: i18nc("@option:check", "Colour credit by the warning thresholds")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        PlasmaComponents3.TextField {
            id: prefixField
            Kirigami.FormData.label: i18nc("@label:textbox", "Text in front:")
            placeholderText: i18nc("@info:placeholder example prefix", "e.g. OR")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        }

        PlasmaComponents3.TextField {
            id: separatorField
            Kirigami.FormData.label: i18nc("@label:textbox", "Separator:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 5
        }

        PlasmaComponents3.TextField {
            id: symbolField
            Kirigami.FormData.label: i18nc("@label:textbox", "Currency symbol:")
            Layout.maximumWidth: Kirigami.Units.gridUnit * 5
        }

        PlasmaComponents3.SpinBox {
            id: decimalsSpin
            Kirigami.FormData.label: i18nc("@label:spinbox", "Decimal places:")
            from: 0
            to: 6
        }
    }
}
