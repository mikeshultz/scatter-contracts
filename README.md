# skatter-contracts

Ethereum smart contracts for skatter.online.

## Libraries

### Owned

TBD

### SafeMath

TBD

### SkatterRewards

TBD

### Structures

TBD


## Contracts

### SkatterRouter

TBD

### BidStore

TBD

### Env

TBD

### SkatterBid

TBD


## TODO

- Separate storage from logic for upgradability?
- Migration/router contract?

## Development Setup

### General Guidlines

- Use solhint linter. Settings are in `.solhint.json`
- Clean metafile with `sb metafile cleanup` before committing new deployments

### Install Solidbyte

The Solidbyte framework is used for dev.  Best to install it in a Python virtual environment.

    export VENV_DIR="/path/to/venv"
    python3 -m venv $VENV_DIR
    source $VENV_DIR/bin/activate
    pip install solidbyte
