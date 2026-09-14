#!/bin/bash

# Define the base name and 1 KB limit in bytes
BASE_NAME="openssh"
MAX_BYTES=1024

current_bytes=0
current_file=""

# Function to generate a new filename with a current timestamp
generate_filename() {
    echo "${BASE_NAME}-$(date +%Y%m%d%H%M%S).log"
}

# Read input line by line
while IFS= read -r line || [[ -n "$line" ]]; do
    # Format line to include the newline character for accurate byte counting
    line_with_newline="$line"$'\n'
    # Calculate byte size of the current line
    line_bytes=$(printf '%s' "$line_with_newline" | wc -c)

    # If no file is open, or adding this line exceeds 1 KB, start a new batch
    if [[ -z "$current_file" ]] || (( current_bytes + line_bytes > MAX_BYTES )); then
        # Ensure a small delay so fast batches don't overwrite the same timestamp filename
        if [[ -n "$current_file" ]]; then
            sleep 1
        fi
        current_file=$(generate_filename)
        current_bytes=0
    fi

    # Append the line to the active batch file
    printf '%s' "$line_with_newline" >> "$current_file"
    # Update the total byte count for the current batch
    (( current_bytes += line_bytes ))
done
