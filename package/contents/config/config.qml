import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nc("@title:tab settings page", "Account")
        icon: "wallet-open"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18nc("@title:tab settings page", "Appearance")
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18nc("@title:tab settings page", "Models")
        icon: "view-list-details"
        source: "ConfigModels.qml"
    }
}
