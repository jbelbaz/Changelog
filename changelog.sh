#!/bin/bash

FROM_TAG="$2"
TO_TAG="$3"
SPACE="cRAcZ4D1Cr4PP6acwqjQWU" # meveo
WORKDIR="$1"
CURRENT_DIR="$(realpath $(pwd))"
API_KEY="02dbd0635a36cbbeea48"
API_SECRET="9e525204512e4ad65dd89b946542173f473db656"
TODAY=$(date +'%d/%m/%Y')

FILE_BASE="tickets_${FROM_TAG}_${TO_TAG}"
TICKETS_LIST=${CURRENT_DIR}/${FILE_BASE}.lst
MODEL_TICKETS=${CURRENT_DIR}/model_${FILE_BASE}.lst
API_TICKETS=${CURRENT_DIR}/api_${FILE_BASE}.lst
SERVICE_TICKETS=${CURRENT_DIR}/service_${FILE_BASE}.lst
GUI_TICKETS=${CURRENT_DIR}/gui_${FILE_BASE}.lst
BUG_TICKETS=${CURRENT_DIR}/bug_${FILE_BASE}.lst
ALL_TICKETS=${CURRENT_DIR}/all_${FILE_BASE}.lst
ALL_TICKETS_MD=${CURRENT_DIR}/CHANGELOG_${FROM_TAG}_${TO_TAG}.md

if [ -z "$FROM_TAG" -o -z "$TO_TAG" ]
then
  echo "usage: changelog.sh <git meveo directory> <from_tag> <to_tag>" >&2
  exit 1
fi

# Prep files
echo -e "\n# Changelog\nAll notable changes to this project will be documented in this file.\n"> "$ALL_TICKETS_MD"
echo -e "## [$TO_TAG] - $TODAY\n">>"$ALL_TICKETS_MD"
echo -e "\n### Model">"$MODEL_TICKETS"
echo -e "\n### Api">"$API_TICKETS"
echo -e "\n### Service">"$SERVICE_TICKETS"
echo -e "\n### GUI">"$GUI_TICKETS"
echo -e "\n### Bug">"$BUG_TICKETS"

cd "${WORKDIR}"
echo ">>> Fetching origin"
git fetch --prune --tags origin

# Get ticket list between tags
echo ">>> From $FROM_TAG"
git log -n 1 $FROM_TAG

echo ">>> To $TO_TAG"
git log -n 1 $TO_TAG

git log ${FROM_TAG}..${TO_TAG} --decorate --pretty="format:%s" | grep -E "#[0-9]+" | sed -E 's/[^#]*#([0-9]+).*/\1/' | sort -u >"$TICKETS_LIST"

# Build ticket data file
ticketsCount=$(wc -l <"$TICKETS_LIST")
echo "Fetching data for $ticketsCount tickets"
rm "$TICKETS" 2>/dev/null
currentTicket=0



cat "$TICKETS_LIST" | while read ticketNumber
do
    currentTicket=$(( $currentTicket + 1 ))
    echo Ticket "core#${ticketNumber} (${currentTicket}/${ticketsCount})"
    json=$( curl -H "X-Api-Key: ${API_KEY}" -H "X-Api-Secret: ${API_SECRET}" https://api.assembla.com/v1/spaces/${SPACE}/tickets/${ticketNumber} )
    number=$(echo $json | jq -c '.number') 
    type=$(echo $json | jq -c '.custom_fields.Type' | sed 's/"//g')
    summary=$(echo $json | jq -c '.summary' | sed 's/"//g')
    component=$(echo $json | jq -c '.custom_fields.Component' | sed 's/"//g')
    link="https://opencell.assembla.com/spaces/meveo/tickets/"$number
    tofile="- [#$number]($link) - $summary"
    echo "$tofile" >> "$ALL_TICKETS"

    if [ "$type" == "Enhancement" ]; then
        if [ "$component" == "Opencell-API" ]; then
            echo "$tofile" >> "$API_TICKETS"
        fi
        if [ "$component" == "Opencell-Model" ]; then
            echo "$tofile" >> "$MODEL_TICKETS"
        fi
        if [ "$component" == "Opencell-Services" ]; then
            echo "$tofile" >> "$SERVICE_TICKETS"
        fi
        if [ "$component" == "Opencell-Admin" ]; then
            echo "$tofile" >> "$GUI_TICKETS"
        fi
    else
         echo "$tofile" >> "$BUG_TICKETS"
    fi
done


cat $MODEL_TICKETS>>"$ALL_TICKETS_MD"

cat $API_TICKETS>>"$ALL_TICKETS_MD"

cat $SERVICE_TICKETS>>"$ALL_TICKETS_MD"

cat $GUI_TICKETS>>"$ALL_TICKETS_MD"

cat $BUG_TICKETS>>"$ALL_TICKETS_MD"

cat $ALL_TICKETS_MD

rm "$TICKETS_LIST"
rm "$MODEL_TICKETS"
rm "$API_TICKETS"
rm "$SERVICE_TICKETS"
rm "$GUI_TICKETS"
rm "$BUG_TICKETS"
rm "$ALL_TICKETS"
