# ProfPadenClams

Optional clam opening and narrowly scoped inventory cleanup for ProfPaden.

**WoW Forever · Interface 16001 · 0.1.1-beta**

Release candidate / beta. Live-game acceptance is still required.

Requires [ProfPaden](https://github.com/paden1991/ProfPaden), installed as a separate addon.

## Installation

Copy the `ProfPadenClams` folder into your WoW Forever `Interface/AddOns` directory, then restart or reload the client. Alternatively, run `python tools/build_local.py` to create an installable ZIP under `dist/`.

Open the addon with `/ppclams`.

## Verification

```sh
python tools/build_local.py --verify-only
```

This checks the published runtime bytes against the reviewed source manifest. For repositories with external files, add `--local-addon` to verify the complete build. It is a source-integrity check, not live-game certification.

## Related addons

- [ProfPaden](https://github.com/paden1991/ProfPaden)
- [ProfPadenRoutes](https://github.com/paden1991/ProfPadenRoutes)
- [CounterCast](https://github.com/paden1991/CounterCast)
- [CounterCastProbe](https://github.com/paden1991/CounterCastProbe)
- [RAID](https://github.com/paden1991/RAID)

## Ownership and provenance

Public visibility does not assign a new open-source license. Existing third-party notices and applicable data licenses remain in force. Do not assume that excluded dependencies may be redistributed. No account SavedVariables, personal settings, raw research archives, credentials, or prior packaged releases are included.
