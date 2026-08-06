/*
 * OpenRouter Monitor - a Plasma 6 widget.
 * Shows credit, spending, limits, model pricing and usage history.
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    L10n {
        id: l10n
        language: cfg.language
    }

    // The data object lives in the root so polling continues while the popup
    // (and with it the full representation) is destroyed.
    OpenRouterApi {
        id: orApi

        rawApiKey: cfg.apiKey
        apiKeyFile: cfg.apiKeyFile
        rawManagementKey: cfg.managementKey
        managementKeyFile: cfg.managementKeyFile
        refreshInterval: cfg.refreshInterval
        language: cfg.language

        usageBaseline: cfg.usageBaseline
        usageBaselineDate: cfg.usageBaselineDate

        onBalanceUpdated: value => root.checkLowBalance(value)

        // The data layer has no access to the configuration, so it asks
        onBaselineRequested: (total, date) => {
            cfg.usageBaseline = total;
            cfg.usageBaselineDate = date;
        }
    }

    // ------------------------------------------------------------------
    // Panel state
    // ------------------------------------------------------------------
    Plasmoid.status: {
        if (!orApi.configured || orApi.errorMessage.length > 0) {
            return PlasmaCore.Types.NeedsAttentionStatus;
        }
        if (orApi.hasBalance && orApi.balance <= cfg.criticalThreshold) {
            return PlasmaCore.Types.NeedsAttentionStatus;
        }
        return PlasmaCore.Types.ActiveStatus;
    }

    toolTipMainText: orApi.hasBalance
        ? l10n.trc("@info:tooltip %1 is a formatted amount",
                "OpenRouter - %1 available",
                l10n.money(orApi.balance, cfg.decimals, cfg.currencySymbol))
        : l10n.trc("@info:tooltip", "OpenRouter")

    toolTipSubText: {
        if (!orApi.configured) {
            return l10n.trc("@info:tooltip", "No API key configured.\nRight click → Configure");
        }
        if (orApi.errorMessage.length > 0) {
            return orApi.errorMessage;
        }
        var lines = [];
        if (orApi.keyValid || orApi.activityLoaded) {
            lines.push(l10n.trc("@info:tooltip spending summary, %1/%2/%3 are amounts",
                             "Today: %1   Week: %2   Month: %3",
                             l10n.money(orApi.usageTodayEff, 2, cfg.currencySymbol),
                             l10n.money(orApi.usageWeekEff, 2, cfg.currencySymbol),
                             l10n.money(orApi.usageMonthEff, 2, cfg.currencySymbol)));
        }
        if (orApi.creditsValid) {
            lines.push(l10n.trc("@info:tooltip %1 is purchased credit, %2 is spent credit",
                             "Purchased: %1   Spent: %2",
                             l10n.money(orApi.totalCredits, 2, cfg.currencySymbol),
                             l10n.money(orApi.totalUsage, 2, cfg.currencySymbol)));
        }
        if (orApi.lastUpdate > 0) {
            lines.push(l10n.trc("@info:tooltip %1 is a relative time such as '5 minutes ago'",
                             "Updated %1", l10n.ago(new Date().getTime() - orApi.lastUpdate)));
        }
        return lines.join("\n");
    }

    // ------------------------------------------------------------------
    // Representations
    // ------------------------------------------------------------------
    compactRepresentation: CompactView {
        api: orApi
        plasmoidItem: root
    }

    fullRepresentation: FullView {
        api: orApi
        plasmoidItem: root
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: l10n.trc("@action", "Refresh now")
            icon.name: "view-refresh"
            onTriggered: orApi.refreshAll()
        },
        PlasmaCore.Action {
            text: l10n.trc("@action", "Open activity on openrouter.ai")
            icon.name: "internet-services"
            onTriggered: Qt.openUrlExternally("https://openrouter.ai/activity")
        },
        PlasmaCore.Action {
            text: l10n.trc("@action", "Buy credit")
            icon.name: "wallet-open"
            onTriggered: Qt.openUrlExternally("https://openrouter.ai/credits")
        }
    ]

    // Qualify root.expanded explicitly, otherwise QML treats it as an
    // injected signal parameter and warns about deprecated behaviour
    onExpandedChanged: {
        if (root.expanded && cfg.refreshOnOpen) {
            // One minute of grace is enough - no need to refetch on every open
            if (new Date().getTime() - orApi.lastUpdate > 60000) {
                orApi.refresh();
            }
            if (!orApi.modelsLoaded) {
                orApi.fetchModels();
            }
        }
    }

    // ------------------------------------------------------------------
    // Low balance notification
    // ------------------------------------------------------------------
    property bool lowNotified: false

    function checkLowBalance(value) {
        if (!cfg.notifyLow || !orApi.hasBalance) {
            return;
        }
        if (value <= cfg.lowThreshold && !lowNotified) {
            lowNotified = true;
            lowBalanceNotification.text = l10n.trc("@info:status %1 is a formatted amount",
                                                "Only %1 of OpenRouter credit left.",
                                                l10n.money(value, cfg.decimals, cfg.currencySymbol));
            lowBalanceNotification.sendEvent();
        } else if (value > cfg.lowThreshold * 1.1) {
            // Hysteresis so it cannot flap around the threshold
            lowNotified = false;
        }
    }

    Notification {
        id: lowBalanceNotification
        componentName: "plasma_workspace"
        eventId: "notification"
        title: l10n.trc("@title:window notification", "OpenRouter credit is low")
        iconName: "openrouter"
        urgency: Notification.HighUrgency

        // Clicking the notification goes straight to the top-up page
        defaultAction: NotificationAction {
            label: l10n.trc("@action:button", "Buy credit")
            onActivated: Qt.openUrlExternally("https://openrouter.ai/credits")
        }
    }
}
