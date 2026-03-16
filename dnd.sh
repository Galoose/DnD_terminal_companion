#!/bin/bash

edit_stats() {
    local filter="$1"
    local val="$2"
    jq --argjson val "$val" "$filter" stats.json > /tmp/stats.tmp && mv /tmp/stats.tmp stats.json
}

build_spell() {
    local query="$1"
    local xml_file="$2"

    # strip everything except letters, numbers and spaces, then lowercase
    local clean_query=$(echo "$query" | tr -cd '[:alnum:] ' | tr '[:upper:]' '[:lower:]')

    # find all element names, clean them the same way, then match
    local name=$(xmllint --xpath "//element/@name" "$xml_file" 2>/dev/null \
        | grep -o '"[^"]*"' \
        | tr -d '"' \
        | while IFS= read -r n; do
            clean_n=$(echo "$n" | tr -cd '[:alnum:] ' | tr '[:upper:]' '[:lower:]')
            [[ "$clean_n" == *"$clean_query"* ]] && echo "$n" && break
        done)

    if [ -z "$name" ]; then
        return 1
    fi

    # extract each field using xmllint xpath
    local supports=$(xmllint --xpath "string(//element[@name='$name']/supports)" "$xml_file" 2>/dev/null)
    local level=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='level'])" "$xml_file" 2>/dev/null)
    local school=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='school'])" "$xml_file" 2>/dev/null)
    local time=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='time'])" "$xml_file" 2>/dev/null)
    local duration=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='duration'])" "$xml_file" 2>/dev/null)
    local range=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='range'])" "$xml_file" 2>/dev/null)
    local concentration=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='isConcentration'])" "$xml_file" 2>/dev/null)
    local ritual=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='isRitual'])" "$xml_file" 2>/dev/null)
    local material=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='materialComponent'])" "$xml_file" 2>/dev/null)

    # description - concatenate all <p> tags
    local description=$(xmllint --xpath "//element[@name='$name']/description/p/text()" "$xml_file" 2>/dev/null | tr -s ' \n\t' ' ' | sed 's/^ //;s/ $//')

    # build json
    jq -n \
        --arg name "$name" \
        --arg supports "$supports" \
        --arg level "$level" \
        --arg school "$school" \
        --arg time "$time" \
        --arg duration "$duration" \
        --arg range "$range" \
        --arg concentration "$concentration" \
        --arg ritual "$ritual" \
        --arg material "$material" \
        --arg description "$description" \
        '{
            name: $name,
            supports: $supports,
            level: $level,
            school: $school,
            time: $time,
            duration: $duration,
            range: $range,
            concentration: $concentration,
            ritual: $ritual,
            material: $material,
            description: $description
        }'
}

view_spells() {

    local CHOSEN_ITEM="$1"

    CUR_DIR="Spells"

    TITLE=$CHOSEN_ITEM

    CHOSEN_ITEM="${CHOSEN_ITEM//"Channel Divinity: "}"
    CHOSEN_ITEM="${CHOSEN_ITEM//\"/}"
    CHOSEN_ITEM="${CHOSEN_ITEM,,}"
    CHOSEN_ITEM="${CHOSEN_ITEM//[^[:alnum:] ]/}"

    FILE="$CUR_DIR/${CHOSEN_ITEM// /-}.json"

    context=$(jq -r '
        del(.name, .supports, .school, .category) |
        to_entries[] |
        "\(.key): \(.value)"
    ' "$FILE" | sed 's/./\u&/')

    cast_cost=$(jq -r '.level' "$FILE")
    if [[ -n "$cast_cost" ]] && (( cast_cost == 0 )); then
        dialog --title "$TITLE" \
            --cr-wrap \
            --msgbox "$context" 30 80
        return 1
    else
        if dialog --title "$TITLE" \
            --cr-wrap \
            --yes-label "Cast" \
            --no-label "Back" \
            --yesno "$context" 30 80; then
            #cast
            if [[ -n "$cast_cost" ]]; then
                current=$(jq -r --argjson lvl "$cast_cost" '.spell_slots | to_entries[] | select(.value.level == $lvl) | .value.current' stats.json)
                if (( current > 0 )); then
                    (( current-=1 ))
                    jq --argjson lvl "$cast_cost" --argjson val "$current" '
                        .spell_slots |= with_entries(
                            if .value.level == $lvl then .value.current = $val else . end
                        )
                    ' stats.json > /tmp/stats.tmp && mv /tmp/stats.tmp stats.json
                    dialog --title "Casting spell!" --cr-wrap --msgbox "You cast $TITLE!" 8 78
                else
                    dialog --title "Out of mana!" --cr-wrap --msgbox "You're out of level $cast_cost spell slots! You can't cast this!" 8 78
                    return 1
                fi
            else
                current=$(jq -r '.channel_divinity.current' stats.json)
                if (( current > 0 )); then
                    (( current-=1 ))
                    edit_stats '.channel_divinity.current = $val' $current
                    dialog --title "Casting spell!" --cr-wrap --msgbox "You cast $TITLE!" 8 78
                else
                    dialog --title "Out of divinity!" --cr-wrap --msgbox "You're out of favour! You can't channel divinity!" 8 78
                    return 1
                fi
            fi
        else
            return 1
        fi
    fi
}

view_spell_raw() {
    local name="$1"
    local xml_file="$2"

    local level=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='level'])" "$xml_file" 2>/dev/null)
    local school=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='school'])" "$xml_file" 2>/dev/null)
    local time=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='time'])" "$xml_file" 2>/dev/null)
    local duration=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='duration'])" "$xml_file" 2>/dev/null)
    local range=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='range'])" "$xml_file" 2>/dev/null)
    local concentration=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='isConcentration'])" "$xml_file" 2>/dev/null)
    local ritual=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='isRitual'])" "$xml_file" 2>/dev/null)
    local material=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='materialComponent'])" "$xml_file" 2>/dev/null)
    local description=$(xmllint --xpath "//element[@name='$name']/description/p/text()" "$xml_file" 2>/dev/null | tr -s ' \n\t' ' ' | sed 's/^ //;s/ $//')

    local context=$(printf "Level: %s\nSchool: %s\nTime: %s\nDuration: %s\nRange: %s\nConcentration: %s\nRitual: %s\nMaterial: %s\n\n%s" \
        "$level" "$school" "$time" "$duration" "$range" "$concentration" "$ritual" "$material" "$description")

    dialog --title "$name" \
        --cr-wrap \
        --msgbox "$context" 30 80
}

