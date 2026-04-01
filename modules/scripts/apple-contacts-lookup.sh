#!/bin/bash
# Look up a contact by name
osascript -e "
tell application \"Contacts\"
    set matchingPeople to every person whose name contains \"$1\"
    set output to \"\"
    repeat with p in matchingPeople
        set output to output & name of p
        try
            set output to output & \" | \" & value of first phone of p
        end try
        try
            set output to output & \" | \" & value of first email of p
        end try
        set output to output & return
    end repeat
    return output
end tell
" 2>/dev/null
