#!/bin/bash

CONFIG_SWITCH_NAME=$1

check_valid_json () {
    if ! jq . "$1" >/dev/null 2>&1; then
        echo "Error: jq parsing error in $1";
        exit 1;
    fi
}

check_valid_url () {
    if [ -z "$2" ]; then
        echo "No URL (mandatory) for $1";
        exit 1;
    elif ! which wget >/dev/null; then
        echo "Command 'wget' isn't installed, skipping url checking...";
        exit 0;
    elif ! wget --spider "$2" 2>/dev/null; then
        echo "Error: URL $2 does not exist";
        exit 1;
    fi
}

check_url_from_file () {
    HEAD=$(head -1 "$1");
    if [ "$HEAD" = "{" ]; then
        URL=$(jq -r '.url' "$1");
        check_valid_url "$1" "$URL";
    else
        # json not starting with '{' means it's a list, we iterate over elements
        URLS=$(jq -r .[].url "$1");
        for u in $URLS; do
            check_valid_url "$1" "$u";
        done;
    fi
}

if [ -z "$CONFIG_SWITCH_NAME" ]; then
    # Checking all files in ocaml-versions
    for f in $(find ocaml-versions/*.json); do
        check_valid_json "$f";
        check_url_from_file "$f";
    done
else
    FILENAME=ocaml-versions/$CONFIG_SWITCH_NAME.json;
    if [ -f "$FILENAME" ]; then
        check_valid_json "$FILENAME";
        check_url_from_file "$FILENAME";
    else
        echo "File $FILENAME doesn't exist.";
        exit 1;
    fi
fi
