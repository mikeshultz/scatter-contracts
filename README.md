# scatter-contracts

Ethereum smart contracts for scatter.online.

## Libraries

### Owned

TBD

### SafeMath

TBD

### ScatterRewards

TBD

### Structures

TBD


## Contracts

### ScatterRouter

TBD

### BidStore

TBD

### Env

TBD

### ScatterBid

TBD


## TODO

- Separate storage from logic for upgradability?
- Migration/router contract?

## Development Setup

### General Guidlines

- Use solhint linter. Settings are in `.solhint.json`
- Clean metafile with `sb metafile cleanup` before committing new deployments

### Install Solidbyte

The [Solidbyte framework](https://github.com/mikeshultz/solidbyte) is used for dev.  Best to install
it in a Python virtual environment.

    export VENV_DIR="/path/to/venv"
    python3 -m venv $VENV_DIR
    source $VENV_DIR/bin/activate
    pip install solidbyte
