// Copyright Mirage authors & contributors <https://github.com/mirukana/mirage>
// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12
import QtQuick.Layouts 1.12
import "../../.."
import "../../../Base"
import "../../../Base/HTile"

HListView {
    id: root

    property HTextArea textArea
    property bool open: false

    property var originalWord: null
    property int replacementStart: -1
    property int replacementEnd: -1
    property bool autoOpenCompleted: false
    property var usersCompleted: ({})  // {userId: displayName}

    readonly property bool autoOpen: {
        if (autoOpenCompleted) return true
        const current = textArea.getWordBehindCursor()
        return current ? /^@.+/.test(current.word) : false
    }

    readonly property var wordToComplete:
        open ? originalWord || textArea.getWordBehindCursor() : null

    readonly property string modelFilter:
        autoOpen && wordToComplete ? wordToComplete.word.replace(/^@/, "") :
        open && wordToComplete ? wordToComplete.word :
        ""

    function replaceCompletionOrCurrentWord(withText) {
        Qt.inputMethod.reset()

        const current = textArea.getWordBehindCursor()
        if (! current) return

        replacementStart === -1 || replacementEnd === -1 ?
        textArea.remove(current.start, current.end + 1) :
        textArea.remove(replacementStart, replacementEnd)

        textArea.insertAtCursor(withText)
    }

    function previous() {
        if (open) {
            decrementCurrentIndex()
            return
        }

        open = true
        const args = [model.modelId, modelFilter]
        py.callCoro("set_string_filter", args, decrementCurrentIndex)
    }

    function next() {
        if (open) {
            incrementCurrentIndex()
            return
        }

        open = true
        const args = [model.modelId, modelFilter]
        py.callCoro("set_string_filter", args, incrementCurrentIndex)
    }

    function accept() {
        if (currentIndex !== -1) {
            const member = model.get(currentIndex)
            usersCompleted[member.id] = member.display_name.trim()
            usersCompletedChanged()
        }

        open = false
    }

    function cancel() {
        if (originalWord) replaceCompletionOrCurrentWord(originalWord.word)

        currentIndex = -1
        open         = false
    }


    visible: opacity > 0
    opacity: open && count ? 1 : 0
    bottomMargin: theme.spacing / 2
    implicitHeight:
        open && count ?
        Math.min(window.height, contentHeight + topMargin + bottomMargin) :
        0

    model: ModelStore.get(chat.userId, chat.roomId, "autocompleted_members")

    delegate: CompletableUserDelegate {
        width: root.width
        colorName: hovered || root.currentIndex === model.index
        onClicked: {
            root.currentIndex = model.index
            root.accept()
            root.open = false
        }
    }

    onAutoOpenChanged: open = autoOpen
    onOpenChanged: if (! open) {
        originalWord      = null
        replacementStart  = -1
        replacementEnd    = -1
        currentIndex      = -1
        autoOpenCompleted = false
        py.callCoro("set_string_filter", [model.modelId, ""])
    }

    onModelFilterChanged: {
        if (! open) return
        py.callCoro("set_string_filter", [model.modelId, modelFilter])
    }

    onCurrentIndexChanged: {
        if (currentIndex === -1) return
        if (! originalWord) originalWord = textArea.getWordBehindCursor()
        if (autoOpen) autoOpenCompleted = true

        const member      = model.get(currentIndex)
        const replacement = member.display_name.trim() || member.id

        replaceCompletionOrCurrentWord(replacement)
        replacementStart = textArea.cursorPosition - replacement.length
        replacementEnd   = textArea.cursorPosition
    }

    Behavior on opacity { HNumberAnimation {} }
    Behavior on implicitHeight { HNumberAnimation {} }

    Rectangle {
        anchors.fill: parent
        z: -1
        color: theme.chat.userAutoCompletion.background
    }

    Connections {
        target: root.textArea

        onCursorPositionChanged: {
            if (! root.open) return

            const pos   = root.textArea.cursorPosition
            const start = root.wordToComplete.start
            let end     = root.wordToComplete.end + 1

            if (root.currentIndex !== -1) {
                const member = root.model.get(root.currentIndex)
                const repl   = member.display_name.trim() || member.id
                end          = root.wordToComplete.start + repl.length
            }

            if (pos === root.textArea.length) return
            if (pos < start || pos > end) root.accept()
        }

        onTextChanged: {
            let changed = false

            for (const [id, name] of Object.entries(root.usersCompleted)) {
                if (! root.textArea.text.includes(name)) {
                    delete root.usersCompleted[id]
                    changed = true
                }
            }

            if (changed) root.usersCompletedChanged()
        }
    }
}
