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

# Per (project, version) verdict, one line per run, appended across
# batch invocations. aggregate_report.py reads this as the source of
# truth for success/failure instead of re-deriving it from raw logs.
# Columns: completed_at, project, version, exit_code, run_id, started_at
SUMMARY_LOG="logs/summary.tsv"

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
    
    # Trim before creating the log directory - otherwise a leading/
    # trailing space in list.txt makes this word-split into the wrong
    # path, and every later log write for this project silently goes
    # missing (aggregate_report.py then can't classify its failures).
    project=$(echo "$project" | xargs)
    mkdir -p "logs/$project"
    
    # Generate timestamp for error log filename. Includes the date (not
    # just HH:MM:SS) since this value is also used as summary.tsv's
    # run_id, which aggregate_report.py relies on to find the exact
    # log file for a run - two runs of the same project at the same
    # wall-clock second on different days must not collide.
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    
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

        # Recorded alongside the verdict below so aggregate_report.py
        # can tell which result.json entries (timestamped by
        # weblate_utils.py's check_sentence_count/detail) were
        # actually produced by *this* run, instead of trusting stale
        # entries left over from an earlier run of the same
        # (project, version).
        run_started_at=$(date '+%Y-%m-%dT%H:%M:%S')

        # run migration.sh and save the log to the log file
        #
        # NOTE: We deliberately do not wrap this pipeline in an
        # `if ... ; then` check. The exit status of a pipeline is the
        # exit status of its *last* command (the `while` loop here),
        # which almost always exits 0 regardless of whether
        # MIGRATION_SCRIPT failed. PIPESTATUS[0] captures the actual
        # exit code of MIGRATION_SCRIPT, and must be read immediately
        # after the pipeline, before any other command runs.
        "$MIGRATION_SCRIPT" "$project" "$version" 2>&1 | while IFS= read -r line; do
            # save the version to the log file
            echo "$version | $line" | tee -a "$LOG_FILE"
            # save the error line to the error log file
            if [[ "$line" == \[ERROR\]* ]]; then
                echo "$version | $line" >> "$ERROR_LOG"
            fi
        done
        migration_exit_code=${PIPESTATUS[0]}

        if [ "$migration_exit_code" -eq 0 ]; then
            echo "[$total_count] Success: '$project' (version: $version)"
        else
            echo "[$total_count] Failed: '$project' (version: $version) (exit code: $migration_exit_code)"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$(date '+%Y-%m-%dT%H:%M:%S')" "$project" "$version" \
            "$migration_exit_code" "$TIMESTAMP" "$run_started_at" \
            >> "$SUMMARY_LOG"
        sleep 15
        
        echo "---"
    done < "$VERSION_FILE"
    
done < "$LIST_FILE"

echo "====================="
echo "=== Migration completed ==="
