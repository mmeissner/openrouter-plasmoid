import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// Test bench: instantiates every representation with synthetic data so QML
// warnings surface and screenshots can be captured without a real account.
Window {
    id: win

    property string shotPath: "/tmp/openrouter-bench.png"
    property int shotWidth: 1500
    property int shotHeight: 620

    width: shotWidth
    height: shotHeight
    visible: true
    color: "#fcfcfc"

    OpenRouterApi {
        id: api
        rawApiKey: Plasmoid.configuration.apiKey
    }

    QtObject {
        id: dummyPlasmoidItem
        property bool expanded: false
    }

    // Opaque backdrop - grabToImage() does not capture Window.color
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        // Panel strip
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            color: Kirigami.Theme.alternateBackgroundColor
            radius: 4

            CompactView {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                api: api
                plasmoidItem: dummyPlasmoidItem
                width: 460
                height: 46
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            OverviewTab {
                api: api
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 470
            }

            ModelsTab {
                id: modelsTab
                api: api
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 470
            }

            ActivityTab {
                id: activityTab
                api: api
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 470
            }
        }
    }

    /*
     * Regression check for the in-widget language switch: the stub starts in
     * one language and this flips it at runtime, so the screenshot proves the
     * bindings re-evaluate without a reload.
     */
    property string switchLanguageTo: "en"

    Timer {
        interval: 5000
        running: win.switchLanguageTo.length > 0
        onTriggered: {
            Plasmoid.configuration.language = win.switchLanguageTo;
            console.warn("BENCH language switched to " + win.switchLanguageTo);
        }
    }

    // Synthetic account data - never touches a real key
    Timer {
        interval: 2500
        running: true
        onTriggered: {
            var rows = [];
            var names = ["anthropic/claude-sonnet-4.5", "openai/gpt-4o-mini",
                         "deepseek/deepseek-v4-flash", "google/gemini-3.5-flash"];
            var base = new Date();
            for (var d = 29; d >= 0; --d) {
                var day = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth(),
                                            base.getUTCDate() - d));
                var iso = day.toISOString().substring(0, 10);
                for (var m = 0; m < names.length; ++m) {
                    rows.push({
                        date: iso,
                        model: names[m],
                        usage: (0.35 + 0.4 * Math.abs(Math.sin(d * 0.7 + m))) / (m + 1),
                        requests: 40 + ((d * 13 + m * 7) % 90),
                        prompt_tokens: 90000 + d * 2500 + m * 4000,
                        completion_tokens: 21000 + d * 700,
                        reasoning_tokens: 0
                    });
                }
            }
            api.parseActivity(rows);
            api.activityLoaded = true;

            api.totalCredits = 96;
            api.totalUsage = 61.33;
            api.creditsValid = true;
            api.keyValid = true;
            api.keyLabel = "desktop";
            api.keyLimit = null;
            api.keyLimitRemaining = null;
            api.keyLimitReset = "";
            api.freeTier = false;
            api.usageDaily = 0;
            api.lastUpdate = new Date().getTime();
            api.errorMessage = "";

            if (api.models.length > 0) {
                modelsTab.expandedId = api.models[0].id;
            }
            // Exercise the drill-down into a single day
            if (api.activityDays.length > 0) {
                activityTab.selectedDate = api.activityDays[api.activityDays.length - 2].date;
            }
            console.warn("BENCH models=" + api.models.length
                       + " days=" + api.activityDays.length
                       + " balance=" + api.balance.toFixed(2));
        }
    }

    Timer {
        interval: 6500
        running: true
        onTriggered: {
            win.contentItem.grabToImage(function (r) {
                r.saveToFile(win.shotPath);
                console.warn("BENCH screenshot " + win.shotPath);
            });
        }
    }
}
