/*
 * Label on the left, value on the right - the standard detail row.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

RowLayout {
    id: infoRow

    property string label: ""
    property string value: ""
    property color valueColor: Kirigami.Theme.textColor
    property bool emphasized: false

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    PlasmaExtras.DescriptiveLabel {
        text: infoRow.label
        elide: Text.ElideRight
        Layout.fillWidth: true
    }

    PlasmaComponents3.Label {
        text: infoRow.value
        color: infoRow.valueColor
        font.weight: infoRow.emphasized ? Font.Bold : Font.Normal
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
        // A fixed cap rather than a fraction of the row width: a fraction
        // would depend on the layout result and make the layout recursive.
        Layout.maximumWidth: Kirigami.Units.gridUnit * 14
    }
}
