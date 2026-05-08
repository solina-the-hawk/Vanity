# Vanity
**A streamlined, zero-dependency character description and pose manager for Achaea and Mudlet.**

Vanity is a modern, lightweight system that removes the headache of managing character appearances and poses manually via aliases or clunky XML packages. It captures, stores, and organizes your various saved descriptions, modular elements, and stances into an easy-to-navigate dashboard. 

Unlike older systems, Vanity has zero external dependencies, relies purely on single-script architecture, and automatically gags server spam when swapping descriptions.

---

## Features

* **Zero Bloat:** Single-script architecture. No reliance on legacy packages or bloated XML files.
* **Modular Elements:** Quickly set or update individual elements like `HEIGHT`, `EYES`, or `COMPLEXION`. Includes a 1-click `BALD` feature! You can even generate a combined description directly from your active elements.
* **Smart Poses:** Save and swap between poses instantly. You can apply a standard `POSE`, or use a `TPOSE` (Temporary Pose) which automatically clears itself the moment you walk into a new room. 
* **Dynamic Add-ons:** Have temporary gear, wounds, or a roleplay state you want added to the end of your description? Toggle an add-on string that automatically appends itself to whatever primary description you activate.
* **Style Checker:** Vanity acts as a gentle editor, warning you if your description includes Godmoding, repeats your automatically-prepended race/gender, or describes clothing that the game already handles via your inventory.
* **Dashboard Interface:** Type `vanity` in-game to see a clean, clickable UI of all your active elements, add-ons, and saved keywords. 

---

## Installation

1. Download the `Vanity.mpackage` or import the `Vanity-Core.lua` script directly into your Mudlet Script Editor.
2. Save the script. It will automatically initialize. 
3. Edit the `Vanity.config` block at the top of the script to adjust colors, character limits, or debug modes to your liking.
4. Type `vanity help` in the game for a list of helpful commands to start building your library!

---

## Accessing Your Data

Vanity stores your saved descriptions, poses, and active elements in a clean JSON/Lua format so they are preserved across sessions. 

To find your saved data file, look in your Mudlet Profile folder. If you're not sure where that is, open Mudlet's main input line and type:
`lua getMudletHomeDir()`

Navigate to that folder on your computer, and you will find a directory named **Vanity**. Inside, you will see your `Vanity_Data.lua` configuration file, which can easily be copied or shared with alt characters.