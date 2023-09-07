#!/bin/bash

CONFIG_PATH=/home/kcasey/mrtg/conf.d
INPUT_FILENAME="$1"
INPUT_FILE=$(echo "$(cat $INPUT_FILENAME)")
OUTPUT_FILENAME=$(echo $INPUT_FILENAME | cut -d "/" -f 6)
OUTPUT_FILE=$CONFIG_PATH/$OUTPUT_FILENAME

output_to_cfg_file() {
    START_INDEX=$1
    END_INDEX=$(($START_INDEX + 39))
    if [ $(echo "$INPUT_FILE" | sed -n "$END_INDEX"p) != "</div>" ]; then
        END_INDEX=$(($START_INDEX + 40))
    fi
    for (( LINE=$START_INDEX; LINE<=$END_INDEX; LINE++ ))
    do
        # echo "Writing $(echo "$INPUT_FILE" | sed -n "$LINE"p)"
        echo "$INPUT_FILE" | sed -n "$LINE"p >> $OUTPUT_FILE
    done
}

remove_down_links() {
   sed -i '/^#/d' $OUTPUT_FILE
}

find_core_links() {
    echo "Building Config File for $INPUT_FILENAME"
    echo "WorkDir: /var/www/mrtg" > $OUTPUT_FILE
    echo "EnableIPv6: no" >> $OUTPUT_FILE
    echo "WorkDir: /var/www/html" >> $OUTPUT_FILE
    echo "Options[_]: growright, bits" >> $OUTPUT_FILE
    readarray -t core_link_array < <(echo "$INPUT_FILE" | grep -n "Name: 'et-" | grep -Fv '.' | cut -d: -f1)
    readarray -t ae_bundle_array < <(echo "$INPUT_FILE" | grep -n "Name: 'ae" | grep -Fv '.' | cut -d: -f1)
    for LINE_NUMBER in "${core_link_array[@]}"
    do
        echo "Found a core link on line "$LINE_NUMBER""
        echo "Passing line number "$LINE_NUMBER" to the output function"
        output_to_cfg_file "$LINE_NUMBER"
    done
    for LINE_NUMBER in "${ae_bundle_array[@]}"
    do
        echo "Found an ae bundle on line "$LINE_NUMBER""
        echo "Passing line number "$LINE_NUMBER" to the output function"
        output_to_cfg_file "$LINE_NUMBER"
    done 
}

find_core_links
remove_down_links
