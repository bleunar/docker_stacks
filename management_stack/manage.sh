#!/bin/bash

# Ensure we are in the script's directory
cd "$(dirname "$0")"

BACKUP_DIR="./volume_backups"
mkdir -p "$BACKUP_DIR"

# Helper function to show messages
msg_box() {
    whiptail --title "$1" --msgbox "$2" 10 60
}

# Main Menu
while true; do
    CHOICE=$(whiptail --title "Stack Manager: $(basename "$PWD")" --menu "Choose an option:" 16 60 7 \
        "1" "Start Stack" \
        "2" "Stop Stack" \
        "3" "Restart Container" \
        "4" "View Network" \
        "5" "Backup Volumes" \
        "6" "Restore Volume" \
        "7" "Logs" \
        3>&1 1>&2 2>&3)

    EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then break; fi

    case $CHOICE in
        1)
            docker compose up -d
            msg_box "Status" "Stack started."
            ;;
        2)
            docker compose stop
            msg_box "Status" "Stack stopped."
            ;;
        3)
            # List containers
            CONTAINERS=$(docker compose ps --format "{{.Name}}" | tr '\n' ' ')
            # Create menu items
            ARGS=()
            for C in $CONTAINERS; do
                ARGS+=("$C" "")
            done
            
            if [ ${#ARGS[@]} -eq 0 ]; then
                msg_box "Error" "No containers running."
                continue
            fi

            TARGET=$(whiptail --title "Restart Container" --menu "Select container:" 15 60 5 "${ARGS[@]}" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                docker restart "$TARGET"
                msg_box "Status" "$TARGET restarted."
            fi
            ;;
        4)
            # List networks used by this stack
            NETWORKS=$(docker compose ps -q | xargs docker inspect --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' | tr ' ' '\n' | sort -u)
            
            if [ -z "$NETWORKS" ]; then
                 # Fallback if no containers running, try to parse compose
                 NETWORKS=$(docker compose config | grep "networks:" -A 10 | grep -v "networks:" | awk '{print $1}' | sed 's/://')
            fi

            OUTPUT=""
            for NET in $NETWORKS; do
                OUTPUT+="Network: $NET\n"
                # Inspect network to get containers
                OUTPUT+=$(docker network inspect "$NET" --format '{{range .Containers}}  - {{.Name}} ({{.IPv4Address}})\n{{end}}')
                OUTPUT+="\n"
            done
            whiptail --title "Network Status" --scrolltext --msgbox "$OUTPUT" 20 70
            ;;
        5)
            # Backup
            VOLUMES=$(docker compose config --volumes)
            if [ -z "$VOLUMES" ]; then
                msg_box "Info" "No volumes defined in this stack."
                continue
            fi
            
            ARGS=()
            for V in $VOLUMES; do
                ARGS+=("$V" "")
            done
            
            TARGET_VOL=$(whiptail --title "Backup Volume" --menu "Select volume to backup:" 15 60 5 "${ARGS[@]}" 3>&1 1>&2 2>&3)
            
            if [ $? -eq 0 ]; then
                DATE=$(date +%Y%m%d_%H%M%S)
                PROJECT_NAME=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
                
                # Find actual volume name
                ACTUAL_VOL_NAME=$(docker volume ls --filter "label=com.docker.compose.volume=$TARGET_VOL" --filter "label=com.docker.compose.project=$PROJECT_NAME" --format "{{.Name}}")
                
                if [ -z "$ACTUAL_VOL_NAME" ]; then
                     ACTUAL_VOL_NAME="${PROJECT_NAME}_${TARGET_VOL}"
                fi

                FILENAME="backup_${TARGET_VOL}_${DATE}.tar.gz"
                
                whiptail --infobox "Backing up $ACTUAL_VOL_NAME to $FILENAME..." 8 50
                
                docker run --rm -v "$ACTUAL_VOL_NAME":/volume -v "$PWD/$BACKUP_DIR":/backup alpine tar czf "/backup/$FILENAME" -C /volume .
                
                msg_box "Success" "Backup created: $FILENAME"
            fi
            ;;
        6)
            # Restore
            FILES=$(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null)
            if [ -z "$FILES" ]; then
                msg_box "Error" "No backups found."
                continue
            fi
            
            ARGS=()
            for F in $FILES; do
                ARGS+=("$(basename "$F")" "")
            done
            
            BACKUP_FILE=$(whiptail --title "Restore Volume" --menu "Select backup file:" 15 60 5 "${ARGS[@]}" 3>&1 1>&2 2>&3)
            
            if [ $? -eq 0 ]; then
                # Extract volume name: backup_VOLNAME_DATE.tar.gz
                MATCHED_VOL=$(echo "$BACKUP_FILE" | sed -E 's/^backup_(.*)_[0-9]{8}_[0-9]{6}\.tar\.gz$/\1/')
                
                VOLUMES=$(docker compose config --volumes)
                VALID=false
                for V in $VOLUMES; do
                    if [ "$V" == "$MATCHED_VOL" ]; then
                        VALID=true
                        break
                    fi
                done
                
                if [ "$VALID" = false ]; then
                    msg_box "Error" "Backup file '$BACKUP_FILE' does not match any volume in this stack (derived name: $MATCHED_VOL)."
                    continue
                fi
                
                if (whiptail --title "Confirm Restore" --yesno "WARNING: This will overwrite data in volume '$MATCHED_VOL'. Continue?" 10 60); then
                     PROJECT_NAME=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
                     ACTUAL_VOL_NAME=$(docker volume ls --filter "label=com.docker.compose.volume=$MATCHED_VOL" --filter "label=com.docker.compose.project=$PROJECT_NAME" --format "{{.Name}}")
                     
                     if [ -z "$ACTUAL_VOL_NAME" ]; then
                         ACTUAL_VOL_NAME="${PROJECT_NAME}_${MATCHED_VOL}"
                     fi
                     
                     whiptail --infobox "Restoring..." 8 50
                     docker run --rm -v "$ACTUAL_VOL_NAME":/volume -v "$PWD/$BACKUP_DIR":/backup alpine sh -c "rm -rf /volume/* && tar xzf /backup/$BACKUP_FILE -C /volume"
                     
                     msg_box "Success" "Restored $MATCHED_VOL from $BACKUP_FILE"
                fi
            fi
            ;;
         7)
            docker compose logs -f
            ;;
    esac
done
