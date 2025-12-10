#!/bin/bash

LIST_FILE="$1"
VERSION_FILE="${2:-version.txt}"

# Check the usage of the script
if [ $# -eq 0 ]; then
    echo "사용법: $0 <list_file> [version_file]"
    echo "예시: $0 list.txt"
    echo "예시: $0 list.txt version.txt"
    exit 1
fi

if [ ! -f "$LIST_FILE" ]; then
    echo "Error: File '$LIST_FILE' does not exist."
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: File '$VERSION_FILE' does not exist."
    exit 1
fi

MIGRATION_SCRIPT="$(dirname "$0")/migration_resources.sh"

if [ ! -f "$MIGRATION_SCRIPT" ]; then
    echo "Error: migration_resources.sh file does not exist in '$MIGRATION_SCRIPT'."
    exit 1
fi

# Check the execution permission of the script
if [ ! -x "$MIGRATION_SCRIPT" ]; then
    echo "Warning: migration_resources.sh does not have execution permission. Granting execution permission."
    chmod +x "$MIGRATION_SCRIPT"
fi

# Make logs directory
mkdir -p logs

echo "=== Migration starts ==="
echo "Project file: $LIST_FILE"
echo "Version file: $VERSION_FILE"
echo "Log directory: $LOG_DIR"
echo "====================="

total_count=0

while IFS= read -r project || [ -n "$project" ]; do   
    echo "=== Project: $project ==="
    if [[ -z "${project// }" ]]; then
        continue
    fi
    
    mkdir -p logs/$project
    project=$(echo "$project" | xargs)
    
    # Generate timestamp for error log filename
    TIMESTAMP=$(date +%H%M%S)
    
    echo ""
    echo "=== Project: $project ==="
    
    # Iterate over the versions
    while IFS= read -r version || [ -n "$version" ]; do
        # Skip empty lines or lines with only whitespace
        if [[ -z "${version// }" ]]; then
            continue
        fi
        
        # Remove leading and trailing whitespace
        version=$(echo "$version" | xargs)
        
        ((total_count++))
        echo "[$total_count] 처리 중: '$project' (버전: $version)"
        
        # path for log files
        LOG_FILE="logs/$project/project.${TIMESTAMP}.log"
        ERROR_LOG="logs/$project/error.${TIMESTAMP}.log"
        
        # run migration.sh and save the log to the log file
        
        if "$MIGRATION_SCRIPT" "$project" "$version" 2>&1 | while IFS= read -r line; do
            # save the version to the log file
            echo "$version | $line" | tee -a "$LOG_FILE"
            # save the error line to the error log file
            if [[ "$line" == \[ERROR\]* ]]; then
                echo "$version | $line" >> "$ERROR_LOG"
            fi
        done; then
            echo "[$total_count] Success: '$project' (version: $version)"
        else
            echo "[$total_count] Failed: '$project' (version: $version) (exit code: $?)"
        fi
        sleep 15
        
        echo "---"
    done < "$VERSION_FILE"
    
done < "$LIST_FILE"

echo "====================="
echo "=== Migration completed ==="
