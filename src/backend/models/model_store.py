# Copyright Mirage authors & contributors <https://github.com/mirukana/mirage>
# SPDX-License-Identifier: LGPL-3.0-or-later

from collections import UserDict
from dataclasses import dataclass, field
from typing import Dict

from . import SyncId
from .model import Model
from .special_models import (
    AllRooms, AutoCompletedMembers, FilteredHomeservers, FilteredMembers,
    MatchingAccounts,
)


@dataclass(frozen=True)
class ModelStore(UserDict):
    """Dict of sync ID keys and `Model` values.

    The dict keys must be the sync ID of `Model` values.
    If a non-existent key is accessed, a corresponding `Model` will be
    created, put into the internal `data` dict and returned.
    """

    data: Dict[SyncId, Model] = field(default_factory=dict)


    def __missing__(self, key: SyncId) -> Model:
        """When accessing a non-existent model, create and return it.

        Special models rather than a generic `Model` object may be returned
        depending on the passed key.
        """

        is_tuple = isinstance(key, tuple)

        model: Model

        if key == "all_rooms":
            model = AllRooms(self["accounts"])
        elif key == "matching_accounts":
            model = MatchingAccounts(self["all_rooms"])
        elif key == "filtered_homeservers":
            model = FilteredHomeservers()
        elif is_tuple and len(key) == 3 and key[2] == "filtered_members":
            model = FilteredMembers(user_id=key[0], room_id=key[1])
        elif is_tuple and len(key) == 3 and key[2] == "autocompleted_members":
            model = AutoCompletedMembers(user_id=key[0], room_id=key[1])
        else:
            model = Model(sync_id=key)  # type: ignore

        self.data[key] = model
        return model


    def __str__(self) -> str:
        """Provide a nice overview of stored models when `print()` called."""

        return "%s(\n    %s\n)" % (
            type(self).__name__,
            "\n    ".join(sorted(str(v) for v in self.values())),
        )


    async def ensure_exists_from_qml(self, sync_id: SyncId) -> None:
        """Create model if it doesn't exist. Should only be called by QML."""

        if isinstance(sync_id, list):  # QML can't pass tuples
            sync_id = tuple(sync_id)

        self[sync_id]  # will call __missing__ if needed
