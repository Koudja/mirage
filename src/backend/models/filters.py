# Copyright Mirage authors & contributors <https://github.com/mirukana/mirage>
# SPDX-License-Identifier: LGPL-3.0-or-later

from typing import (
    TYPE_CHECKING, Any, Callable, Collection, Dict, List, Optional, Tuple,
)

from . import SyncId
from .model import Model
from .proxy import ModelProxy

if TYPE_CHECKING:
    from .model_item import ModelItem


class ModelFilter(ModelProxy):
    """Filter data from one or more source models."""

    def __init__(self, sync_id: SyncId) -> None:
        self.filtered_out: Dict[Tuple[Optional[SyncId], str], "ModelItem"] = {}
        self.items_changed_callbacks: List[Callable[[], None]] = []
        super().__init__(sync_id)


    def accept_item(self, item: "ModelItem") -> bool:
        """Return whether an item should be present or filtered out."""
        return True


    def source_item_set(
        self,
        source: Model,
        key,
        value: "ModelItem",
        _changed_fields: Optional[Dict[str, Any]] = None,
    ) -> None:
        with self.write_lock:
            if self.accept_source(source):
                value = self.convert_item(value)

                if self.accept_item(value):
                    self.__setitem__(
                        (source.sync_id, key), value, _changed_fields,
                    )
                    self.filtered_out.pop((source.sync_id, key), None)
                else:
                    self.filtered_out[source.sync_id, key] = value
                    self.pop((source.sync_id, key), None)

                for callback in self.items_changed_callbacks:
                    callback()


    def source_item_deleted(self, source: Model, key) -> None:
        with self.write_lock:
            if self.accept_source(source):
                try:
                    del self[source.sync_id, key]
                except KeyError:
                    del self.filtered_out[source.sync_id, key]

                for callback in self.items_changed_callbacks:
                    callback()


    def source_cleared(self, source: Model) -> None:
        with self.write_lock:
            if self.accept_source(source):
                for source_sync_id, key in self.copy():
                    if source_sync_id == source.sync_id:
                        try:
                            del self[source.sync_id, key]
                        except KeyError:
                            del self.filtered_out[source.sync_id, key]

                for callback in self.items_changed_callbacks:
                    callback()


    def refilter(
        self,
        only_if: Optional[Callable[["ModelItem"], bool]] = None,
    ) -> None:
        """Recheck every item to decide if they should be filtered out."""

        with self.write_lock:
            take_out   = []
            bring_back = []

            for key, item in sorted(self.items(), key=lambda kv: kv[1]):
                if only_if and not only_if(item):
                    continue

                if not self.accept_item(item):
                    take_out.append(key)

            for key, item in self.filtered_out.items():
                if only_if and not only_if(item):
                    continue

                if self.accept_item(item):
                    bring_back.append(key)

            with self.batch_remove():
                for key in take_out:
                    self.filtered_out[key] = self.pop(key)

            for key in bring_back:
                self[key] = self.filtered_out.pop(key)

            if take_out or bring_back:
                for callback in self.items_changed_callbacks:
                    callback()


class FieldStringFilter(ModelFilter):
    """Filter source models based on if their fields matches a string.

    This is used for filter fields in QML: the user enters some text and only
    items with a certain field (typically `display_name`) that starts with the
    entered text will be shown.

    Matching is done using "smart case": insensitive if the filter text is
    all lowercase, sensitive otherwise.
    """

    def __init__(
        self,
        sync_id:                    SyncId,
        fields:                     Collection[str],
        no_filter_accept_all_items: bool = True,
    ) -> None:

        self.fields                     = fields
        self.no_filter_accept_all_items = no_filter_accept_all_items
        self._filter: str               = ""


        super().__init__(sync_id)


    @property
    def filter(self) -> str:
        return self._filter


    @filter.setter
    def filter(self, value: str) -> None:
        if value != self._filter:
            self._filter = value
            self.refilter()


    def accept_item(self, item: "ModelItem") -> bool:
        if not self.filter:
            return self.no_filter_accept_all_items

        fields    = {f: getattr(item, f) for f in self.fields}
        filtr     = self.filter
        lowercase = filtr.lower()

        if lowercase == filtr:
            # Consider case only if filter isn't all lowercase
            filtr        = lowercase
            fields = {name: value.lower() for name, value in fields.items()}

        return self.match(fields, filtr)


    def match(self, fields: Dict[str, str], filtr: str) -> bool:
        for value in fields.values():
            if value.startswith(filtr):
                return True

        return False


class FieldSubstringFilter(FieldStringFilter):
    """Fuzzy-like alternative to `FieldStringFilter`.

    All words in the filter string must fully or partially match words in the
    item field values, e.g. "red l" can match "red light",
    "tired legs", "light red" (order of the filter words doesn't matter),
    but not just "red" or "light" by themselves.
    """

    def match(self, fields: Dict[str, str], filtr: str) -> bool:
        text = " ".join(fields.values())

        for word in filtr.split():
            if word and word not in text:
                return False

        return True
