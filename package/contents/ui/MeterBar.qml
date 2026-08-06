/*
 * Thin progress bar with a freely chosen colour.
 * SPDX-License-Identifier: MIT
 */
import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: meter

    /* Fill level, 0..1 */
    property real value: 0
    property color barColor: Kirigami.Theme.highlightColor

    readonly property real clamped: Math.max(0, Math.min(1, isFinite(value) ? value : 0))

    implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.45)
    implicitWidth: Kirigami.Units.gridUnit * 10

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Kirigami.Theme.textColor
        opacity: 0.15
    }

    Rectangle {
        height: parent.height
        width: Math.max(meter.clamped > 0 ? height : 0, parent.width * meter.clamped)
        radius: height / 2
        color: meter.barColor

        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
