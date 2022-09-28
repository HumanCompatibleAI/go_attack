#!/bin/sh
cd /engines/KataGo-custom/python || exit
RUN_NAME="$1"
VOLUME_NAME="$2"
INITIAL_WEIGHTS="$3"
if [ -z "$INITIAL_WEIGHTS" ]; then
    echo "No initial weights specified, using random weights"
else
    echo "Using initial weights: $INITIAL_WEIGHTS"
    mkdir -p /"$VOLUME_NAME"/victimplay/"$RUN_NAME"/train/t0
    cp -r /"$VOLUME_NAME"/victim-weights/"$INITIAL_WEIGHTS"/saved_model/model.config.json /"$VOLUME_NAME"/victimplay/"$RUN_NAME"/train/t0/model.config.json
    cp -r /"$VOLUME_NAME"/victim-weights/"$INITIAL_WEIGHTS"/saved_model/variables /"$VOLUME_NAME"/victimplay/"$RUN_NAME"/train/t0/initial_weights
fi

./selfplay/train.sh    /"$VOLUME_NAME"/victimplay/"$RUN_NAME"    t0    b6c96    256    main    -disable-vtimeloss    -lr-scale 1.0    -max-train-bucket-per-new-data 4