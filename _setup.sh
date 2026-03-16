#!/bin/bash

REPO="https://raw.githubusercontent.com/Galoose/DnD_terminal_companion/main"
INSTALL_DIR="$HOME/DnD"

REQUIRED_COMMANDS=("xmllint" "jq" "dialog" "tac")
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
    mkdir $INSTALL_DIR
    echo "Made directory \"$INSTALL_DIR\"."

    cd ~/DnD

    mkdir -p $INSTALL_DIR/Spells/spell-source \
        ./Quests/{Notes,Completed-quests,Side-quests,Current-campaign-goals} \
        ./Items/{Monster-loot,Adventuring-gear,Quest-items,Magic-items}

    echo "Made following directories in $INSTALL_DIR:"
    find . -type d

    read -n 1 -p "Proceed with code download? (y/N) " choice
    echo ""
    if [[ "$choice" == "y" ]] || [[ "$choice" == "Y" ]]; then
        # download main script
        echo "Downloading dnd.sh..."
        if curl -fSL "$REPO/dnd.sh" -o "$INSTALL_DIR/dnd.sh"; then
            chmod +x "$INSTALL_DIR/dnd.sh"
            echo "  dnd.sh downloaded"
        else
            echo "  Failed to download dnd.sh"
            exit 1
        fi

        # download stats.json if it doesn't already exist
        if [[ ! -f "$INSTALL_DIR/stats.json" ]]; then
            echo "Downloading stats.json..."
            if curl -fSL "$REPO/stats.json" -o "$INSTALL_DIR/stats.json"; then
                echo "  stats.json downloaded"
            else
                echo "  Failed to download stats.json"
                exit 1
            fi
        else
            echo "  stats.json already exists, skipping"
        fi

        # create empty spell list
        touch "$INSTALL_DIR/Spells/spell_list.txt"
    else
        echo "Download cancelled."
        exit 1
    fi
else
    echo "Setup cancelled."
    exit 1
fi

echo "  Installation complete!"
echo ""
echo "  Run with:"
echo "    cd $INSTALL_DIR && bash dnd.sh"
echo ""
echo "  Optionally add to PATH:"
echo "    echo 'alias dnd=\"cd $INSTALL_DIR && bash dnd.sh\"' >> ~/.bashrc"
echo "    source ~/.bashrc"
