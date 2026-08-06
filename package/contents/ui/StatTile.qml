/*
 * Tile for a single metric: big value, small caption.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Rectangle {
    id: tile

    property string caption: ""
    property string value: "–"
    property string hint: ""
    property color valueColor: Kirigami.Theme.textColor

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + Kirigami.Units.smallSpacing * 3

    radius: Kirigami.Units.cornerRadius
    color: Kirigami.Theme.alternateBackgroundColor

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
        anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
        spacing: 0

        PlasmaExtras.DescriptiveLabel {
            text: tile.caption
            font: Kirigami.Theme.smallFont
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        PlasmaComponents3.Label {
            text: tile.value
            color: tile.valueColor
            font.weight: Font.Bold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        PlasmaExtras.DescriptiveLabel {
            text: tile.hint
            visible: tile.hint.length > 0
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
