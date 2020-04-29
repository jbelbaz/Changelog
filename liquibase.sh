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
FILE_NAME="LIQUIBASE.md"
SQL_FILE_NAME="${FROM_TAG//./_}_TO_${TO_TAG//./_}.sql"
STRUCTURE_CHANGE_LOG="$1/opencell-model/src/main/db_resources/changelog/current/structure.xml"
DATA_CHANGE_LOG="$1/opencell-model/src/main/db_resources/changelog/current/data.xml"
TITLE="# Liquibase"
DESCRIPTION="All notable database updates to this project will be documented in this file."
TODAY=$(date +'%d/%m/%Y')

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
echo -e "$TITLE\n$DESCRIPTION\n" > ../$FILE_NAME
echo -e "## [$TO_TAG] - $TODAY\n" >> ../$FILE_NAME
echo $INCLUDE >> ../$FILE_NAME
for k in $(git tag -l  --sort=v:refname); do 
    if [  $k \> "$FROM_TAG" -a \( $k \< "$TO_TAG" -o $k == "$TO_TAG" \) ]; then
        git checkout $k -f
        echo "-- checkout $k "
        IFS=$'§'
        changeSets=( $(xmllint --format --xpath "//*[local-name() = 'changeSet']" $STRUCTURE_CHANGE_LOG | sed 's/changeSet>/changeSet>§/g'))
        changeSets+=( $(xmllint --format --xpath "//*[local-name() = 'changeSet']" $DATA_CHANGE_LOG | sed 's/changeSet>/changeSet>§/g'))
        echo "-- changeset(s) defined"
        for changeSet in "${changeSets[@]}"
        do
            id=$(echo $changeSet | xmllint --format --xpath "string(//*/@id)" -)
            ticket=$(echo $id | sed 's/#//g' | sed -E 's/([0-9]*)_.*/\1/')
            changeSetNoXML=$(echo $changeSet | perl -pe 's/<changeSet.*?>//g' | perl -pe 's/<(?=[a-zA-Z]*?\s)/;/g' | perl -pe's/<([a-zA-Z]*?)>/;/g' | perl -pe 's/<\/[a-zA-Z]*?>|<\/[a-zA-Z]*?>|<|\/>|>//g')
            echo "-- changeSetNoXML defined"
            if [[ !" ${ids[@]} " =~ ${id} ]]; then
                echo -n "-- DUPLICATE CHANGESET : "
                echo $id
            else
                ids+=($id)
                echo -n "-- ADDING CHANGESET : "
                echo $id
                echo -e "[#$ticket](https://opencell.assembla.com/spaces/meveo/tickets/$ticket)$changeSetNoXML\n" >> ../$FILE_NAME
            fi
        done
        #printf '%s\n' "${ids[@]}"
    fi
done
liquibase --url=jdbc:postgresql://localhost:5432/meveo2?outputLiquibaseSql=true --username=meveo --password=meveo --classpath=postgresql-42.1.4.jar dropAll
liquibase --url=jdbc:postgresql://localhost:5432/meveo2?outputLiquibaseSql=true --username=meveo --password=meveo --classpath=postgresql-42.1.4.jar --changeLogFile="../$FILE_NAME" --outputFile="../$SQL_FILE_NAME" clearCheckSums updatesql

IFS=$OLD_IFS
