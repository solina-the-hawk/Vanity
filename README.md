# Vanity
**A modular character description manager for Achaea and Mudlet.**

Vanity is a lightweight, zero-dependency script that takes the headache out of managing character descriptions. Instead of relying on sprawling Mudlet buttons, clunky aliases, or losing track of your various outfits, Vanity saves your descriptions to a local database and lets you manage, edit, and swap between them seamlessly. 

It fully supports Achaea's physical element system (Hair, Eyes, Build, etc.) and includes built-in style checking to keep your roleplay top-notch.

---
## Screenshots
*(Add your image links here! e.g., `<img width="800" src="...">`)*

## Features

* **Zero Bloat:** Single-script architecture. No messy XML packages, complex triggers, or reliance on external dependencies.
* **Keyword Database:** Save, load, and organize your favorite descriptions using easy-to-remember keywords and display names. 
* **Elements Manager:** Update your character's specific physical components (Hair, Eyes, Complexion, Height, Build) and effortlessly push them to the game.
* **Description Generator:** Combine your currently saved physical elements into a cohesive, experimental full-text description with a single command.
* **In-Line Editing:** Bypasses Mudlet's hardcoded C++ editor by using command-line injection, loading your saved descriptions directly into your input bar for fast, frustration-free editing.
* **Smart Style Checking:** Automatically scans your descriptions against Achaea's `HELP STYLE` rules to warn you about accidentally including clothing, godmoding emotional reactions, or using redundant gender/race flags.
* **Interactive Dashboard:** Type `vanity` at any time to pull up a clean, clickable UI in your main window showing your current elements and saved descriptions.

---

## Installation

1. Download the `Vanity.mpackage` or import the `Vanity-Core.lua` script directly into your Mudlet Script Editor.
2. Save the script to initialize the system. 
3. Type `vanity` in the game to view your dashboard, or `vanity help` to see a full list of commands!

*(Note: Vanity safely stores your saved descriptions inside your Mudlet Profile folder. You can find your `Vanity_Data.lua` file by typing `lua getMudletHomeDir()` in your Mudlet input line and navigating to the `/Vanity` directory.)*

---

## Quick Command Guide

Vanity is entirely command-driven. Here are a few essentials to get you started:

* **`vanity`** - Opens the interactive dashboard.
* **`vanity help`** - Displays the full syntax guide.
* **`vanity add <keyword> "<Name>" <text>`** - Saves a brand new description.
* **`vanity use <keyword>`** - Instantly sends your saved description to the game.
* **`vanity edit <keyword>`** - Drops your saved description into the command line so you can easily fix typos or add details.
* **`vanity elem update <type> <text>`** - Sets a specific physical element (e.g., `vanity elem update HAIR long blonde hair`).