// Copyright Mirage authors & contributors <https://github.com/mirukana/mirage>
// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12
import Clipboard 0.1
import CppUtils 0.1
import "../../../Base"
import "../../../Dialogs"

HButton {
    enabled: chat.roomInfo.can_send_messages
    icon.name: "upload-file"
    backgroundColor: theme.chat.composer.uploadButton.background
    toolTip.text:
        chat.userInfo.max_upload_size ?
        qsTr("Send files (%1 max)").arg(
            CppUtils.formattedBytes(chat.userInfo.max_upload_size, 0),
        ) :
        qsTr("Send files")

    onClicked: sendFilePicker.dialog.open()

    HShortcut {
        sequences: window.settings.keys.sendFileFromPathInClipboard
        onActivated: window.makePopup(
            "Popups/ConfirmUploadPopup.qml",
            {
                userId: chat.userId,
                roomId: chat.roomId,
                roomName: chat.roomInfo.display_name,
                filePath: Clipboard.text.trim(),
                replyToEventId: chat.replyToEventId,
            },
            popup => popup.replied.connect(chat.clearReplyTo),
        )
    }

    SendFilePicker {
        id: sendFilePicker
        userId: chat.userId
        roomId: chat.roomId
        replyToEventId: chat.replyToEventId
        onReplied: chat.clearReplyTo()

        HShortcut {
            sequences: window.settings.keys.sendFile
            onActivated: sendFilePicker.dialog.open()
        }
    }
}
