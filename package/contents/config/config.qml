/*
 * Pages of the settings dialog.
 *
 * The category names honour the widget's own language setting too. L10n.qml
 * cannot be reached from this directory, so the catalogue is consulted
 * directly here - a JS import works by relative path, a type import would not.
 *
 * SPDX-License-Identifier: MIT
 */
import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.configuration

import "../code/catalogs.js" as Catalogs

ConfigModel {
    id: configModel

    /* Same lookup order as L10n.trc: source language, catalogue, then KI18n. */
    function trc(context, msgid) {
        var lang = Plasmoid.configuration.language;
        if (lang === "en") {
            return msgid;
        }
        var cat = lang.length > 0 ? Catalogs.catalog(lang) : null;
        var hit = (cat && cat.messages) ? cat.messages[context + "\u0004" + msgid] : null;
        return hit ? hit : i18nc(context, msgid);
    }

    ConfigCategory {
        name: configModel.trc("@title:tab settings page", "Account")
        icon: "wallet-open"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: configModel.trc("@title:tab settings page", "Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: configModel.trc("@title:tab settings page", "Models")
        icon: "view-list-details"
        source: "ConfigModels.qml"
    }
}
