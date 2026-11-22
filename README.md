# Brainwasher

Named, iconed talent specs at the Goblin Brainwashing Device, with an action bar profile for each.

For **World of Warcraft 1.12.1** with [ClassicAPI](https://github.com/brues-code/ClassicAPI), made for OctoWoW. [ActionBars](https://github.com/Fostercare5988/ActionBars) is optional.

When you talk to the device, its menu becomes a list of rows inside the gossip window: one per talent slot, with its icon, its name, its point split (most points green, fewest blue) and its action bar profile. Goodbye, the close button and Escape work as for any NPC.

- **Click a row's icon** to activate that slot. You are asked first. The active slot is marked "Active" and does nothing when clicked.
- **Save** stores your current talents in that slot, after asking which spec it replaces.
- **Buy** an unbought slot (a coin icon with the price), and **Reset talents** with the price, after asking.
- **Edit** opens a small menu: **Rename** (20 letters), **Icon** (the icons of your spellbook and talents first, then every spell and item icon; mouse wheel scrolls) and **Action bars** (None or any ActionBars profile).
- **The bars follow the spec.** Once the swap is over (1.5 seconds after the talents and spells stop changing), the slot's ActionBars profile loads, after combat if you are fighting. A profile that ActionBars no longer has is said once in chat and not loaded.
- **Show original** brings the device's own menu back.
- A slot you have not set up shows "Spec N" and the icon of its main talent tree.

Two slots with the same point split are told apart by the talents Brainwasher saves when you save or activate a slot. Hover a row for its full name, split and profile.

Brainwasher sleeps away from the device: it listens to two events and runs no timer. During a swap only, it also watches the talent and spell events.

## Install

[Download Brainwasher](https://github.com/Fostercare5988/Brainwasher/releases/latest/download/Brainwasher.zip) and extract it into `Interface/AddOns/`. The folder should be `Interface/AddOns/Brainwasher/`.

## Notes

There is no settings page and no slash command. Names, icons, profiles and saved talents are kept per character (`BrainwasherDB`).

The device is known by its menu texts (`Save 1st Specialization.`, `Activate 1st Specialization  (41/10/0)`, `Buy 4th Specialization tab for 200 gold.`, `Reset my talents. (1g0s0c)`), read in play on OctoWoW. The client has no talent-group API here, and nothing says when the server's swap is over, so those two jobs are small functions marked `GAP` in `Device.lua`.
