## 0.0.2
- Added `onCreate` callback to `StateContainer` constructor for post-construction setup.
- Wired `onCreate` through `StateProvider` and `registerState` extension.
- Renamed `registerState`'s `onCreated` parameter to `onCreate` for consistency.
- Removed `dispatcher` parameter from `StateProvider` and `registerState` — use `onCreate` to add dispatchers instead.
- Added `getState` method to `get_it` extension.

## 0.0.1

- Initial release.