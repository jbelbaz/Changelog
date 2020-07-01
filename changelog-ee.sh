#!/bin/bash

FROM_TAG="$2"
TO_TAG="$3"
SPACE="dE8Z0QjqOr5zBcdmr6bg7m" # meveo-entreprise
WORKDIR="$1"
CURRENT_DIR="$(realpath $(pwd))"
API_KEY="02dbd0635a36cbbeea48"
API_SECRET="9e525204512e4ad65dd89b946542173f473db656"
TODAY=$(date +'%d/%m/%Y')

FILE_BASE="tickets_${FROM_TAG}_${TO_TAG}"
TICKETS_LIST=${CURRENT_DIR}/${FILE_BASE}.lst
API_TICKETS=${CURRENT_DIR}/api_${FILE_BASE}.lst
ALL_TICKETS=${CURRENT_DIR}/all_${FILE_BASE}.lst
ALL_TICKETS_MD=${CURRENT_DIR}/CHANGELOG-EE_${FROM_TAG}_${TO_TAG}.md

if [ -z "$FROM_TAG" -o -z "$TO_TAG" ]
then
  echo "usage: changelog.sh <git meveo-entreprise directory> <from_tag> <to_tag>" >&2
  exit 1
fi

# Prep files
echo -e "\n# Changelog-ee\nAll notable changes to this project will be documented in this file.\n"> "$ALL_TICKETS_MD"
echo -e "## [$TO_TAG] - $TODAY\n">>"$ALL_TICKETS_MD"
echo -e "\n### Generic API">"$API_TICKETS"

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
    echo Ticket "EE#${ticketNumber} (${currentTicket}/${ticketsCount})"
    json=$( curl -H "X-Api-Key: ${API_KEY}" -H "X-Api-Secret: ${API_SECRET}" https://api.assembla.com/v1/spaces/${SPACE}/tickets/${ticketNumber} )
    number=$(echo $json | jq -c '.number') 
    type=$(echo $json | jq -c '.custom_fields.Type' | sed 's/"//g')
    summary=$(echo $json | jq -c '.summary' | sed 's/"//g')
    component=$(echo $json | jq -c '.custom_fields.Component' | sed 's/"//g')
    link="https://opencell.assembla.com/spaces/meveo-enterprise/tickets/"$number
    tofile="- [#$number]($link) - $summary"
    echo "$tofile" >> "$ALL_TICKETS"

    if [ "$component" == "API" ]; then
         echo "$tofile" >> "$API_TICKETS"
    fi
done

cat $API_TICKETS>>"$ALL_TICKETS_MD"


cat $ALL_TICKETS_MD

rm "$TICKETS_LIST"
rm "$API_TICKETS"
rm "$ALL_TICKETS"