filter_spell() {

    local queries="$1"

    SPELL_LINES=()

    # loop files, check each against ALL queries
    while IFS= read -r -d $'\0' file; do
        jq empty "$file" 2>/dev/null || continue

        # flatten all fields to one searchable string
        all_fields=$(jq -r '[.. | strings] | join(" ")' "$file" | tr -cd '[:alnum:] ' | tr '[:upper:]' '[:lower:]')

        # check every query matches
        all_match=1
        if [[ "$all_fields" != *"$queries"* ]]; then
            all_match=0
        fi

        if (( all_match )); then
            name=$(jq -r '.name // ""' "$file")
            school=$(jq -r '.school // ""' "$file")
            level=$(jq -r '.level // ""' "$file")
            summary="lvl ${level} : ${school}"
            SPELL_LINES+=("${level}|${name}|${summary}")
        fi

    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.json" -print0)

    SPELLS=()
    while IFS='|' read -r level name summary; do
        SPELLS+=("$name" "$summary")
    done < <(printf '%s\n' "${SPELL_LINES[@]}" | sort -t'|' -k1 -n)

    while true; do
        CHOSEN_ITEM=$(dialog --title "Search results" \
            --ok-label "Select" \
            --cancel-label "Back" \
            --menu "Choose a spell:" 25 78 10 \
            "${SPELLS[@]}" \
            3>&1 1>&2 2>&3) || break
        
        view_spells "$CHOSEN_ITEM" || continue
        break
    done
}

# important info, status effects, links to other menus
main_menu() {
    while true; do
        copper=$(jq '.coin.copper' stats.json)
        silver=$(jq '.coin.silver' stats.json)
        gold=$(jq '.coin.gold' stats.json)
        hp_curr=$(jq '.hp.current' stats.json)
        hp_max=$(jq '.hp.max' stats.json)
        channel_divinity_curr=$(jq '.channel_divinity.current' stats.json)
        channel_divinity_max=$(jq '.channel_divinity.max' stats.json)

        coin=$(( $copper / 100 + $silver / 10 + $gold ))

        spell_levels=()
        mana_string="Mana: "
        while IFS= read -r s_level; do
            lvl_name=$(echo "$s_level" | jq -r '.key')
            lvl_max=""
            lvl_curr=""
            while IFS= read -r lvl_deets; do
                lvl_deet=$(echo "$lvl_deets" | jq -r '.key')
                lvl_val=$(echo "$lvl_deets" | jq -r '.value')
                spell_levels+=("$lvl_name" "$lvl_deet" "$lvl_val")
                case $lvl_deet in
                    "max")     lvl_max="$lvl_val" ;;
                    "current") lvl_curr="$lvl_val" ;;
                esac
            done < <(echo "$s_level" | jq -c '.value | to_entries[]')
            mana_string+="${lvl_name^} $lvl_curr/$lvl_max | "
        done < <(jq -c '.spell_slots | to_entries[]' stats.json)

        context=$(printf "Coin: %sc %ss %sg | Total: %sg\nHealth: %s/%s\n%s\nChannel divinity: %s/%s" \
            "$copper" "$silver" "$gold" "$coin" \
            "$hp_curr" "$hp_max" \
            "${mana_string% | }" \
            "$channel_divinity_curr" "$channel_divinity_max")
        CHOICE=$(dialog --title "Yarpen - DnD" \
            --ok-label "Select" \
            --cancel-label "Quit" \
            --menu "$context" 25 78 5 \
            "Combat" "Engage in combat" \
            "Spell book" "Peruse your spells" \
            "Backpack" "Look inside your backpack" \
            "Quest log" "Campaign notes and quests" \
            "Rest" "Regain health and mana" \
            3>&1 1>&2 2>&3) || break

        case $CHOICE in
            "Combat") combat_menu ;;
            "Spell book") spell_menu ;;
            "Backpack") items_menu ;;
            "Quest log") quests_menu ;;
            "Rest") rest_menu ;;
        esac
    done
    kill $PPID
}

