import QtQuick 2.12
import QtQuick.Layouts 1.12

HPopup {
    id: popup
    onAboutToShow: okClicked = false


    signal ok()
    signal cancel()


    property alias summary: summary
    property alias details: details
    property bool okClicked: false


    box.enterButtonTarget: "ok"
    box.buttonModel: [
        { name: "ok", text: qsTr("OK"), iconName: "ok" },
        { name: "cancel", text: qsTr("Cancel"), iconName: "cancel" },
    ]
    box.buttonCallbacks: ({
        ok:     button => { okClicked = true; popup.ok(); popup.close() },
        cancel: button => { okClicked = false; popup.cancel(); popup.close() },
    })


    HLabel {
        id: summary
        wrapMode: Text.Wrap
        font.bold: true
        visible: Boolean(text)

        Layout.fillWidth: true
    }

    HLabel {
        id: details
        wrapMode: Text.Wrap
        visible: Boolean(text)

        Layout.fillWidth: true
    }
}