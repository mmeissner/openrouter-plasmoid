/*
 * Tab 3: 30 day spending history plus a per-model breakdown.
 * Needs an account that serves /activity for the configured key.
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../code/utils.js" as Utils

Item {
    id: activityTab

    required property var api

    readonly property var cfg: Plasmoid.configuration
    readonly property string sym: cfg.currencySymbol
    readonly property var days: api.activityDays
    readonly property bool available: api.activityLoaded && days.length > 0

    L10n {
        id: l10n
        language: activityTab.cfg.language
    }

    /* Clicking a bar drills into that single day; empty means "all 30 days". */
    property string selectedDate: ""

    readonly property var selectedDay: {
        for (var i = 0; i < days.length; ++i) {
            if (days[i].date === selectedDate) {
                return days[i];
            }
        }
        return null;
    }

    readonly property real maxDay: {
        var max = 0;
        for (var i = 0; i < days.length; ++i) {
            if (days[i].usage > max) {
                max = days[i].usage;
            }
        }
        return max;
    }

    // ------------------------------------------------------------------
    // Hint when the endpoint is unusable
    // ------------------------------------------------------------------
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 3
        visible: !activityTab.available
        iconName: "office-chart-bar"
        text: activityTab.api.activityError.length > 0
            ? l10n.trc("@info:placeholder", "History unavailable")
            : l10n.trc("@info:placeholder", "No data yet")
        explanation: activityTab.api.activityError.length > 0
            ? activityTab.api.activityError + "\n\n"
              + l10n.trc("@info:placeholder",
                      "The 30 day history comes from /activity. If your account requires it, create a management key at openrouter.ai/settings/provisioning-keys and enter it in the settings.")
            : l10n.trc("@info:placeholder", "Requests made through your account will show up here.")

        helpfulAction: Kirigami.Action {
            icon.name: "configure"
            text: l10n.trc("@action:button", "Open settings")
            onTriggered: Plasmoid.internalAction("configure").trigger()
        }
    }

    // ------------------------------------------------------------------
    // History
    // ------------------------------------------------------------------
    PlasmaComponents3.ScrollView {
        anchors.fill: parent
        visible: activityTab.available

        contentItem: Flickable {
            id: flick

            contentWidth: width
            contentHeight: column.implicitHeight + Kirigami.Units.largeSpacing
            clip: true

            ColumnLayout {
                id: column

                width: flick.width
                spacing: Kirigami.Units.smallSpacing

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    columns: 3
                    columnSpacing: Kirigami.Units.smallSpacing

                    StatTile {
                        caption: l10n.trc("@label", "30 days")
                        value: l10n.money(activityTab.api.activityTotal, 2, activityTab.sym)
                    }
                    StatTile {
                        caption: l10n.trc("@label", "Requests")
                        value: l10n.count(activityTab.api.activityRequests)
                    }
                    StatTile {
                        caption: l10n.trc("@label average per day", "Ø per day")
                        value: l10n.money(
                            activityTab.days.length > 0
                                ? activityTab.api.activityTotal / activityTab.days.length : 0,
                            2, activityTab.sym)
                    }
                }

                PlasmaExtras.Heading {
                    text: l10n.trc("@title:group", "Daily spending")
                    level: 5
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                }

                // -- Bar chart --------------------------------------
                Item {
                    id: chart

                    Layout.fillWidth: true
                    implicitHeight: Kirigami.Units.gridUnit * 6

                    readonly property int gap: 2
                    readonly property real barWidth: activityTab.days.length > 0
                        ? Math.max(2, (width - gap * (activityTab.days.length - 1)) / activityTab.days.length)
                        : 0

                    Repeater {
                        model: activityTab.days

                        Item {
                            id: bar

                            required property int index
                            required property var modelData

                            x: index * (chart.barWidth + chart.gap)
                            width: chart.barWidth
                            height: chart.height

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                radius: Math.min(2, width / 2)
                                height: activityTab.maxDay > 0
                                    ? Math.max(bar.modelData.usage > 0 ? 2 : 0,
                                               parent.height * (bar.modelData.usage / activityTab.maxDay))
                                    : 0
                                color: (barMouse.containsMouse
                                        || activityTab.selectedDate === bar.modelData.date)
                                    ? Kirigami.Theme.textColor : Kirigami.Theme.highlightColor
                                opacity: (activityTab.selectedDate.length === 0
                                          || activityTab.selectedDate === bar.modelData.date)
                                    ? 1.0 : 0.45

                                Behavior on height {
                                    NumberAnimation { duration: Kirigami.Units.longDuration }
                                }
                            }

                            MouseArea {
                                id: barMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Click a day to see only that day's models
                                onClicked: activityTab.selectedDate =
                                    (activityTab.selectedDate === bar.modelData.date)
                                        ? "" : bar.modelData.date
                            }

                            PlasmaComponents3.ToolTip {
                                visible: barMouse.containsMouse
                                text: l10n.shortDate(bar.modelData.date) + "  "
                                    + l10n.money(bar.modelData.usage, 4, activityTab.sym) + "\n"
                                    + l10n.trc("@info:tooltip %1 is a request count", "%1 requests",
                                            l10n.count(bar.modelData.requests))
                                    + "  ·  "
                                    + l10n.trc("@info:tooltip %1 is input tokens, %2 output tokens",
                                            "%1 in / %2 out",
                                            Utils.tokens(bar.modelData.prompt),
                                            Utils.tokens(bar.modelData.completion))
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaExtras.DescriptiveLabel {
                        text: activityTab.days.length > 0
                            ? l10n.shortDate(activityTab.days[0].date) : ""
                        font: Kirigami.Theme.smallFont
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    PlasmaExtras.DescriptiveLabel {
                        text: activityTab.days.length > 0
                            ? l10n.shortDate(activityTab.days[activityTab.days.length - 1].date) : ""
                        font: Kirigami.Theme.smallFont
                    }
                }

                // -- Per model --------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    PlasmaExtras.Heading {
                        text: activityTab.selectedDay
                            ? l10n.trc("@title:group %1 is a date, %2 an amount",
                                       "%1 - %2",
                                       l10n.shortDate(activityTab.selectedDay.date),
                                       l10n.money(activityTab.selectedDay.usage, 3, activityTab.sym))
                            : l10n.trc("@title:group", "By model")
                        level: 5
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    PlasmaComponents3.ToolButton {
                        visible: activityTab.selectedDate.length > 0
                        text: l10n.trc("@action:button", "All 30 days")
                        icon.name: "go-previous"
                        onClicked: activityTab.selectedDate = ""
                    }
                }

                PlasmaExtras.DescriptiveLabel {
                    visible: activityTab.selectedDate.length === 0
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                    text: l10n.trc("@info:usagetip", "Click a bar to see that day on its own.")
                }

                Repeater {
                    model: activityTab.selectedDay
                        ? activityTab.selectedDay.models : activityTab.api.activityModels

                    ColumnLayout {
                        id: modelRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        InfoRow {
                            label: modelRow.modelData.model
                            value: l10n.money(modelRow.modelData.usage, 3, activityTab.sym)
                        }

                        MeterBar {
                            Layout.fillWidth: true
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                            implicitHeight: 3
                            value: {
                                var total = activityTab.selectedDay
                                    ? activityTab.selectedDay.usage
                                    : activityTab.api.activityTotal;
                                return total > 0 ? modelRow.modelData.usage / total : 0;
                            }
                        }
                    }
                }
            }
        }
    }
}
