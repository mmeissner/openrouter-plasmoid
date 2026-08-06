/*
 * Popup: heading with actions plus three tabs.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: full

    required property var api
    required property var plasmoidItem

    readonly property var cfg: Plasmoid.configuration

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 20
    Layout.preferredWidth: Kirigami.Units.gridUnit * 28
    Layout.preferredHeight: Kirigami.Units.gridUnit * 30

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../icons/openrouter.svg")
                    isMask: true
                    color: Kirigami.Theme.textColor
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaExtras.Heading {
                    text: "OpenRouter"
                    level: 4
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                PlasmaComponents3.BusyIndicator {
                    running: full.api.busy
                    visible: running
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18nc("@action:button", "Refresh")
                    onClicked: full.api.refreshAll()

                    PlasmaComponents3.ToolTip {
                        text: parent.text
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "internet-services"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18nc("@action:button", "Open on openrouter.ai")
                    onClicked: Qt.openUrlExternally("https://openrouter.ai/activity")

                    PlasmaComponents3.ToolTip {
                        text: parent.text
                    }
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "configure"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18nc("@action:button", "Configure")
                    onClicked: Plasmoid.internalAction("configure").trigger()

                    PlasmaComponents3.ToolTip {
                        text: parent.text
                    }
                }
            }

            PlasmaComponents3.TabBar {
                id: tabBar

                Layout.fillWidth: true
                position: PlasmaComponents3.TabBar.Header

                PlasmaComponents3.TabButton {
                    icon.name: "wallet-open"
                    text: i18nc("@title:tab", "Overview")
                }
                PlasmaComponents3.TabButton {
                    icon.name: "view-list-details"
                    text: i18nc("@title:tab", "Models")
                }
                PlasmaComponents3.TabButton {
                    icon.name: "office-chart-bar"
                    text: i18nc("@title:tab", "History")
                }
            }
        }
    }

    contentItem: StackLayout {
        currentIndex: tabBar.currentIndex

        OverviewTab {
            api: full.api
        }

        ModelsTab {
            api: full.api
        }

        ActivityTab {
            api: full.api
        }
    }
}
