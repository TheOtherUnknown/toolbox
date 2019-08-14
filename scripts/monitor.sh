#!/bin/bash
counter=0
set -u # Exit with error if any vars are undefined
if [ -z $hookurl ]; then
    >&2 echo 'Hook URL is not set!'
    exit 1
fi
while true; do
    curl -sm 5 -I -H "User-Agent: CSG monitor/0.1" https://csg.ius.edu > /dev/null # Make an HTTP HEAD request, timeout after 5 secs
    if [ $? -gt 0 ]; then # Did curl have a exit code > 0?
        counter=$((counter + 1)) # Yes!
        if [ $counter -eq 2 ]; then # Has curl failed for 60 secs?
            message="csg.ius.edu has not responded to HTTP requests for 60 seconds."
        curl -H "Content-Type: application/json" -X POST -d "{\"username\": \"HTTP monitor\", \"content\": \"$message\"}" "$hookurl"
        fi
        if [ $counter -eq 10 ]; then # Has curl failed for 5 mins?
            message="csg.ius.edu has not responded to HTTP requests for 5 minutes.\nNo more alerts will be sent until the host comes back online."
        curl -H "Content-Type: application/json" -X POST -d "{\"username\": \"HTTP monitor\", \"content\": \"$message\"}" "$hookurl"
        fi
    else # No!
        counter=0
    fi
    sleep 30 # wait before the next check
done
