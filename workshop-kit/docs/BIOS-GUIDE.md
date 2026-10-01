# Turning on virtualization in the BIOS

**Take a photo of this page with your phone before you start.** You will not
be able to see your screen's other windows while you are in the BIOS.

## Before you start

- Plug in your charger.
- If Claude asked you to, make sure you can see your BitLocker recovery key at
  https://aka.ms/myrecoverykey on your phone.
- Change **only** the virtualization setting. Do **not** change Secure Boot,
  TPM, Boot order, or passwords.

## Getting into the BIOS

Claude will usually restart your laptop straight into the BIOS. If it could
not, do this yourself:

**Settings > System > Recovery > Advanced startup > Restart now >
Troubleshoot > Advanced options > UEFI Firmware Settings > Restart**

If that option is missing, restart and repeatedly press the key for your
brand as soon as the screen turns on:

| Brand | Key |
|---|---|
| Dell | F2 |
| HP | Esc, then F10 |
| Lenovo ThinkPad | Enter, then F1 |
| Lenovo IdeaPad / Yoga | F2 (or the small "Novo" pinhole button) |
| ASUS | F2 |
| Acer | F2 |
| MSI | Delete |
| Microsoft Surface | Hold Volume Up, press and release Power |

## Finding the setting

The name depends on your processor:

- **Intel:** "Intel Virtualization Technology", "Intel VT-x", or "VT-x"
- **AMD:** "SVM Mode", "SVM", or "AMD-V"

Where it usually is:

| Brand | Location |
|---|---|
| Dell | Virtualization Support > Virtualization (or Advanced > Virtualization) |
| HP | Advanced > System Options > Virtualization Technology (VTx) |
| Lenovo ThinkPad | Config (or Security) > Virtualization > Intel Virtualization Technology |
| Lenovo IdeaPad / Yoga | Configuration > Intel Virtual Technology / AMD SVM Technology |
| ASUS | Advanced > CPU Configuration > Intel Virtualization Technology / SVM Mode (press F7 for Advanced Mode first) |
| Acer | Advanced (or Main) > Intel Virtualization Technology / AMD-V |
| MSI | OC (or Advanced) > CPU Features > Intel Virtualization Tech / SVM Mode |
| Microsoft Surface | Usually already on. Tell the instructor. |

Set it to **Enabled**.

## Saving

Press **F10** (on most laptops) and choose **Yes** to save and exit. Windows
starts normally.

Then open Claude, open the workshop folder, and type **continue**.

## If something looks wrong

- **Windows asks for a BitLocker recovery key:** type in the key from
  https://aka.ms/myrecoverykey on your phone (use the one whose Key ID matches
  the ID on the screen).
- **You cannot find the setting, or the BIOS asks for a password:** choose
  "Exit without saving" and ask the instructor.
