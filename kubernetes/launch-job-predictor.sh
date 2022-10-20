#!/bin/sh
GIT_ROOT=$(git rev-parse --show-toplevel)
RUN_NAME_SHORT="b10-curr-cp505-init"
RUN_NAME="tony-vpred/b10-curr-cp505-init"
echo "Run name: $RUN_NAME"

# Make sure we don't miss any changes
if [ "$(git status --porcelain --untracked-files=no | wc -l)" -gt 0 ]; then
    echo "Git repo is dirty, aborting" 1>&2
    exit 1
fi

# Maybe build and push new Docker images
python "$GIT_ROOT"/kubernetes/update_images.py
# Load the env variables just created by update_images.py
# This line is weird because ShellCheck wants us to put double quotes around the
# $() context but this changes the behavior to something we don't want
# shellcheck disable=SC2046
export $(grep -v '^#' "$GIT_ROOT"/kubernetes/active-images.env | xargs)

# The KUBECONFIG env variable is set in the user's .bashrc and is changed whenever you type
# "loki" or "lambda" on the command line
case "$KUBECONFIG" in
    "$HOME/.kube/loki")
        echo "Looks like we're on Loki. Will use the shared host directory instead of Weka."
        VOLUME_FLAGS=""
        VOLUME_NAME=data
        ;;
    "$HOME/.kube/lambda")
        echo "Looks like we're on Lambda. Will use the shared Weka volume."
        # shellcheck disable=SC2089
        # VOLUME_FLAGS="--volume_name go-attack --volume_mount shared --shared-host-dir=''"
        VOLUME_FLAGS="--volume_name go-attack --volume_mount shared"
        VOLUME_NAME=shared
        ;;
    *)
        echo "Unknown value for KUBECONFIG env variable: $KUBECONFIG"
        exit 2
        ;;
esac

# shellcheck disable=SC2215,SC2086,SC2089,SC2090
ctl job run --container \
    "$CPP_IMAGE" \
    "$PYTHON_IMAGE" \
    "$PYTHON_IMAGE" \
    "$PYTHON_IMAGE" \
    "$PYTHON_IMAGE" \
    "$PYTHON_IMAGE" \
    $VOLUME_FLAGS \
    --command "/go_attack/kubernetes/victimplay-predictor.sh $RUN_NAME $VOLUME_NAME" \
    "/go_attack/kubernetes/shuffle-and-export.sh $RUN_NAME $RUN_NAME $VOLUME_NAME" \
    "/go_attack/kubernetes/shuffle-and-export.sh $RUN_NAME $RUN_NAME/predictor $VOLUME_NAME" \
    "/go_attack/kubernetes/train.sh $RUN_NAME $VOLUME_NAME" \
    "/go_attack/kubernetes/train.sh $RUN_NAME/predictor $VOLUME_NAME" \
    "/go_attack/kubernetes/curriculum.sh $RUN_NAME $VOLUME_NAME" \
    --gpu 1 0 0 1 1 0 \
    --name go-training-"$RUN_NAME_SHORT" \
    --replicas "${2:-7}" 1 1 1 1 1
