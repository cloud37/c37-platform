#!/bin/bash

# Initialize variables
addr="$BOOTSTRAP_SERVERS"
interval=1  # Default value for the interval
topic="test"

# Function to show usage
usage() {
    echo "Usage: $0 [-a <addr>] [-i <interval>] [-t <topic>]"
    exit 1
}

# Parse the arguments
while getopts ":a:i:t:" opt; do
  case $opt in
    a)
      addr=$OPTARG
      ;;
    i)
      interval=$OPTARG
      ;;
    t)
      topic=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

# Validate the addr argument
if [ -z "$addr" ]; then
    echo "Error: Argument --addr (-a) is required."
    exit 1
fi

# Validate the interval argument
if ! [[ $interval =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: --interval (-i) must be a valid number."
    exit 1
fi

# Validate the topic argument
if [ -z "$topic" ]; then
    echo "Error: Argument --topic (-t) is required."
    exit 1
fi

# Main loop
while true
do
    # Generate a random ID (e.g., between 1 and 10000)
    RANDOM_ID=$((RANDOM % 10000 + 1))

    # Generate random content (example here is a random word)
    # Use LC_ALL=C to avoid 'Illegal byte sequence' error
    RANDOM_CONTENT=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head -n 1)

    # Execute the command with the random key and values
    data="{\"id\":\"$RANDOM_ID\"}#{\"id\": $RANDOM_ID, \"value\": \"$RANDOM_CONTENT\"}"
    echo "$data" | kafka-console-producer.sh --bootstrap-server "$addr" --topic "$topic" --property "parse.key=true" --property "key.separator=#"
    echo "$data"
    # Pause the script for a specified interval between requests
    sleep "$interval"
done
