# Go Attack

This repository contains code for studying the adversarial robustness of KataGo.

Read about our research:
- [Adversarial Policies Beat Superhuman Go AIs](https://arxiv.org/abs/2211.00241)
- [Can Go AIs Be Adversarially Robust?](https://arxiv.org/abs/2406.12843)

View our website here: https://goattack.far.ai/.

Our models and training data are available on our [Google
Drive](https://drive.google.com/drive/folders/1-bGX-NQOh6MuRPoXJgYHb9-jWRJvviSg?usp=drive_link).
To run our adversaries with Sabaki, see [this guide](sabaki/README.md).

# Development / testing information

To clone this repository, run one of the following commands:
```
# Via HTTPS
git clone --recurse-submodules https://github.com/AlignmentResearch/go_attack.git

# Via SSH
git clone --recurse-submodules git@github.com:AlignmentResearch/go_attack.git
```

Run `pip install -e '.[dev]'` inside the project root directory to install all necessary dependencies.

To run a pre-commit script before each commit, run `pre-commit install` (`pre-commit` should already have been installed in the previous step).
You may also want to run `pre-commit install` from `engines/KataGo-custom` to install that repository's respective commit hook.

## Git submodules

Modifications to KataGo *are not* tracked in this repository and should instead be made to the [AlignmentResearch/KataGo-custom](https://github.com/AlignmentResearch/KataGo-custom) repository. We use code from KataGo-custom in this repository via a Git submodule.

- [engines/KataGo-custom](engines/KataGo-custom) tracks the `stable` branch of the `KataGo-custom` repository.
- [engines/KataGo-raw](engines/KataGo-raw) tracks the `master` branch of https://github.com/lightvector/KataGo.
- [engines/KataGo-tensorflow](engines/KataGo-tensorflow) is a version of
  KataGo-custom prior to merging KataGo version v1.12, which switched the
  training code from TensorFlow to PyTorch. We use KataGo-tensorflow to
  fine-tune our existing TensorFlow adversaries that pre-dated v1.12.

## Individual containers

We run KataGo within Docker containers.
More specifically:
1. The C++ portion of KataGo runs in the container defined by [compose/cpp/Dockerfile](compose/cpp/Dockerfile).
2. The Python training portion of KataGo runs in the container defined at [compose/python/Dockerfile](compose/python/Dockerfile).

The Dockerfiles contain instructions for how to build them.

After building a container, you run it with a command like
```
docker run --gpus all -v ~/go_attack:/go_attack -v DATA_DIR:/shared -it humancompatibleai/goattack:cpp
```
where `DATA_DIR` is a directory, shared among all containers, in which to save the
results of training runs.

A KataGo executable can be found in the `/engines/KataGo-custom/cpp` directory inside the C++ container.

## Launching victim-play training runs

In order to launch training runs, run several containers
simultaneously:

* One or more 1-GPU C++ containers executing victim-play games to generate data. Example
  command to run in each container: `/go_attack/kubernetes/victimplay.sh
  [--warmstart] EXPERIMENT-NAME /shared/`, where the optional `--warmstart` flag
  should be set for warmstarted runs.
* One 1-GPU Python container for training. Example command:
  `/go_attack/kubernetes/train.sh [--initial-weights WARMSTART-MODEL-DIR]
  EXPERIMENT-NAME /shared/ 1.0` where the optional `--initial-weights
  WARMSTART-MODEL-DIR` flag should be set for warmstarted runs.
* One Python container for shuffling data. Example command:
  `/go_attack/kubernetes/shuffle-and-export.sh [--preseed
  WARMSTART-SELFPLAY-DIR] EXPERIMENT-NAME /shared` where the optional `--preseed`
  flag should be set for warmstarted runs.
* One Python container for running the curriculum. Example command:
  `/go_attack/kubernetes/curriculum.sh EXPERIMENT-NAME /shared/
  /go_attack/configs/examples/cyclic-adversary-curriculum.json
  -harden-below-visits 100`.
  * The victims listed in the curriculum `.json` file are assumed to exist in
    `/shared/victims`. They can be symlinks.
* Optionally, one 1-GPU C++ container for evaluating models. Example command:
  `/go_attack/kubernetes/evaluate-loop.sh /shared/victimplay/EXPERIMENT-NAME/
  /shared/victimplay/EXPERIMENT-NAME/eval`.

See [configs/examples](configs/examples/README.md) for example experiment
configurations and example values for the warmstart flags.

For these wrapper scripts in `kubernetes/`, optional flags for the wrapper come
before any positional arguments, but optional flags for the underlying command
the wrapper calls go after any positional arguments. For example, in the command
`/go_attack/kubernetes/shuffle-and-export.sh --preseed WARMSTART-SELFPLAY-DIR
EXPERIMENT-NAME /shared -add-to-window 100000000`, `--preseed` is a flag for the
wrapper whereas `-add-to-window` is a flag to be passed to
`/engines/KataGo-tensorflow/python/selfplay/shuffle_and_export_loop.sh`.

## Docker compose

Within the `compose` directory of this repo are a few docker-compose `.yml` files
that automate the process of spinning up the various components of training.

Each `.yml` file also has a corresponding `.env` that configures more specific
parameters of the run (
    e.g. what directory to write to,
    how many threads to use,
    batch size,
    where to look for other config files
).

(Note: we stopped using these in October 2022, so they are no longer maintained.)

## Website and analysis notebooks

See [AlignmentResearch/KataGoVisualizer](https://github.com/AlignmentResearch/KataGoVisualizer).

# Baseline attacks

In addition to the learned attacks, we also implement 5 baseline, hardcoded attacks:
- Edge attack, which plays random vertices in the outermost available ring of the board
- Random attack, which simply plays random legal moves
- Pass attack, which always passes at every turn
- Spiral attack, which deterministically plays the "largest" legal move in lexicographical order in polar coordinates (going counterclockwise starting from the outermost ring)
- [Mirror Go](https://en.wikipedia.org/wiki/Mirror_Go), which plays the opponent's last move reflected about the y = x diagonal, or the y = -x diagonal if they play on y = x. If the mirrored vertex is taken, then the policy plays the "closest" legal vertex by L1 distance.

You can test these attacks by running `baseline_attacks.py` with the appropriate `--strategy` flag (`edge`, `random`, `pass`, `spiral`, or `mirror`). Run `python scripts/baseline_attacks.py --help` for more information about all the available flags.
