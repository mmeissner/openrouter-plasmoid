/*
 * Tab 1: credit, spending, key details and favourite model prices.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../code/utils.js" as Utils

PlasmaComponents3.ScrollView {
    id: overview

    required property var api

    readonly property var cfg: Plasmoid.configuration
    readonly property string sym: cfg.currencySymbol

    L10n {
        id: l10n
        language: overview.cfg.language
    }

    readonly property color balanceColor: {
        if (!api.hasBalance) {
            return Kirigami.Theme.textColor;
        }
        if (api.balance <= cfg.criticalThreshold) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (api.balance <= cfg.lowThreshold) {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.positiveTextColor;
    }

    // Join favourite ids with the matching model records
    readonly property var favorites: {
        var ids = Utils.splitList(cfg.favoriteModels);
        var out = [];
        for (var i = 0; i < ids.length; ++i) {
            out.push({ id: ids[i], model: api.modelById(ids[i]) });
        }
        return out;
    }

    contentItem: Flickable {
        id: flick

        contentWidth: width
        contentHeight: column.implicitHeight + Kirigami.Units.largeSpacing
        clip: true

        ColumnLayout {
            id: column

            width: flick.width
            spacing: Kirigami.Units.smallSpacing * 2

            // ----------------------------------------------------------
            // Setup hint while no key is configured
            // ----------------------------------------------------------
            PlasmaExtras.PlaceholderMessage {
                visible: !overview.api.configured
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit
                iconName: "dialog-warning"
                text: l10n.trc("@info:placeholder", "No API key configured")
                explanation: l10n.trc("@info:placeholder",
                    "Enter your OpenRouter key in the settings to see credit and usage.")

                helpfulAction: Kirigami.Action {
                    icon.name: "configure"
                    text: l10n.trc("@action:button", "Open settings")
                    onTriggered: Plasmoid.internalAction("configure").trigger()
                }
            }

            // ----------------------------------------------------------
            // Credit card
            // ----------------------------------------------------------
            Rectangle {
                visible: overview.api.configured
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                implicitHeight: balanceColumn.implicitHeight + Kirigami.Units.largeSpacing
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.alternateBackgroundColor

                ColumnLayout {
                    id: balanceColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Kirigami.Units.smallSpacing * 2
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaExtras.DescriptiveLabel {
                        text: overview.api.creditsValid
                            ? l10n.trc("@label", "Available credit")
                            : l10n.trc("@label", "Remaining key limit")
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        PlasmaComponents3.Label {
                            text: overview.api.hasBalance
                                ? l10n.money(overview.api.balance, overview.cfg.decimals, overview.sym)
                                : "–"
                            color: overview.balanceColor
                            font.weight: Font.Bold
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        PlasmaComponents3.Button {
                            text: l10n.trc("@action:button", "Buy credit")
                            icon.name: "wallet-open"
                            onClicked: Qt.openUrlExternally("https://openrouter.ai/credits")
                        }
                    }

                    MeterBar {
                        Layout.fillWidth: true
                        visible: overview.api.creditsValid && overview.api.totalCredits > 0
                        value: overview.api.usedFraction
                        barColor: overview.balanceColor
                    }

                    PlasmaExtras.DescriptiveLabel {
                        visible: overview.api.creditsValid
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: l10n.trc("@info %1 is the spent amount, %2 the purchased amount, %3 a percentage",
                                    "%1 of %2 spent (%3%)",
                                    l10n.money(overview.api.totalUsage, 2, overview.sym),
                                    l10n.money(overview.api.totalCredits, 2, overview.sym),
                                    Math.round(overview.api.usedFraction * 100))
                    }

                    // Without a management key /credits stays empty - not an error
                    PlasmaExtras.DescriptiveLabel {
                        visible: !overview.api.creditsValid && overview.api.keyValid
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                        text: l10n.trc("@info", "The real account balance needs a management key (Settings → Account).")
                    }
                }
            }

            // ----------------------------------------------------------
            // Spending tiles
            // ----------------------------------------------------------
            GridLayout {
                id: usageGrid

                visible: overview.api.keyValid || overview.api.activityLoaded
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                // Spell out where a number comes from, otherwise a 0.00 for
                // people juggling several keys looks like a bug.
                readonly property string scopeHint: overview.api.accountWide
                    ? l10n.trc("@info:whatsthis data scope", "whole account")
                    : l10n.trc("@info:whatsthis data scope", "this key only")

                StatTile {
                    caption: l10n.trc("@label spending period", "Today")
                    value: l10n.money(overview.api.usageTodayEff, overview.cfg.decimals, overview.sym)
                    hint: overview.api.activityHasToday || overview.api.todayFromCredits
                        ? l10n.trc("@info:whatsthis data scope", "whole account")
                        : l10n.trc("@info:whatsthis data scope", "this key only")
                }
                StatTile {
                    caption: l10n.trc("@label spending period", "This week")
                    value: l10n.money(overview.api.usageWeekEff, overview.cfg.decimals, overview.sym)
                    hint: usageGrid.scopeHint
                }
                StatTile {
                    caption: l10n.trc("@label spending period", "This month")
                    value: l10n.money(overview.api.usageMonthEff, overview.cfg.decimals, overview.sym)
                    hint: usageGrid.scopeHint
                }
                StatTile {
                    caption: l10n.trc("@label spending period", "Spent in total")
                    value: l10n.money(overview.api.usageTotalEff, overview.cfg.decimals, overview.sym)
                    hint: overview.api.creditsValid
                        ? l10n.trc("@info:whatsthis data scope", "whole account")
                        : l10n.trc("@info:whatsthis data scope", "this key only")
                }
            }

            // ----------------------------------------------------------
            // Key details
            // ----------------------------------------------------------
            PlasmaExtras.Heading {
                visible: overview.api.keyValid
                text: l10n.trc("@title:group", "API key")
                level: 5
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            ColumnLayout {
                visible: overview.api.keyValid
                Layout.fillWidth: true
                spacing: 0

                InfoRow {
                    label: l10n.trc("@label", "Name")
                    value: overview.api.keyLabel.length > 0
                        ? overview.api.keyLabel : l10n.trc("@item key without a name", "unnamed")
                }
                InfoRow {
                    label: l10n.trc("@label", "Spending limit")
                    value: overview.api.keyLimit === null
                        ? l10n.trc("@item no spending limit set", "unlimited")
                        : l10n.money(overview.api.keyLimit, 2, overview.sym)
                }
                InfoRow {
                    visible: overview.api.keyLimitRemaining !== null
                    label: l10n.trc("@label", "Left of that")
                    value: l10n.money(overview.api.keyLimitRemaining, 2, overview.sym)
                    emphasized: true
                }
                InfoRow {
                    visible: overview.api.keyLimitReset.length > 0
                    label: l10n.trc("@label", "Limit resets")
                    value: overview.api.keyLimitReset
                }
                InfoRow {
                    label: l10n.trc("@label account tier", "Tier")
                    value: overview.api.freeTier
                        ? l10n.trc("@item account tier", "free tier")
                        : l10n.trc("@item account tier", "paid")
                }
                InfoRow {
                    // OpenRouter marks this field as deprecated and returns -1
                    // when it has nothing meaningful to report
                    visible: overview.api.rateLimit !== null
                        && Number(overview.api.rateLimit.requests) > 0
                    label: l10n.trc("@label", "Rate limit")
                    value: overview.api.rateLimit
                        ? l10n.trc("@item %1 is a request count, %2 an interval such as 10s",
                                "%1 requests / %2",
                                overview.api.rateLimit.requests, overview.api.rateLimit.interval)
                        : ""
                }
                InfoRow {
                    visible: overview.api.byokUsage > 0
                    label: l10n.trc("@label bring-your-own-key usage", "BYOK total")
                    value: l10n.money(overview.api.byokUsage, 2, overview.sym)
                }
            }

            // ----------------------------------------------------------
            // Favourite models with prices
            // ----------------------------------------------------------
            PlasmaExtras.Heading {
                visible: overview.favorites.length > 0
                text: l10n.trc("@title:group %1 is a token unit such as '1M tokens'",
                            "Favourites - price per %1", l10n.unitLabel(overview.cfg.pricingUnit))
                level: 5
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            ColumnLayout {
                visible: overview.favorites.length > 0
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: overview.favorites

                    InfoRow {
                        required property var modelData

                        label: modelData.model ? modelData.model.name : modelData.id
                        value: {
                            if (!modelData.model) {
                                return overview.api.modelsLoaded
                                    ? l10n.trc("@item model id that is not in the catalogue", "unknown") : "…";
                            }
                            var p = modelData.model.pricing || {};
                            return l10n.price(Utils.pricePerUnit(p.prompt, overview.cfg.pricingUnit), overview.sym)
                                + " / "
                                + l10n.price(Utils.pricePerUnit(p.completion, overview.cfg.pricingUnit), overview.sym);
                        }
                    }
                }
            }

            // ----------------------------------------------------------
            // Footer
            // ----------------------------------------------------------
            PlasmaExtras.DescriptiveLabel {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                color: overview.api.errorMessage.length > 0
                    ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
                text: {
                    if (overview.api.errorMessage.length > 0) {
                        return overview.api.errorMessage;
                    }
                    if (overview.api.lastUpdate <= 0) {
                        return l10n.trc("@info:status", "No data fetched yet");
                    }
                    return l10n.trc("@info:status %1 is a relative time such as '5 minutes ago'",
                                 "Updated %1", l10n.ago(tick.now - overview.api.lastUpdate));
                }
            }
        }
    }

    // Keeps the relative timestamp from freezing
    Timer {
        id: tick
        property double now: new Date().getTime()
        interval: 15000
        repeat: true
        running: overview.visible
        triggeredOnStart: true
        onTriggered: now = new Date().getTime()
    }
}
