# fuckZonesAntiCamp
An advanced anti-camp plugin for CS:GO, made for fuckZones by Bara.

![Downloads](https://img.shields.io/github/downloads/Sarrus1/fuckZonesAntiCamp/total?style=flat-square) ![Last commit](https://img.shields.io/github/last-commit/Sarrus1/fuckZonesAntiCamp?style=flat-square) ![Open issues](https://img.shields.io/github/issues/Sarrus1/fuckZonesAntiCamp?style=flat-square) ![Closed issues](https://img.shields.io/github/issues-closed/Sarrus1/fuckZonesAntiCamp?style=flat-square) ![Size](https://img.shields.io/github/repo-size/Sarrus1/fuckZonesAntiCamp?style=flat-square) ![GitHub Workflow Status](https://img.shields.io/github/workflow/status/Sarrus1/fuckZonesAntiCamp/Compile%20with%20SourceMod?style=flat-square)

## Description ##
Admins can define areas, where, if a player spends more than x minutes in it, he will get slapped until he leaves the area.
Admins can decide how much slap damage will be inflicted, how long the player can stay in the areas, and more.

## Requirements ##
- Sourcemod and Metamod
- [fuckZones](https://forums.alliedmods.net/showthread.php?t=328422) by Bara
- [SM Warn](https://forums.alliedmods.net/showthread.php?t=197853) (Optional)

## Installation ##
1. Grab the latest release from the release page and unzip it in your sourcemod folder.
2. Restart the server or type **`sm plugins load fuckZonesAntiCamp`** in the console to load the plugin.
3. The config file will be automatically generated in **`cfg/sourcemod/`**

## Configuration ##
- You can modify the phrases in **`addons/sourcemod/translations/fuckZonesAntiCamp.phrases.txt`**.
- Once the plugin has been loaded, you can modify the cvars in **`cfg/sourcemod/fuckZonesAntiCamp.cfg`**.
- To add a sound, put it in the **`sound/misc/anticamp folder`**. It has to be in the .mp3 format. Then, configure the appropriate convar in **`cfg/sourcemod/fuckZonesAntiCamp.cfg`** by pointing to the sound file relative to the sound folder. Remember to add the sound file to your FASTDL directory aswell.

## Usage ##
### Creating zones ###
Once the plugin has been loaded, admins can type **`!zones`** in chat to open the zone menu. From there you can create a zone by pointing your cursor at where you want to create the zone.

### Editing zones ###
Once a zone has been created, you can modifiy it my typing !zones in chat.

### Restrict zones ###
If you don't want CT to camp in a zone, include **"AnticampCT"** in the name of the zone.

For T, use **"AnticampT"**.

For Both teams, use **"AnticampBoth"**

## Contacts ##
If you have questions, you can add me on Discord: Sarrus#9090

## To do ##
- ~~Add a Cvar to set slap frequency~~
- ~~Do a cooldown system~~
- ~~Add sound support~~
- Make zones without having to rename them


