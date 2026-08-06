/*
 * Tab 2: searchable model catalogue with prices and a cost calculator.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../code/utils.js" as Utils

ColumnLayout {
    id: modelsTab

    required property var api

    readonly property var cfg: Plasmoid.configuration
    readonly property string sym: cfg.currencySymbol
    readonly property int unit: cfg.pricingUnit

    property string expandedId: ""
    property var favoriteIds: Utils.splitList(cfg.favoriteModels)

    // Calculator inputs apply to every model at once so prices stay comparable
    property int calcIn: cfg.calcInputTokens
    property int calcOut: cfg.calcOutputTokens

    spacing: Kirigami.Units.smallSpacing

    L10n {
        id: l10n
        language: modelsTab.cfg.language
    }

    function isFavorite(id) {
        return favoriteIds.indexOf(id) >= 0;
    }

    function toggleFavorite(id) {
        var list = favoriteIds.slice();
        var i = list.indexOf(id);
        if (i >= 0) {
            list.splice(i, 1);
        } else {
            list.push(id);
        }
        cfg.favoriteModels = Utils.joinList(list);
        favoriteIds = list;
    }

    // ------------------------------------------------------------------
    // Filtering and sorting
    // ------------------------------------------------------------------
    readonly property var filtered: {
        var q = searchField.text.toLowerCase().trim();
        var terms = q.length > 0 ? q.split(/\s+/) : [];
        var onlyFavs = favFilter.checked;
        var hideFree = modelsTab.cfg.hideFreeModels;

        var arr = [];
        for (var i = 0; i < api.models.length; ++i) {
            var m = api.models[i];
            var hay = (String(m.id) + " " + String(m.name)).toLowerCase();
            var ok = true;
            for (var t = 0; t < terms.length; ++t) {
                if (hay.indexOf(terms[t]) < 0) {
                    ok = false;
                    break;
                }
            }
            if (!ok) {
                continue;
            }
            if (onlyFavs && !modelsTab.isFavorite(m.id)) {
                continue;
            }
            if (hideFree && Utils.isFree(m)) {
                continue;
            }
            arr.push(m);
        }

        switch (sortBox.currentValue) {
        case "input":
            arr.sort(function (a, b) {
                return Utils.num(a.pricing.prompt) - Utils.num(b.pricing.prompt);
            });
            break;
        case "output":
            arr.sort(function (a, b) {
                return Utils.num(a.pricing.completion) - Utils.num(b.pricing.completion);
            });
            break;
        case "context":
            arr.sort(function (a, b) {
                return Utils.num(b.context_length) - Utils.num(a.context_length);
            });
            break;
        case "new":
            arr.sort(function (a, b) {
                return Utils.num(b.created) - Utils.num(a.created);
            });
            break;
        default:
            arr.sort(function (a, b) {
                return String(a.name || a.id).localeCompare(String(b.name || b.id));
            });
        }
        return arr;
    }

    // ------------------------------------------------------------------
    // Filter bar
    // ------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.SearchField {
            id: searchField
            Layout.fillWidth: true
            placeholderText: l10n.trc("@info:placeholder", "Search models…")
        }

        PlasmaComponents3.ToolButton {
            id: favFilter
            icon.name: "emblem-favorite"
            checkable: true
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: l10n.trc("@action:button", "Favourites only")

            PlasmaComponents3.ToolTip {
                text: parent.text
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.ComboBox {
            id: sortBox
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "key"
            model: [
                { key: "name", label: l10n.trc("@item:inlistbox sort order", "By name") },
                { key: "input", label: l10n.trc("@item:inlistbox sort order", "Cheapest input") },
                { key: "output", label: l10n.trc("@item:inlistbox sort order", "Cheapest output") },
                { key: "context", label: l10n.trc("@item:inlistbox sort order", "Largest context") },
                { key: "new", label: l10n.trc("@item:inlistbox sort order", "Newest first") }
            ]
            currentIndex: {
                var keys = ["name", "input", "output", "context", "new"];
                var i = keys.indexOf(modelsTab.cfg.modelsSort);
                return i < 0 ? 0 : i;
            }
            onActivated: modelsTab.cfg.modelsSort = currentValue
        }

        PlasmaComponents3.Label {
            text: l10n.trc("@info:status %1 is the filtered count, %2 the total count",
                        "%1 / %2", modelsTab.filtered.length, modelsTab.api.models.length)
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
        }
    }

    // ------------------------------------------------------------------
    // List
    // ------------------------------------------------------------------
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Sits above the list so it does not scroll away
        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: listView.count === 0
            iconName: modelsTab.api.modelsLoaded ? "view-filter" : "download"
            text: modelsTab.api.modelsLoaded
                ? l10n.trc("@info:placeholder", "No model matches")
                : l10n.trc("@info:placeholder", "Loading model list…")
            explanation: modelsTab.api.modelsError
        }

        PlasmaComponents3.ScrollView {
            anchors.fill: parent

            contentItem: ListView {
                id: listView

                model: modelsTab.filtered
                clip: true
                currentIndex: -1

                delegate: PlasmaComponents3.ItemDelegate {
                    id: delegate

                    required property var modelData

                    readonly property bool isExpanded: modelsTab.expandedId === modelData.id
                    readonly property var pricing: modelData.pricing || ({})
                    readonly property real inPrice: Utils.pricePerUnit(pricing.prompt, modelsTab.unit)
                    readonly property real outPrice: Utils.pricePerUnit(pricing.completion, modelsTab.unit)

                    width: ListView.view.width
                    highlighted: isExpanded
                    onClicked: modelsTab.expandedId = isExpanded ? "" : modelData.id

                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        // -- Header row: name, context, prices --------------
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                PlasmaComponents3.Label {
                                    text: delegate.modelData.name || delegate.modelData.id
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                PlasmaExtras.DescriptiveLabel {
                                    text: l10n.trc("@info %1 is a token count such as 128K",
                                                "%1 context", Utils.tokens(delegate.modelData.context_length))
                                        + (Utils.isFree(delegate.modelData)
                                           ? "  ·  " + l10n.trc("@info model costs nothing", "free") : "")
                                    font: Kirigami.Theme.smallFont
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // The price column may only take its natural width,
                            // otherwise it squeezes the model name
                            ColumnLayout {
                                spacing: 0
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                                PlasmaComponents3.Label {
                                    text: l10n.trc("@info:status input price, %1 is an amount",
                                                "in %1", l10n.price(delegate.inPrice, modelsTab.sym))
                                    horizontalAlignment: Text.AlignRight
                                    font: Kirigami.Theme.smallFont
                                    Layout.alignment: Qt.AlignRight
                                }
                                PlasmaComponents3.Label {
                                    text: l10n.trc("@info:status output price, %1 is an amount",
                                                "out %1", l10n.price(delegate.outPrice, modelsTab.sym))
                                    horizontalAlignment: Text.AlignRight
                                    font: Kirigami.Theme.smallFont
                                    Layout.alignment: Qt.AlignRight
                                }
                            }

                            Kirigami.Icon {
                                source: modelsTab.isFavorite(delegate.modelData.id)
                                    ? "emblem-favorite" : "list-add"
                                opacity: modelsTab.isFavorite(delegate.modelData.id) ? 1 : 0.45
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelsTab.toggleFavorite(delegate.modelData.id)
                                }
                            }
                        }

                        // -- Expanded detail section -----------------------
                        Loader {
                            Layout.fillWidth: true
                            active: delegate.isExpanded
                            visible: active

                            sourceComponent: ColumnLayout {
                                spacing: 0

                                Kirigami.Separator {
                                    Layout.fillWidth: true
                                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                                }

                                InfoRow {
                                    label: l10n.trc("@label", "Model id")
                                    value: delegate.modelData.id
                                }
                                InfoRow {
                                    label: l10n.trc("@label", "Context window")
                                    value: l10n.trc("@item %1 is a token count",
                                                 "%1 tokens", Utils.tokens(delegate.modelData.context_length))
                                }
                                InfoRow {
                                    visible: delegate.modelData.architecture
                                        && delegate.modelData.architecture.modality
                                    label: l10n.trc("@label", "Modalities")
                                    value: delegate.modelData.architecture
                                        ? delegate.modelData.architecture.modality : ""
                                }

                                PlasmaExtras.Heading {
                                    text: l10n.trc("@title:group %1 is a token unit such as '1M tokens'",
                                                "Prices per %1", l10n.unitLabel(modelsTab.unit))
                                    level: 6
                                    Layout.fillWidth: true
                                    Layout.topMargin: Kirigami.Units.smallSpacing
                                }

                                InfoRow {
                                    label: l10n.trc("@label", "Input")
                                    value: l10n.price(delegate.inPrice, modelsTab.sym)
                                }
                                InfoRow {
                                    label: l10n.trc("@label", "Output")
                                    value: l10n.price(delegate.outPrice, modelsTab.sym)
                                }
                                InfoRow {
                                    visible: Utils.num(delegate.pricing.input_cache_read) > 0
                                    label: l10n.trc("@label", "Cache read")
                                    value: l10n.price(Utils.pricePerUnit(delegate.pricing.input_cache_read, modelsTab.unit), modelsTab.sym)
                                }
                                InfoRow {
                                    visible: Utils.num(delegate.pricing.input_cache_write) > 0
                                    label: l10n.trc("@label", "Cache write")
                                    value: l10n.price(Utils.pricePerUnit(delegate.pricing.input_cache_write, modelsTab.unit), modelsTab.sym)
                                }
                                InfoRow {
                                    visible: Utils.num(delegate.pricing.internal_reasoning) > 0
                                    label: l10n.trc("@label", "Reasoning")
                                    value: l10n.price(Utils.pricePerUnit(delegate.pricing.internal_reasoning, modelsTab.unit), modelsTab.sym)
                                }
                                InfoRow {
                                    visible: Utils.num(delegate.pricing.image) > 0
                                    label: l10n.trc("@label", "Per image")
                                    value: l10n.price(Utils.num(delegate.pricing.image), modelsTab.sym)
                                }
                                InfoRow {
                                    visible: Utils.num(delegate.pricing.request) > 0
                                    label: l10n.trc("@label", "Per request")
                                    value: l10n.price(Utils.num(delegate.pricing.request), modelsTab.sym)
                                }
                                InfoRow {
                                    visible: Utils.num(delegate.pricing.web_search) > 0
                                    label: l10n.trc("@label", "Web search")
                                    value: l10n.price(Utils.num(delegate.pricing.web_search), modelsTab.sym)
                                }

                                // -- Cost calculator -----------------------
                                PlasmaExtras.Heading {
                                    text: l10n.trc("@title:group", "Cost calculator")
                                    level: 6
                                    Layout.fillWidth: true
                                    Layout.topMargin: Kirigami.Units.smallSpacing
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    PlasmaComponents3.TextField {
                                        Layout.fillWidth: true
                                        text: String(modelsTab.calcIn)
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 1000000000 }
                                        onEditingFinished: {
                                            modelsTab.calcIn = parseInt(text, 10) || 0;
                                            modelsTab.cfg.calcInputTokens = modelsTab.calcIn;
                                        }

                                        PlasmaComponents3.ToolTip {
                                            text: l10n.trc("@info:tooltip", "Input tokens")
                                        }
                                    }

                                    PlasmaComponents3.Label {
                                        text: "→"
                                    }

                                    PlasmaComponents3.TextField {
                                        Layout.fillWidth: true
                                        text: String(modelsTab.calcOut)
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 1000000000 }
                                        onEditingFinished: {
                                            modelsTab.calcOut = parseInt(text, 10) || 0;
                                            modelsTab.cfg.calcOutputTokens = modelsTab.calcOut;
                                        }

                                        PlasmaComponents3.ToolTip {
                                            text: l10n.trc("@info:tooltip", "Output tokens")
                                        }
                                    }
                                }

                                InfoRow {
                                    label: l10n.trc("@label", "Estimated cost")
                                    emphasized: true
                                    valueColor: Kirigami.Theme.highlightColor
                                    value: l10n.price(
                                        Utils.estimate(delegate.pricing, modelsTab.calcIn, modelsTab.calcOut),
                                        modelsTab.sym)
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: Kirigami.Units.smallSpacing

                                    PlasmaComponents3.Button {
                                        text: modelsTab.isFavorite(delegate.modelData.id)
                                            ? l10n.trc("@action:button", "Remove favourite")
                                            : l10n.trc("@action:button", "Add to favourites")
                                        icon.name: "emblem-favorite"
                                        onClicked: modelsTab.toggleFavorite(delegate.modelData.id)
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    PlasmaComponents3.Button {
                                        text: l10n.trc("@action:button", "Details")
                                        icon.name: "internet-services"
                                        onClicked: Qt.openUrlExternally(
                                            "https://openrouter.ai/" + delegate.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
