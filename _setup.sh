#!/bin/bash

REQUIRED_COMMANDS=("xmllint" "jq" "dialog")
MISSING_DEPS=0

echo "Checking dependencies..."

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Missing: '$cmd' needs to be installed."
        MISSING_DEPS=1
    else
        echo "Checked: '$cmd'"
    fi
done

if [[ "$MISSING_DEPS" -eq 1 ]]; then
    echo "Please install the missing dependencies and rerun the script."
    read -p "Press any key to exit..."
    exit 1
else
    echo "All required dependencies are installed. Proceeding with script execution."
fi

read -n 1 -p "Proceed with directory setup? (y/N) " answer
echo "" # Add a newline after the input
if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
    mkdir ~/DnD
    echo "Made directory \"~/DnD\"."

    cd ~/DnD

    mkdir -p ./Spells/spell-source \
        ./Quests/{Notes,Completed-quests,Side-quests,Current-campaign-goals} \
        ./Items/{Monster-loot,Adventuring-gear,Quest-items,Magic-items}

    echo "Made following directories in ~/DnD:"
    find . -type d
    read -p "Installation complete! Press any key to exit..."
else
    echo "Setup cancelled."
    read -p "Press any key to exit..."
fi

