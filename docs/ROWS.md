# Rows alternative for v8

`Vanilla-Plus-Megapack-Rows-v8.zip` is a complete alternate megapack. It uses
the in-game verified Know Your Constellation Rows layout. All constellation
sections and their enemy lists appear at once, with long lists wrapped into
rows and the same native font, frame and menu visibility rules.

The forecast resource matches the verified standalone Rows package exactly.
Every other resource, including the pack identity and all eight other mods,
matches the standard v8 ZIP byte for byte. Enemy Collision Synchronized v2.9
and all existing gameplay settings are retained.

Enable one megapack version with Bingus Shared Loader v12 or newer, installed
separately. Disable the standard megapack before enabling Rows. Give Rows
priority over standalone forecast packages to use its layout. Purge / Deploy
with the game closed. The loader priority rules are the same for both packs.

For a source build, build or download the standard v8 ZIP into the release
directory first, then run `python scripts/build.py --rows`. Alternate build
outputs go to `build/rows`. The component lock pins both forecast payloads.
The package test compares against the standard ZIP and requires exactly one
changed resource. Shared startup, duplicate-install and component tests also
run for the alternate build.

The standalone Rows layout passed user verification in-game. The combined
Rows package has offline integration and byte-for-byte component verification.
