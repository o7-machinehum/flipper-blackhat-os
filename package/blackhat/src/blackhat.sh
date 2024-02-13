#!/bin/bash

# Default message
message="Hello World!"

# Parse command line arguments
while getopts "p:" opt; do
  case $opt in
    p)
      message=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Function to print message
print_message() {
    echo $message
}

# Main script execution
print_message

