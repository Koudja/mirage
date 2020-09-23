// Copyright Mirage authors & contributors <https://github.com/mirukana/mirage>
// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12
import "../../Base"

HPopup {
    id: popup

    property string clientUserId

    property string thumbnailTitle
    property string thumbnailMxc
    property string thumbnailPath: ""
    property var thumbnailCryptDict

    property string fullTitle
    property string fullMxc
    property var fullCryptDict
    property int fullFileSize

    property size overallSize

    property bool alternateScaling: false
    property bool activedFullScreen: false
    property bool imagesPaused: false
    property real imagesRotation: 0
    property real animatedRotationTarget: 0
    property real imagesSpeed: 1
    property var availableSpeeds: [16, 8, 2, 1.75, 1.5, 1.25, 1, 0.75, 0.5]

    readonly property alias info: info
    readonly property alias canvas: canvas
    readonly property alias buttons: buttons
    readonly property alias autoHideTimer: autoHideTimer

    readonly property bool isAnimated:
        canvas.thumbnail.animated || canvas.full.animated

    readonly property bool imageLargerThanWindow:
        overallSize.width > window.width || overallSize.height > window.height

    readonly property bool imageEqualToWindow:
        overallSize.width == window.width &&
        overallSize.height == window.height

    readonly property int paintedWidth:
        canvas.full.status === Image.Ready ?
        canvas.full.animatedPaintedWidth || canvas.full.paintedWidth :
        canvas.thumbnail.animatedPaintedWidth || canvas.thumbnail.paintedWidth

    readonly property int paintedHeight:
        canvas.full.status === Image.Ready ?
        canvas.full.animatedPaintedHeight || canvas.full.paintedHeight :
        canvas.thumbnail.animatedPaintedHeight || canvas.thumbnail.paintedHeight

    readonly property bool canAutoHide:
        paintedHeight * canvas.thumbnail.scale >
        height - info.implicitHeight - buttons.implicitHeight &&
        ! infoHover.hovered &&
        ! buttonsHover.hovered

    readonly property bool autoHide: canAutoHide && ! autoHideTimer.running

    signal openExternallyRequested()

    function showFullScreen() {
        if (activedFullScreen) return

        window.showFullScreen()
        popup.activedFullScreen = true
        if (! imageLargerThanWindow) popup.alternateScaling = true
    }

    function exitFullScreen() {
        if (! activedFullScreen) return

        window.showNormal()
        popup.activedFullScreen = false
        if (! imageLargerThanWindow) popup.alternateScaling = false
    }

    function toggleFullScreen() {
        const isFull = window.visibility === Window.FullScreen
        return isFull ? exitFullScreen() : showFullScreen()
    }


    margins: 0
    background: null

    onAboutToHide: exitFullScreen()

    HNumberAnimation {
        target: popup
        property: "imagesRotation"
        from: popup.imagesRotation
        to: popup.animatedRotationTarget
        easing.type: Easing.OutCirc
        onToChanged: restart()
    }

    Item {
        implicitWidth: window.width
        implicitHeight: window.height

        ViewerCanvas {
            id: canvas
            anchors.fill: parent
            viewer: popup
        }

        HoverHandler {
            readonly property point position: point.position

            enabled: popup.canAutoHide
            onPositionChanged:
                if (Math.abs(point.velocity.x + point.velocity.y) >= 0.05)
                    autoHideTimer.restart()
        }

        Timer {
            id: autoHideTimer
            interval: window.settings.media.autoHideOSDAfterMsec
        }

        ViewerInfo {
            id: info
            viewer: popup
            width: parent.width
            y:
                (parent.width < buttons.width * 4 || layout.vertical) &&
                popup.autoHide ?
                -height :

                parent.width < buttons.width * 4  || layout.vertical ?
                0 :

                parent.height - (popup.autoHide ? 0 : height)

            maxTitleWidth: y <= 0 ? -1 : buttons.x - buttons.width / 2

            Behavior on y { HNumberAnimation {} }

            HoverHandler { id: infoHover }
        }

        ViewerButtons {
            id: buttons
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(calculatedWidth, parent.width)
            y: parent.height - (popup.autoHide ? 0 : height)
            viewer: popup

            Behavior on y { HNumberAnimation {} }

            HoverHandler { id: buttonsHover }
        }
    }
}
