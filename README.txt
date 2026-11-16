PearyOS 1.0 - download package
==============================

The ISO is cut into numbered parts because GitHub does not allow single files this big.
Join them back into one ISO, then write that ISO to a USB stick.

1. Join the parts (needs about 3 GB of free disk space)
   - Windows:       double-click join.bat
   - macOS / Linux: run   sh join.sh
   The result is pearyos-1.0-amd64.iso

2. Check it. The SHA-256 of the joined file must be:
   c41bf5ce6076edfdf7c9a92bc6c3de72dad9ffd4b1a53440a380b181b7b76da1

3. Write it to a USB stick (4 GB or larger). This ERASES the stick.
   - Windows: Rufus -> select the ISO -> choose "DD Image mode" when asked
   - Any system: balenaEtcher

4. Restart the PC, open the boot menu (F12 / F10 / F9 / Esc / F2, depending on the brand),
   pick the USB stick's UEFI entry, then "PearyOS (live session)".
   If the screen stays black, restart and choose the "safe graphics" entry.
   If the desktop feels slow, choose the "glass effects off" entry.

More details: README.md on the main branch of this repository.
