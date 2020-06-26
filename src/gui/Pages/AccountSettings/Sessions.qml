// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../../Base"
import "../../Base/ButtonLayout"
import "../../PythonBridge"
import "../../ShortcutBundles"

HColumnPage {
    id: page
    contentHeight: Math.min(
        window.height,
        Math.max(
            deviceList.contentHeight + deviceList.bottomMargin,
            busyIndicatorLoader.height + theme.spacing * 2,
        )
    )


    property string userId

    property bool enableFlickShortcuts:
        SwipeView ? SwipeView.isCurrentItem : true

    property Future loadFuture: null

    // property var pr: column.childrenRect.height
    // onPrChanged: print("pr changed:", pr, deviceList.implicitHeight)


    function takeFocus() {} // XXX

    function loadDevices() {
        loadFuture = py.callClientCoro(userId, "devices_info", [], devices => {
            deviceList.checked = {}
            deviceList.model.clear()

            for (const device of devices)
                deviceList.model.append(device)

            loadFuture                   = null
            deviceList.sectionItemCounts = getSectionItemCounts()
        })
    }

    function renameDevice(index, name) {
        const device = deviceList.model.get(index)

        device.display_name = name

        py.callClientCoro(userId, "rename_device", [device.id, name], ok => {
            if (! ok) deviceList.model.remove(index)  // 404 happened
        })
    }

    function getSectionItemCounts() {
        const counts = {}

        for (let i = 0; i < deviceList.model.count; i++) {
            const section = deviceList.model.get(i).type
            section in counts ? counts[section] += 1 : counts[section] = 1
        }

        return counts
    }


    footer: ButtonLayout {
        OtherButton {
            text: qsTr("Refresh")
            icon.name: "device-refresh-list"
            onClicked: loadDevices()
        }

        OtherButton {
            text:
                deviceList.selectedCount === 0 ?
                qsTr("Sign out all") :
                deviceList.selectedCount === 1 ?
                qsTr("Sign out checked") :
                qsTr("Sign out checked (%1)").arg(deviceList.selectedCount)

            icon.name: "device-delete-checked"
            icon.color: theme.colors.negativeBackground
        }
    }


    HListView {
        id: deviceList

        // Don't bind directly to getSectionItemCounts(), laggy with big list
        property var sectionItemCounts: ({})

        bottomMargin: theme.spacing
        clip: true
        model: ListModel {}
        delegate: DeviceDelegate {
            width: deviceList.width
            view: deviceList
            userId: page.userId
            onVerified: page.loadDevices()
            onBlacklisted: page.loadDevices()
            onRenameRequest: name => renameDevice(model.index, name)
        }

        section.property: "type"
        section.delegate: DeviceSection {
            width: deviceList.width
            view: deviceList
        }

        Component.onCompleted: page.loadDevices()

        Layout.fillWidth: true
        Layout.fillHeight: true

        FlickShortcuts {
            flickable: deviceList
            active:
                ! mainUI.debugConsole.visible && page.enableFlickShortcuts
        }

        HLoader {
            id: busyIndicatorLoader
            anchors.centerIn: parent
            width: 96 * theme.uiScale
            height: width

            source: "../../Base/HBusyIndicator.qml"
            active: page.loadFuture
            opacity: active ? 1 : 0

            Behavior on opacity { HNumberAnimation { factor: 2 } }
        }
    }
}