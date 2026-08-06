/*
 * Settings page "Models": pricing unit, favourites, calculator defaults.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
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

    property alias cfg_favoriteModels: favoritesArea.text
    property alias cfg_hideFreeModels: hideFreeBox.checked
    property alias cfg_calcInputTokens: calcInSpin.value
    property alias cfg_calcOutputTokens: calcOutSpin.value

    property int cfg_pricingUnit: 1000000

    onCfg_pricingUnitChanged: {
        var i = cfg_pricingUnit === 1000 ? 1 : 0;
        if (unitBox.currentIndex !== i) {
            unitBox.currentIndex = i;
        }
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        PlasmaComponents3.ComboBox {
            id: unitBox
            Kirigami.FormData.label: l10n.trc("@label:listbox", "Show prices per:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
            textRole: "label"
            valueRole: "key"
            model: [
                { key: 1000000, label: l10n.trc("@item:inlistbox pricing unit", "1 million tokens") },
                { key: 1000, label: l10n.trc("@item:inlistbox pricing unit", "1000 tokens") }
            ]
            onActivated: page.cfg_pricingUnit = currentValue
            Component.onCompleted: currentIndex = (page.cfg_pricingUnit === 1000 ? 1 : 0)
        }

        PlasmaComponents3.CheckBox {
            id: hideFreeBox
            text: l10n.trc("@option:check", "Hide free models")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: l10n.trc("@title:group", "Cost calculator")
        }

        PlasmaComponents3.SpinBox {
            id: calcInSpin
            Kirigami.FormData.label: l10n.trc("@label:spinbox", "Input tokens:")
            from: 0
            to: 100000000
            stepSize: 50000
            editable: true
        }

        PlasmaComponents3.SpinBox {
            id: calcOutSpin
            Kirigami.FormData.label: l10n.trc("@label:spinbox", "Output tokens:")
            from: 0
            to: 100000000
            stepSize: 50000
            editable: true
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: l10n.trc("@title:group", "Favourites")
        }

        PlasmaComponents3.TextArea {
            id: favoritesArea
            Kirigami.FormData.label: l10n.trc("@label:textbox", "Model ids:")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
            Layout.minimumHeight: Kirigami.Units.gridUnit * 6
            wrapMode: TextEdit.Wrap
            placeholderText: "anthropic/claude-sonnet-4.5, openai/gpt-4o-mini"
        }

        PlasmaComponents3.Label {
            text: l10n.trc("@info",
                "Separated by commas or line breaks. The star in the widget's model\nlist is the more convenient way.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
