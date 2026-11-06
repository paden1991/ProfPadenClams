Clam Keeper 0.1.3-beta fixes cases where clams were detected but opening stalled or the Open clam button stayed disabled.

- Recognizes loot containers with "clam" anywhere in their name, including previously unlisted clam types. Clam meat, food, equipment and protected items are excluded.
- Stops treating leftover loot-slot counts as an active loot window. Actual visible or event-tracked loot still pauses opening.
- Recovers from temporary busy/locked states and keeps opening timeouts running while busy.
- Prevents the manual Open clam button from disabling itself before its secure click handler runs.
- Shows the reason for a pause and adds `/ppclams status` diagnostics.

Existing junk protections and silent quick loot are preserved. Reload after updating. This remains a beta: 66 automated Lua checks and UIForever panel checks passed; actual item opening in the live game remains unconfirmed.

Requires [ProfPaden](https://github.com/paden1991/ProfPaden) separately. Download the attached `-forever.zip` for WoW Forever / Interface 16001. For WowUp, use `https://github.com/paden1991/ProfPadenClams` with Install from URL and the Beta channel. Automatic Source code archives are not the installable package.
