My personal DnD companion, built in bash using very few dependencies (all of which were pre-configured on my system). Track your health, spell slots, inventory, coin, and quest log — all from a CLI.

## Features

- **Character stats** — track HP, spell slots, channel divinity, and coin purse
- **Spell book** — browse, search, and cast spells with automatic slot tracking
- **Backpack** — organise items by category
- **Quest log** — journal entries for campaign notes and objectives
- **Rest system** — short and long rests with hit dice management
- **Spell source browser** — browse all spells from source XMLs without importing them

## Requirements

- `dialog`
- `jq`
- `xmllint` (from `libxml2-utils`)
- `tac` (from `coreutils`)

## Installation

Run the following command in your terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Galoose/DnD_terminal_companion/refs/heads/main/_setup.sh)
```

This will:
1. Check for any missing dependencies
2. Create the directory structure under `~/DnD`
3. Download `dnd.sh` and `stats.json`

## Running

```bash
cd ~/DnD && bash dnd.sh
```

Or add a shortcut alias to your shell:

```bash
echo 'alias dnd="cd ~/DnD && bash dnd.sh"' >> ~/.bashrc
source ~/.bashrc
```

Then just run:

```bash
dnd
```

## Directory Structure

```
~/DnD/
├── dnd.sh                  # main script
├── stats.json              # character stats
├── Spells/
│   ├── spell_list.txt      # list of imported spells
│   ├── spell-source/       # place XML spell source files here
│   └── *.json              # imported spell files
├── Items/
│   ├── Adventuring-gear/
│   ├── Magic-items/
│   ├── Monster-loot/
│   └── Quest-items/
└── Quests/
    ├── Completed-quests/
    ├── Current-campaign-goals/
    ├── Notes/
    └── Side-quests/
```

## Of Note

I built this for my character - Yarpen (a cleric). You'll find that there may be some hard-coded filters that search for cleric spells, or handle cleric specific class features. I will work on a system that makes this more flexible and intuitive to use... eventually!

## Adding Spell Sources

My spell source files were ripped from an install of Aurora (a windows DnD character builder), although I'm sure that the XML's are more of a universal digital format for DnD information, which I'll leave to you to find - that's not my work to publish and share in this repo. Once aquired, place the XML spell source files into `~/DnD/Spells/spell-source/`. These are used to import spells into your spell book via the **Add spells** menu option, and to browse available spells.

## Editing Your Character

Edit `~/DnD/stats.json` directly to set up your character's starting stats. Mine is included as a basis for your character and how to interface with the companion:

```json
{
    "hp": {
        "current": 17,
        "max": 17,
        "hit_die": "d8",
        "hit_dice": 3,
        "hit_dice_max": 3
    },
    "spell_slots": {
        "first":  { "level": 1, "current": 4, "max": 4 },
        "second": { "level": 2, "current": 2, "max": 2 }
    },
    "channel_divinity": { "current": 1, "max": 1 },
    "coin": { "copper": 0, "silver": 0, "gold": 0 }
}
```