# entering combat
combat_menu() {
    # text box, initiative +0 !
    # combat menu
    # move 30ft, fly 40ft (if dark)
    dialog --title "Entering combat, roll initiative!" --cr-wrap --msgbox "Your initiative bonus is +0, roll a d20." 8 78

    while true; do
        CUR_DIR="Spells"
            hp_curr=$(jq '.hp.current' stats.json)
            hp_max=$(jq '.hp.max' stats.json)
            channel_divinity_curr=$(jq '.channel_divinity.current' stats.json)
            channel_divinity_max=$(jq '.channel_divinity.max' stats.json)
            spell_levels=()
            mana_string="Mana: "
            while IFS= read -r s_level; do
                lvl_name=$(echo "$s_level" | jq -r '.key')
                lvl_max=""
                lvl_curr=""
                while IFS= read -r lvl_deets; do
                    lvl_deet=$(echo "$lvl_deets" | jq -r '.key')
                    lvl_val=$(echo "$lvl_deets" | jq -r '.value')
                    spell_levels+=("$lvl_name" "$lvl_deet" "$lvl_val")
                    case $lvl_deet in
                        "max")     lvl_max="$lvl_val" ;;
                        "current") lvl_curr="$lvl_val" ;;
                    esac
                done < <(echo "$s_level" | jq -c '.value | to_entries[]')
                mana_string+="${lvl_name^} $lvl_curr/$lvl_max | "
            done < <(jq -c '.spell_slots | to_entries[]' stats.json)

        context=$(printf "Health: %s/%s\n%s\nChannel divinity: %s/%s" \
            "$hp_curr" "$hp_max" \
            "${mana_string% | }" \
            "$channel_divinity_curr" "$channel_divinity_max")
        menu=("Reaction" "Quickly counter their move!" \
            "Action" "What will you do?" \
            "Bonus action" "Opportunity!" \
            "Adjust health" "Record injuries and damage" \
            "Spellbook" "Open and find a spell!")
        CHOICE=$(dialog --title "Combat menu" \
            --ok-label "Select" \
            --cancel-label "Back" \
            --menu "$context" 25 78 5 \
            "${menu[@]}" \
            3>&1 1>&2 2>&3) || break

        case $CHOICE in
            "Reaction")
                while true; do
                    context="A reaction is an instant response to a trigger of some kind, which can occur on your turn or on someone else's."
                    menu=("Opportunity attack" "Enemy leaves your reach" \
                        "Cast spell" "Cast time of 1 reaction")
                    MOVE=$(dialog --title "Reaction" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "$context" 25 78 5 \
                        "${menu[@]}" \
                        3>&1 1>&2 2>&3) || break
                    case $MOVE in
                        "Opportunity attack")
                            break
                        ;;
                        "Cast spell")
                            filter_spell "reaction" || continue
                        ;;
                    esac
                done
            ;;
            "Action")
                while true; do
                    context="You can also interact with one object or feature of the environment for free."
                    menu=("Attack" "Melee or ranged attack" \
                        "Cast spell" "Cast time of 1 action" \
                        "Dash" "Double movement speed" \
                        "Disengage" "Prevent opportunity attacks" \
                        "Dodge" "Increase defenses" \
                        "Help" "Grant an ally advantage")
                    MOVE=$(dialog --title "Action" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "$context" 25 78 5 \
                        "${menu[@]}" \
                        3>&1 1>&2 2>&3) || break
                    case $MOVE in
                        "Cast spell")
                            filter_spell "1 action" || continue
                            break
                        ;;
                        "Attack")
                            while true; do
                                context="Choose your method of melee attack."
                                menu=("Weapon 1" "xyz" \
                                    "Weapon 2" "xyz" \
                                    "Grapple" "Special melee attack" \
                                    "Shove" "Special melee attack")
                                ATTACK=$(dialog --title "Action" \
                                    --ok-label "Select" \
                                    --cancel-label "Back" \
                                    --menu "$context" 25 78 5 \
                                    "${menu[@]}" \
                                    3>&1 1>&2 2>&3) || break
                            done
                        ;;
                        *)
                            break
                        ;;
                    esac
                done
            ;;
            "Bonus action")
                while true; do
                    context="You can take a bonus action only when a special ability, spell, or feature states that you can do something as a bonus action."
                    menu=("Cast spell" "Cast time of 1 bonus action")
                    MOVE=$(dialog --title "Bonus Action" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "$context" 25 78 5 \
                        "${menu[@]}" \
                        3>&1 1>&2 2>&3) || break
                    case $MOVE in
                        "Cast spell")
                            while true; do
                                filter_spell "bonus action" || continue
                                break
                            done
                        ;;
                    esac
                done
            ;;
            "Adjust health")
                hp_curr=$(jq '.hp.current' stats.json)
                lost_health=$(dialog --title "Taking damage..." --inputbox "Enter health lost:" 8 39 "" 3>&1 1>&2 2>&3) || continue
                if (( hp_curr - lost_health <= 0 )); then
                    (( hp_curr = 0 ))
                    dialog --title "Knocked out!" --cr-wrap --msgbox "You have no health left and are knocked out!" 9 78
                else
                    (( hp_curr -= lost_health ))
                    dialog --title "Health lost!" --cr-wrap --msgbox "You have ${hp_curr}hp left!" 9 78
                fi
                edit_stats '.hp.current = $val' $hp_curr
            ;;
            "Spellbook")
                spell_menu 1
            ;;
        esac
    done
}

