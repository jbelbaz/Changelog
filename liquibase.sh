#!/bin/bash
OLD_IFS=$IFS

if [ "$#" -lt 2 ]; then
    echo "FATAL : PARAMS ARE MISSING." 
    echo "Syntax : ./mig.sh FROM_TAG TO_TAG"
	echo "FROM_TAG : 6.0.0"
	echo "TO_TAG   : 6.0.2"
	echo "EXIT WITH ERROR"
	exit
fi

pwd

FROM_TAG=$2
TO_TAG=$3
WORKSPACE=.
CURRENT_DIR="$(realpath $(pwd))"
FILE_NAME=${CURRENT_DIR}/LIQUIBASE.csv
SQL_FILE_NAME="${FROM_TAG//./_}_TO_${TO_TAG//./_}.sql"
STRUCTURE_CHANGE_LOG="$1/opencell-model/src/main/db_resources/changelog/current/structure.xml"
DATA_CHANGE_LOG="$1/opencell-model/src/main/db_resources/changelog/current/data.xml"

## Remove file
rm -rf $SQL_FILE_NAME
rm -rf $FILE_NAME

cd "$1"
git checkout $FROM_TAG -f

ids=()
IFS=$'§'
changeSets=( $(xmllint --format --xpath "//*[local-name() = 'changeSet']" $STRUCTURE_CHANGE_LOG | sed 's/changeSet>/changeSet>§/g'))
changeSets+=( $(xmllint --format --xpath "//*[local-name() = 'changeSet']" $DATA_CHANGE_LOG | sed 's/changeSet>/changeSet>§/g'))
for changeSet in "${changeSets[@]}"
    do
        ids+=($(echo $changeSet | xmllint --format --xpath "string(//*/@id)" -))
    done
printf '%s\n' "${ids[@]}"


IFS=$OLD_IFS
for k in $(git tag -l  --sort=v:refname); do 
    if [  $k \> "$FROM_TAG" -a \( $k \< "$TO_TAG" -o $k == "$TO_TAG" \) ]; then
        git checkout $k -f
        echo "-- checkout $k "
        IFS=$'§'
        changeSets=( $(xmllint --format --xpath "//*[local-name() = 'changeSet']" $STRUCTURE_CHANGE_LOG | sed 's/changeSet>/changeSet>§/g'))
        changeSets+=( $(xmllint --format --xpath "//*[local-name() = 'changeSet']" $DATA_CHANGE_LOG | sed 's/changeSet>/changeSet>§/g'))
        echo "-- changeset(s) set"
        for changeSet in "${changeSets[@]}"
        do
            id=$(echo $changeSet | xmllint --format --xpath "string(//*/@id)" -)
            ticket=$(echo $id | sed 's/#//g' | sed -E 's/([0-9]*)_.*/\1/')
            changeSetNoXML=$(echo $changeSet | perl -pe 's/<changeSet.*?>//g' | perl -pe 's/<(?=[a-zA-Z]*?\s)/;/g' | perl -pe 's/<([a-zA-Z]*?)>/;/g' | perl -pe 's/<\/[a-zA-Z]*?>|<\/[a-zA-Z]*?>|<|\/>|>//g' | perl -pe 's/\t|\n/ /g')
            if [[ !" ${ids[@]} " =~ ${id} ]]; then
                echo -n "-- DUPLICATE CHANGESET : "
                echo $id
            else
                ids+=($id)
                echo -n "-- ADDING CHANGESET : "
                echo $id
                echo -e "#$ticket - https://opencell.assembla.com/spaces/meveo/tickets/$ticket$changeSetNoXML" >> "$FILE_NAME"
            fi
        done
        #printf '%s\n' "${ids[@]}"
    fi
done
IFS=$OLD_IFS
