// Copyright Mirage authors & contributors <https://github.com/mirukana/mirage>
// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12

QtObject {
    id: future

    property PythonBridge bridge

    readonly property QtObject privates: QtObject {
        property var pythonFuture: null
        property bool cancelPending: false

        onPythonFutureChanged: if (cancelPending) future.cancel()
    }

    function cancel() {
        if (! privates.pythonFuture) {
            privates.cancelPending = true
            return
        }

        bridge.call(bridge.getattr(privates.pythonFuture, "cancel"))
    }
}