# spells
spell_menu() {

    local altmenu=$1
    while true; do
        CUR_DIR="Spells"
        channel_divinity_curr=$(jq '.channel_divinity.current' stats.json)
        channel_divinity_max=$(jq '.channel_divinity.max' stats.json)
        spell_levels=()
        mana_string="Mana: "
        while IFS= read -r s_level; do
            lvl_name=$(echo "$s_level" | jq -r '.key')
            lvl_max=""
            lvl_curr=""
            while IFS= read -r lvl_deets; do
                lvl_deet=$(echo "$lvl_deets" | jq -r '.key')
                lvl_val=$(echo "$lvl_deets" | jq -r '.value')
                spell_levels+=("$lvl_name" "$lvl_deet" "$lvl_val")
                case $lvl_deet in
                    "max")     lvl_max="$lvl_val" ;;
                    "current") lvl_curr="$lvl_val" ;;
                esac
            done < <(echo "$s_level" | jq -c '.value | to_entries[]')
            mana_string+="${lvl_name^} $lvl_curr/$lvl_max | "
        done < <(jq -c '.spell_slots | to_entries[]' stats.json)

        context=$(printf "%s\nChannel divinity: %s/%s" \
            "${mana_string% | }" \
            "$channel_divinity_curr" "$channel_divinity_max")
        menu=("Cantrips" "Basic spells you can reuse anytime" \
            "Healing" "Perform medical care" \
            "Attack" "Retaliate against attack" \
            "Combat utility" "Magically alter battles" \
            "Other" "Spells for the traveller" \
            "Search spells" "Find all spells matching a search")
        [[ -n $altmenu ]] || menu+=("Add spells" "Add new spells to your book" "Spell library" "Browse all cleric spells from source")
        CHOICE=$(dialog --title "Spell book" \
            --ok-label "Select" \
            --cancel-label "Back" \
            --menu "$context" 25 78 5 \
            "${menu[@]}" \
            3>&1 1>&2 2>&3) || break

        case $CHOICE in
            "Search spells")
                while true; do
                    dialog --title "Search for a spell" --editbox "/tmp/tmp_query.txt" 30 80 2>"/tmp/tmp_query.txt" || break

                    # collect all non-empty query terms first
                    queries=()
                    while read -r query; do
                        [[ -z "$query" ]] && continue
                        clean=$(echo "$query" | tr -cd '[:alnum:] ' | tr '[:upper:]' '[:lower:]')
                        [[ -n "$clean" ]] && queries+=("$clean")
                    done < /tmp/tmp_query.txt

                    SPELL_LINES=()

                    # loop files, check each against ALL queries
                    while IFS= read -r -d $'\0' file; do
                        jq empty "$file" 2>/dev/null || continue

                        # flatten all fields to one searchable string
                        all_fields=$(jq -r '[.. | strings] | join(" ")' "$file" | tr -cd '[:alnum:] ' | tr '[:upper:]' '[:lower:]')

                        # check every query matches
                        all_match=1
                        for q in "${queries[@]}"; do
                            if [[ "$all_fields" != *"$q"* ]]; then
                                all_match=0
                                break
                            fi
                        done

                        if (( all_match )); then
                            name=$(jq -r '.name // ""' "$file")
                            school=$(jq -r '.school // ""' "$file")
                            level=$(jq -r '.level // ""' "$file")
                            summary="lvl ${level} : ${school}"
                            SPELL_LINES+=("${level}|${name}|${summary}")
                        fi

                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.json" -print0)

                    if [[ ${#SPELL_LINES[@]} -eq 0 ]]; then
                        dialog --title "No spells!" --msgbox "No spells were found matching your search!" 8 78
                        break
                    fi

                    SPELLS=()
                    while IFS='|' read -r level name summary; do
                        SPELLS+=("$name" "$summary")
                    done < <(printf '%s\n' "${SPELL_LINES[@]}" | sort -t'|' -k1 -n)

                    while true; do
                        CHOSEN_ITEM=$(dialog --title "Search results" \
                            --ok-label "Select" \
                            --cancel-label "Back" \
                            --menu "Choose a spell:" 25 78 10 \
                            "${SPELLS[@]}" \
                            3>&1 1>&2 2>&3) || break
                        
                        view_spells "$CHOSEN_ITEM" || continue
                        break
                    done
                    break
                done
            ;;
            "Add spells")
                while true; do
                    CONTENT=$(cat $CUR_DIR/spell_list.txt)
                    echo "$CONTENT" > "/tmp/input.txt"

                    dialog --title "Edit list of spells" --editbox "/tmp/input.txt" 30 80 2>"$CUR_DIR/spell_list.txt" || { echo "$CONTENT" > "$CUR_DIR/spell_list.txt"; break; }

                    while read -r line; do
                        [[ -f "$CUR_DIR/${line// /-}.json" ]] && continue
                        # loop through files in spell-source directory
                        found=0
                        while IFS= read -r -d $'\0' file; do
                            if build_spell "$line" "$file" > "$CUR_DIR/${line// /-}.json"; then
                                # make user choose a category for the spell!
                                while true; do
                                    CATEGORY=$(dialog --title "${line^}" \
                                        --ok-label "Select" \
                                        --cancel-label "Back" \
                                        --menu "Choose spell category for $line:" 15 78 5 \
                                        "Cantrips" "Basic spells you can reuse anytime" \
                                        "Healing" "Perform medical care" \
                                        "Attack" "Retaliate against attack" \
                                        "Combat utility" "Magically alter battles" \
                                        "Other" "Spells for the traveller" \
                                        3>&1 1>&2 2>&3) || continue
                                    break
                                done
                                jq --arg val "$CATEGORY" '.category = $val' "$CUR_DIR/${line// /-}.json" > /tmp/tmp.json && mv /tmp/tmp.json "$CUR_DIR/${line// /-}.json"
                                dialog --title "Adding spell!" --cr-wrap --msgbox "The spell \"${line}\" has been added to $CATEGORY!" 8 78
                                found=1
                                break
                            fi
                        done < <(find "$CUR_DIR/spell-source" -mindepth 1 -maxdepth 1 -type f -print0)

                        if (( found == 0 )); then
                            rm -f "$CUR_DIR/${line// /-}.json"
                        fi
                    done < $CUR_DIR/spell_list.txt

                    dialog --title "Spell list" \
                        --cr-wrap \
                        --msgbox "$CONTENT" 30 80

                    break
                done
            ;;
            "Spell library")
                while true; do
                    # build cache if not already built
                    if [[ -z "${CLERIC_CACHE+x}" ]]; then
                        dialog --title "Loading..." --infobox "Loading cleric spells from source files..." 5 50

                        CLERIC_CACHE=()
                        while IFS= read -r -d $'\0' file; do
                            while IFS= read -r name; do
                                [[ -z "$name" ]] && continue
                                level=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='level'])" "$file" 2>/dev/null)
                                school=$(xmllint --xpath "string(//element[@name='$name']/setters/set[@name='school'])" "$file" 2>/dev/null)
                                CLERIC_CACHE+=("${level}|${name}|${file}|${school}")
                            done < <(xmllint --xpath "//element[contains(supports,'Cleric')]/@name" "$file" 2>/dev/null \
                                | grep -o '"[^"]*"' \
                                | tr -d '"')
                        done < <(find "$CUR_DIR/spell-source" -mindepth 1 -maxdepth 1 -type f -print0)
                    fi

                    # pick a level to browse
                    LEVEL_CHOICE=$(dialog --title "Cleric spells" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose a spell level:" 20 78 10 \
                        "All"  "Browse all cleric spells" \
                        "0"    "Cantrips" \
                        "1"    "Level 1" \
                        "2"    "Level 2" \
                        "3"    "Level 3" \
                        "4"    "Level 4" \
                        "5"    "Level 5" \
                        "6"    "Level 6" \
                        "7"    "Level 7" \
                        "8"    "Level 8" \
                        "9"    "Level 9" \
                        3>&1 1>&2 2>&3) || break

                    while true; do
                        # filter cache by chosen level
                        SPELL_LINES=()
                        for entry in "${CLERIC_CACHE[@]}"; do
                            IFS='|' read -r level name file school <<< "$entry"
                            [[ "$LEVEL_CHOICE" == "All" ]] || [[ "$level" == "$LEVEL_CHOICE" ]] || continue
                            summary="lvl ${level} : ${school}"
                            SPELL_LINES+=("${level}|${name}|${file}|${summary}")
                        done

                        SPELLS=()
                        while IFS='|' read -r level name file summary; do
                            SPELLS+=("$name" "$summary")
                        done < <(printf '%s\n' "${SPELL_LINES[@]}" | sort -t'|' -k1 -n)

                        if [[ ${#SPELLS[@]} -eq 0 ]]; then
                            dialog --title "No spells!" --msgbox "No cleric spells found for level $LEVEL_CHOICE." 8 78
                            break
                        fi

                        CHOSEN_ITEM=$(dialog --title "Cleric spells - Level $LEVEL_CHOICE" \
                            --ok-label "Select" \
                            --cancel-label "Back" \
                            --menu "Browse cleric spells:" 25 78 10 \
                            "${SPELLS[@]}" \
                            3>&1 1>&2 2>&3) || break

                        # find source file from cache
                        source_file=""
                        for entry in "${SPELL_LINES[@]}"; do
                            IFS='|' read -r lvl n f s <<< "$entry"
                            if [[ "$n" == "$CHOSEN_ITEM" ]]; then
                                source_file="$f"
                                break
                            fi
                        done

                        view_spell_raw "$CHOSEN_ITEM" "$source_file"
                    done
                done
            ;;
            *) 
                while true; do
                    SPELLS_LINES=()
                    while IFS= read -r -d $'\0' file; do
                        category=$(jq -r '.category' "$file")
                        if [[ $category == $CHOICE ]]; then
                            name=$(jq -r '.name' "$file")
                            school=$(jq -r '.school' "$file")
                            level=$(jq -r '.level' "$file")
                            summary="lvl ${level} : ${school}"
                            SPELLS_LINES+=("${level}|${name}|${summary}")
                        fi
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.json" -print0)

                    SPELLS=()
                    # sort by level (first field)
                    while IFS='|' read -r level name summary; do
                        SPELLS+=("$name" "$summary")
                    done < <(printf '%s\n' "${SPELLS_LINES[@]}" | sort -t'|' -k1 -n)

                    CHOSEN_ITEM=$(dialog --title "$CHOICE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Inspect a spell:" 25 78 5 \
                        "${SPELLS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break

                    view_spells "$CHOSEN_ITEM" || continue
                    break
                done
            ;;
        esac
    done
}

# quest items, magic items, valuables, treasure
items_menu() {
    # gold spending menu using dialog --form
    while true; do
        CUR_DIR="Items"

        ITEMS=()
        while IFS= read -r -d $'\0' entry; do
            name=$(basename "$entry")
            desc=$(ls -1 "$entry" | wc -l)
            ITEMS+=("${name}" "$desc entries")
        done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
        
        CHOICE=$(dialog --title "Backpack" \
            --ok-label "Select" \
            --cancel-label "Back" \
            --menu "" 25 78 5 \
            "${ITEMS[@]//-/ }" \
            "New item" "Add a new item into any pocket" \
            "Edit item" "Edit any existing item" \
            "Move item" "Move an item into another pocket" \
            "Remove item" "Remove an item from your inventory" \
            "Update coin" "Record transactions and purchases" \
            3>&1 1>&2 2>&3) || return

        case $CHOICE in
            "New item")
                ENTRY_TYPE=""
                ENTRY_NAME=""
                ENTRY_DESC=""
                while true; do
                    TITLE="New item..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        ITEMS+=("$name" "")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose journal type:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break

                    ENTRY_NAME=$(dialog --title "$TITLE" --inputbox "Item name:" 8 39 "$ENTRY_NAME" 3>&1 1>&2 2>&3) || continue

                    ENTRY_DESC=$(dialog --title "$TITLE" --inputbox "Item summary:" 8 39 "$ENTRY_DESC" 3>&1 1>&2 2>&3) || continue

                    echo "" > "/tmp/input.txt"

                    ENTRY_BODY=$(dialog --title "$TITLE" --editbox "/tmp/input.txt" 30 80 3>&1 1>&2 2>&3) || continue

                    jq -n \
                        --arg summary "$ENTRY_DESC" \
                        --arg body    "$ENTRY_BODY" \
                        '{"summary": $summary, "body": $body}' > $CUR_DIR/${ENTRY_TYPE// /-}/${ENTRY_NAME// /-}.json
                    break
                done
            ;;
            "Edit item")
                while true; do
                    TITLE="Edit item details..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        desc=$(ls -1 "$entry" | wc -l)
                        ITEMS+=("$name" "$desc entries")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose pocket to enter:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break
                    
                    POCKET_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        POCKET_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${ENTRY_TYPE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "Editing in $ENTRY_TYPE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item to edit:" 18 78 10 \
                        "${POCKET_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue
                    
                    SUMMARY=$(jq -r '.summary' $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json)
                    ENTRY_DESC=$(dialog --title "$TITLE" --inputbox "Item summary:" 8 39 "$SUMMARY" 3>&1 1>&2 2>&3) || continue

                    CONTENT=$(jq -r '.body' $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json)
                    echo "$CONTENT" > "/tmp/input.txt"

                    ENTRY_BODY=$(dialog --title "$TITLE" --editbox "/tmp/input.txt" 30 80 3>&1 1>&2 2>&3) || continue

                    jq -n \
                        --arg summary "$ENTRY_DESC" \
                        --arg body    "$ENTRY_BODY" \
                        '{"summary": $summary, "body": $body}' > $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json

                    dialog --title "$CHOSEN_ITEM" \
                        --cr-wrap \
                        --msgbox "$CONTENT" 30 80

                    break
                done
            ;;
            "Move item")
                while true; do
                    TITLE="Move item..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        desc=$(ls -1 "$entry" | wc -l)
                        ITEMS+=("$name" "$desc entries")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose pocket to move from:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break
                    
                    POCKET_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        POCKET_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${ENTRY_TYPE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "Moving from $ENTRY_TYPE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item to move:" 18 78 10 \
                        "${POCKET_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue

                    MOVE_LOC=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        MOVE_LOC+=("$name" "")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
                    
                    NEW_LOCATION=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose pocket to move to:" 12 78 4 \
                        "${MOVE_LOC[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue

                    mv $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json $CUR_DIR/${NEW_LOCATION// /-}
                    dialog --title "Moving item!" --cr-wrap --msgbox "Item $CHOSEN_ITEM moved from $ENTRY_TYPE to $NEW_LOCATION!" 8 78
                    break
                done
            ;;
            "Remove item")
                while true; do
                    TITLE="Remove item..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        desc=$(ls -1 "$entry" | wc -l)
                        ITEMS+=("$name" "$desc entries")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose pocket to remove from:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break
                    
                    POCKET_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        POCKET_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${ENTRY_TYPE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "Removing from $ENTRY_TYPE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item to remove:" 18 78 10 \
                        "${POCKET_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue

                    if dialog --title "Removing $CHOSEN_ITEM from $ENTRY_TYPE" --yesno "Are you sure?" 8 78; then
                        rm $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json
                    else 
                        break
                    fi

                done
            ;;
            "Update coin")
                while true; do
                    copper=$(jq '.coin.copper' stats.json)
                    silver=$(jq '.coin.silver' stats.json)
                    gold=$(jq '.coin.gold' stats.json)
                    coin=$(( $copper / 100 + $silver / 10 + $gold ))
                    context=$(printf "Coin: %sc %ss %sg | Total: %sg" \
                        "$copper" "$silver" "$gold" "$coin")
                    menu=("Income" "Record earned money" \
                        "Outgoing" "Record spent money")
                    MONEY=$(dialog --title "Combat menu" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "$context" 25 78 5 \
                        "${menu[@]}" \
                        3>&1 1>&2 2>&3) || break

                    case $MONEY in
                        *)
                            exec 3>&1
                            form_output=$(dialog --title "Transfer details" \
                                --ok-label "Confirm" \
                                --cancel-label "Back" \
                                --form "Enter coin value amounts being transferred:" 12 40 3 \
                                "Gold:"   1 1 "" 1 10 10 0 \
                                "Silver:" 2 1 "" 2 10 10 0 \
                                "Copper:" 3 1 "" 3 10 10 0 \
                                2>&1 1>&3)
                            exec 3>&-

                            [ $? -ne 0 ] && continue

                            # parse the three lines of output
                            dx_gold=$(echo "$form_output" | sed -n '1p')
                            dx_silver=$(echo "$form_output" | sed -n '2p')
                            dx_copper=$(echo "$form_output" | sed -n '3p')

                            if [[ $MONEY == "Income" ]]; then
                                (( gold += dx_gold ))
                                (( silver += dx_silver ))
                                (( copper += dx_copper ))
                            else
                                (( gold -= dx_gold ))
                                (( silver -= dx_silver ))
                                (( copper -= dx_copper ))
                            fi
                            edit_stats '.coin.gold = $val' $gold
                            edit_stats '.coin.silver = $val' $silver
                            edit_stats '.coin.copper = $val' $copper
                            dialog --title "Transfer complete!" --cr-wrap --msgbox "Updated your balance!" 9 78
                            break
                        ;;
                    esac
                done
            ;;
            *)
                while true; do
                    POCKET_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        POCKET_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${CHOICE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "$CHOICE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item:" 18 78 10 \
                        "${POCKET_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break

                    CONTENT=$(jq -r '.body' $CUR_DIR/${CHOICE// /-}/${CHOSEN_ITEM// /-}.json)

                    dialog --title "$CHOSEN_ITEM" \
                        --cr-wrap \
                        --msgbox "$CONTENT" 30 80
                done
            ;;
        esac
    done
}

# campaign notes and current objectives
quests_menu() {
    while true; do
        CUR_DIR="Quests"

        QUESTS=()
        while IFS= read -r -d $'\0' entry; do
            name=$(basename "$entry")
            desc=$(ls -1 "$entry" | wc -l)
            QUESTS+=("${name}" "$desc entries")
        done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | tac --separator=$'\0')
        
        CHOICE=$(dialog --title "Quest log" \
            --ok-label "Select" \
            --cancel-label "Back" \
            --menu "" 25 78 5 \
            "${QUESTS[@]//-/ }" \
            "New entry" "Add a new entry into any journal" \
            "Edit entry" "Edit any existing journal entry" \
            "Move entry" "Move an entry into another journal" \
            3>&1 1>&2 2>&3) || return

        case $CHOICE in
            "New entry")
                ENTRY_TYPE=""
                ENTRY_NAME=""
                ENTRY_DESC=""
                while true; do
                    TITLE="New entry..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        ITEMS+=("$name" "")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | tac --separator=$'\0')
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose journal type:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break

                    ENTRY_NAME=$(dialog --title "$TITLE" --inputbox "Journal entry title:" 8 39 "$ENTRY_NAME" 3>&1 1>&2 2>&3) || continue

                    ENTRY_DESC=$(dialog --title "$TITLE" --inputbox "Journal summary:" 8 39 "$ENTRY_DESC" 3>&1 1>&2 2>&3) || continue

                    echo "" > "/tmp/input.txt"

                    ENTRY_BODY=$(dialog --title "$TITLE" --editbox "/tmp/input.txt" 30 80 3>&1 1>&2 2>&3) || continue

                    jq -n \
                        --arg summary "$ENTRY_DESC" \
                        --arg body    "$ENTRY_BODY" \
                        '{"summary": $summary, "body": $body}' > $CUR_DIR/${ENTRY_TYPE// /-}/${ENTRY_NAME// /-}.json
                    break
                done
            ;;
            "Edit entry")
                while true; do
                    TITLE="Edit journal entry..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        desc=$(ls -1 "$entry" | wc -l)
                        ITEMS+=("$name" "$desc entries")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | tac --separator=$'\0')
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose journal to edit:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break
                    
                    JOURNAL_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        JOURNAL_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${ENTRY_TYPE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "Editing in $ENTRY_TYPE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item to edit:" 18 78 10 \
                        "${JOURNAL_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue
                    
                    SUMMARY=$(jq -r '.summary' $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json)
                    ENTRY_DESC=$(dialog --title "$TITLE" --inputbox "Journal summary:" 8 39 "$SUMMARY" 3>&1 1>&2 2>&3) || continue

                    CONTENT=$(jq -r '.body' $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json)
                    echo "$CONTENT" > "/tmp/input.txt"

                    ENTRY_BODY=$(dialog --title "$TITLE" --editbox "/tmp/input.txt" 30 80 3>&1 1>&2 2>&3) || continue

                    jq -n \
                        --arg summary "$ENTRY_DESC" \
                        --arg body    "$ENTRY_BODY" \
                        '{"summary": $summary, "body": $body}' > $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json

                    dialog --title "$CHOSEN_ITEM" \
                        --cr-wrap \
                        --msgbox "$CONTENT" 30 80

                    break
                done
            ;;
            "Move entry")
                while true; do
                    TITLE="Move journal entry..."

                    ITEMS=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        desc=$(ls -1 "$entry" | wc -l)
                        ITEMS+=("$name" "$desc entries")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | tac --separator=$'\0')
                    
                    ENTRY_TYPE=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose journal to move from:" 12 78 4 \
                        "${ITEMS[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break
                    
                    JOURNAL_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        JOURNAL_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${ENTRY_TYPE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "Moving from $ENTRY_TYPE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item to move:" 18 78 10 \
                        "${JOURNAL_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue

                    MOVE_LOC=()
                    while IFS= read -r -d $'\0' entry; do
                        name=$(basename "$entry")
                        MOVE_LOC+=("$name" "")
                    done < <(find "$CUR_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | tac --separator=$'\0')
                    
                    NEW_LOCATION=$(dialog --title "$TITLE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose journal to move to:" 12 78 4 \
                        "${MOVE_LOC[@]//-/ }" \
                        3>&1 1>&2 2>&3) || continue

                    mv $CUR_DIR/${ENTRY_TYPE// /-}/${CHOSEN_ITEM// /-}.json $CUR_DIR/${NEW_LOCATION// /-}
                    dialog --title "Moving journal entry!" --cr-wrap --msgbox "Journal entry $CHOSEN_ITEM moved from $ENTRY_TYPE to $NEW_LOCATION!" 8 78
                    break
                done
            ;;
            *)
                while true; do
                    JOURNAL_ENTRIES=()
                    while IFS= read -r -d $'\0' file; do
                        name=$(basename "$file" .json)
                        summary=$(jq -r '.summary' $file)
                        JOURNAL_ENTRIES+=("${name}" "$summary")
                    done < <(find "$CUR_DIR/${CHOICE// /-}" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

                    CHOSEN_ITEM=$(dialog --title "$CHOICE" \
                        --ok-label "Select" \
                        --cancel-label "Back" \
                        --menu "Choose an item:" 18 78 10 \
                        "${JOURNAL_ENTRIES[@]//-/ }" \
                        3>&1 1>&2 2>&3) || break

                    CONTENT=$(jq -r '.body' $CUR_DIR/${CHOICE// /-}/${CHOSEN_ITEM// /-}.json)

                    dialog --title "$CHOSEN_ITEM" \
                        --cr-wrap \
                        --msgbox "$CONTENT" 30 80
                done
            ;;
        esac
    done
}

rest_menu() {
    while true; do
        hp_curr=$(jq '.hp.current' stats.json)
        hp_max=$(jq '.hp.max' stats.json)
        hit_die=$(jq -r '.hp.hit_die' stats.json)
        hit_die_max=$(jq '.hp.hit_dice_max' stats.json)
        hit_dice=$(jq '.hp.hit_dice' stats.json)
        channel_divinity_curr=$(jq '.channel_divinity.current' stats.json)
        channel_divinity_max=$(jq '.channel_divinity.max' stats.json)
        exhaustion=$(jq '.exhaustion' stats.json)
        context=$(printf "Hit dice: %s/%s\nExhaustion: %s" \
            "$hit_dice" "$hit_die_max" "$exhaustion")
        CHOICE=$(dialog --title "Rest" \
            --ok-label "Select" \
            --cancel-label "Back" \
            --menu "$context" 25 78 5 \
            "Short rest" "A quick rest of at least 1 hour" \
            "Long rest" "A deeply restorative rest of at least 8 hours" \
            3>&1 1>&2 2>&3) || return

        case $CHOICE in
            "Short rest")
                # short rest
                # channel divinity reset
                (( channel_divinity_curr = channel_divinity_max ))
                edit_stats '.channel_divinity.current = $val' $channel_divinity_curr
                # regain health using hit dice
                if (( hit_dice > 0 )); then 
                    used_die=$(dialog --title "Short resting..." --inputbox "You may use ${hit_dice}x${hit_die}... how many die to use:" 8 39 "" 3>&1 1>&2 2>&3) || continue
                    # if exceeding remaining dice, then we force break back to the rest menu
                    if (( $used_die > $hit_dice )); then
                        dialog --title "Cannot exceed maximum dice!" --cr-wrap --msgbox "You may not use a number of hit die exceeding your remaining amount!\nTry again!" 9 78
                        continue
                    fi
                    hp_gained=$(dialog --title "Short resting..." --inputbox "Using ${used_die}x${hit_die}... how much health regained:" 8 39 "" 3>&1 1>&2 2>&3) || continue
                    if (( hp_curr + hp_gained > hp_max )); then
                        hp_curr=$hp_max
                    else
                        (( hp_curr += hp_gained ))
                    fi
                    edit_stats '.hp.current = $val' $hp_curr
                    (( hit_dice -= used_die ))
                    edit_stats '.hp.hit_dice = $val' $hit_dice
                    dialog --title "Short resting!" --cr-wrap --msgbox "Used ${used_die}x${hit_die} to regain ${hp_gained}hp!\nChannel divinity restored!" 9 78
                else
                    dialog --title "Short resting!" --cr-wrap --msgbox "No hit die remain!\nChannel divinity restored!" 8 78
                fi
                break
            ;;
            "Long rest")
                # long rest
                # channel divinity reset
                (( channel_divinity_curr = channel_divinity_max ))
                edit_stats '.channel_divinity.current = $val' $channel_divinity_curr
                if (( exhaustion > 0 )); then
                    (( exhaustion -= 1 ))
                    edit_stats '.exhaustion = $val' $exhaustion
                fi
                # health reset
                edit_stats '.hp.current = $val' $hp_max
                if (( hit_dice + (hit_die_max + 1) / 2 <= hit_die_max)); then
                    (( hit_dice += (hit_die_max + 1) / 2 ))
                else
                    (( hit_dice = hit_die_max ))
                fi
                edit_stats '.hp.hit_dice = $val' $hit_dice
                # spell slot reset
                jq '.spell_slots |= with_entries(.value.current = .value.max)' stats.json > /tmp/stats.tmp && mv /tmp/stats.tmp stats.json
                dialog --title "Long resting!" --cr-wrap --msgbox "You now have ${hit_dice}x${hit_die} hit dice to use!\nChannel divinity restored!\nRegained spell slots!" 9 78
                break
            ;;
        esac
    done
}

main_menu