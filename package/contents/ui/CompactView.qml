/*
 * Panel representation: the icon plus any number of freely chosen metrics.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import "../code/utils.js" as Utils

MouseArea {
    id: compact

    required property var api
    required property var plasmoidItem

    readonly property var cfg: Plasmoid.configuration
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Stack as soon as the panel is vertical, or when the user asks for it
    readonly property bool stacked: vertical || cfg.compactStacked

    // 0 keeps the theme's own font, any other value is a pixel size
    readonly property bool customFont: cfg.fontSize > 0

    /*
     * The base font with the configured pixel size applied. The family is kept
     * from the theme so only the size moves.
     */
    function sizedFont(base) {
        if (!customFont) {
            return base;
        }
        var f = Qt.font({ pixelSize: cfg.fontSize });
        f.family = base.family;
        return f;
    }

    /* A configured part colour wins, otherwise the fallback applies. */
    function pickColor(custom, fallback) {
        return String(custom).length > 0 ? custom : fallback;
    }

    L10n {
        id: l10n
        language: compact.cfg.language
    }

    // ------------------------------------------------------------------
    // Raw value per metric
    // ------------------------------------------------------------------
    function metricValue(key) {
        switch (key) {
        case "limit":
            return (api.keyLimitRemaining !== null && api.keyLimitRemaining !== undefined)
                ? Number(api.keyLimitRemaining) : Number.NaN;
        case "today":
            return (api.keyValid || api.activityLoaded) ? api.usageTodayEff : Number.NaN;
        case "week":
            return (api.keyValid || api.activityLoaded) ? api.usageWeekEff : Number.NaN;
        case "month":
            return (api.keyValid || api.activityLoaded) ? api.usageMonthEff : Number.NaN;
        case "total":
            return (api.creditsValid || api.keyValid) ? api.usageTotalEff : Number.NaN;
        case "credits":
            return api.creditsValid ? api.totalCredits : Number.NaN;
        case "requests":
            return api.activityLoaded ? api.activityRequests : Number.NaN;
        default:
            return api.hasBalance ? api.balance : Number.NaN;
        }
    }

    // "less is bad" only applies to remaining amounts
    function metricColor(key, value) {
        if (!cfg.colorize || !isFinite(value) || (key !== "balance" && key !== "limit")) {
            return Kirigami.Theme.textColor;
        }
        if (value <= cfg.criticalThreshold) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (value <= cfg.lowThreshold) {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.positiveTextColor;
    }

    /*
     * Display-ready entries. Unknown values stay as an en dash so the panel
     * width does not jump around while requests are in flight.
     */
    readonly property var entries: {
        var keys = Utils.splitList(cfg.compactItems);
        var out = [];
        for (var i = 0; i < keys.length; ++i) {
            var def = l10n.metricDef(keys[i]);
            if (def === null) {
                continue;
            }
            var v = metricValue(def.key);
            var text;
            if (!api.configured) {
                text = "–";
            } else if (!isFinite(v)) {
                text = api.busy ? "…" : "–";
            } else if (def.money) {
                text = l10n.money(v, cfg.decimals, cfg.currencySymbol);
            } else {
                text = l10n.count(v);
            }
            out.push({
                key: def.key,
                caption: def.short,
                text: text,
                color: String(metricColor(def.key, v))
            });
        }
        return out;
    }

    // ------------------------------------------------------------------
    // Layout
    // ------------------------------------------------------------------
    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : content.implicitWidth
    Layout.preferredWidth: vertical ? -1 : content.implicitWidth
    Layout.maximumWidth: vertical ? Number.POSITIVE_INFINITY : content.implicitWidth
    Layout.minimumHeight: vertical ? content.implicitHeight : Kirigami.Units.iconSizes.small
    Layout.preferredHeight: vertical ? content.implicitHeight : -1

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            api.refreshAll();
        } else {
            plasmoidItem.expanded = !plasmoidItem.expanded;
        }
    }

    GridLayout {
        id: content

        anchors.centerIn: parent
        columns: compact.vertical ? 1 : 2
        rowSpacing: Kirigami.Units.smallSpacing
        columnSpacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            id: statusIcon

            visible: compact.cfg.showIcon

            readonly property bool problem: !compact.api.configured
                || compact.api.errorMessage.length > 0

            // Official OpenRouter mark, tinted to the theme colour; the
            // standard warning icon takes over when something is wrong.
            source: problem
                ? (compact.api.configured ? "dialog-error" : "dialog-warning")
                : Qt.resolvedUrl("../icons/openrouter.svg")
            isMask: !problem
            color: Kirigami.Theme.textColor

            Layout.alignment: Qt.AlignCenter
            implicitWidth: compact.vertical
                ? Math.min(compact.width, Kirigami.Units.iconSizes.smallMedium)
                : Math.min(compact.height, Kirigami.Units.iconSizes.smallMedium)
            implicitHeight: implicitWidth

            // Dim gently while fetching instead of blinking
            opacity: compact.api.busy ? 0.5 : 1.0
            Behavior on opacity {
                NumberAnimation { duration: Kirigami.Units.shortDuration }
            }
        }

        GridLayout {
            id: valueGrid

            visible: compact.entries.length > 0
            Layout.alignment: Qt.AlignCenter
            // 99 columns keeps everything on one line, 1 column stacks it
            columns: compact.stacked ? 1 : 99
            rowSpacing: 0
            columnSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                visible: compact.cfg.compactPrefix.length > 0
                text: compact.cfg.compactPrefix
                color: compact.pickColor(compact.cfg.prefixColor, Kirigami.Theme.textColor)
                font: compact.sizedFont(Kirigami.Theme.smallFont)
                opacity: 0.75
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignCenter
            }

            Repeater {
                model: compact.entries

                /* One cell per metric: separator, caption and value can each
                 * carry their own colour. */
                Row {
                    id: entryRow
                    required property var modelData
                    required property int index

                    spacing: 0
                    Layout.fillWidth: compact.stacked
                    Layout.alignment: compact.stacked
                        ? (Qt.AlignRight | Qt.AlignVCenter) : Qt.AlignCenter
                    Layout.maximumWidth: compact.vertical ? compact.width : implicitWidth

                    PlasmaComponents3.Label {
                        id: separatorLabel

                        visible: entryRow.index > 0 && !compact.stacked
                        text: compact.cfg.compactSeparator + " "
                        color: compact.pickColor(compact.cfg.captionColor, entryRow.modelData.color)
                        font: compact.sizedFont((compact.stacked || compact.entries.length > 2)
                            ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont)
                        verticalAlignment: Text.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        id: captionLabel

                        visible: compact.cfg.compactLabels
                        text: entryRow.modelData.caption + " "
                        color: compact.pickColor(compact.cfg.captionColor, entryRow.modelData.color)
                        font: compact.sizedFont((compact.stacked || compact.entries.length > 2)
                            ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont)
                        verticalAlignment: Text.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        text: entryRow.modelData.text
                        color: compact.pickColor(compact.cfg.valueColor, entryRow.modelData.color)
                        font: compact.sizedFont((compact.stacked || compact.entries.length > 2)
                            ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont)
                        elide: Text.ElideRight
                        horizontalAlignment: compact.stacked ? Text.AlignRight : Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        // Shrink only in a vertical panel, where the width is capped
                        width: compact.vertical
                            ? Math.max(0, Math.min(implicitWidth,
                                compact.width
                                  - (separatorLabel.visible ? separatorLabel.implicitWidth : 0)
                                  - (captionLabel.visible ? captionLabel.implicitWidth : 0)))
                            : implicitWidth
                    }
                }
            }
        }
    }
}
