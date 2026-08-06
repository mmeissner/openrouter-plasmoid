pragma Singleton
import QtQuick

// Stand-in for the Plasmoid attached object, which only exists inside plasmashell
QtObject {
    property QtObject configuration: QtObject {
        property string apiKey: "sk-or-v1-testbench"
        property string apiKeyFile: ""
        property string managementKey: ""
        property string managementKeyFile: ""
        property int refreshInterval: 300
        property bool refreshOnOpen: true
        property real lowThreshold: 5.0
        property real criticalThreshold: 1.0
        property bool notifyLow: true
        property string language: "de"
        property string compactItems: "balance,today,month,requests"
        property bool compactLabels: true
        property bool compactStacked: false
        property string compactSeparator: "·"
        property bool showIcon: true
        property string compactPrefix: ""
        property string currencySymbol: "$"
        property int decimals: 2
        property bool colorize: true
        property string favoriteModels: "anthropic/claude-sonnet-4.5,openai/gpt-4o-mini"
        property int pricingUnit: 1000000
        property int calcInputTokens: 1000000
        property int calcOutputTokens: 200000
        property real usageBaseline: 0
        property string usageBaselineDate: ""
        property string modelsSort: "name"
        property bool hideFreeModels: false
    }
    property int formFactor: 2
    property string pluginName: "com.github.teodorgross.openrouter"
    property QtObject actionStub: QtObject { function trigger() {} }
    function internalAction(name) { return actionStub }
}
