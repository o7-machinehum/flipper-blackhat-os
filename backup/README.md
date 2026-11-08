# Backups of scripts that live on the Black Hat's SD card

These files are not part of the OS build. They are copies of the user's own
scripts from the card, kept here so they survive a reflash.

| File | Lives on the card at | Notes |
|------|----------------------|-------|
| `blackhat-menu` | `/boot/bh/scripts/blackhat-menu` and `/usr/local/bin/blackhat-menu` | Arrow-key version of the Black Hat payload menu. Arrows move, OK runs, Back exits; number keys still work on a keyboard. Open it from bhtui: Blackhat > Blackhat Menu (Flipper app, "screen only" mode). |

To put one back on a freshly flashed card, copy it to both paths and run
`chmod 755` on them.
