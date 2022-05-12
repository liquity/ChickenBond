# Chicken Bonds macro economic simulations

## Pre-requisites

```
pip3 install numpy pandas plotly kaleido scipy
```

This might install newer versions of the packages than what has been tested and known to work.

If you're running into problems (such as deprecation warnings) while running the simulation, you can install the dependencies using a set of versions that is known to work:

```
pip3 install -r requirements.txt
```

### Using a virtual environment

If you're working on multiple Python projects at the same time, it's a good idea to isolate their dependencies from each other. If you were to install all dependencies globally, you could run into issues if e.g. two of your projects require different versions of the same package.

Thankfully, we can use the `venv` (virtual environment) module to avoid all this. Think of a virtual environment as a local installation site of Python that starts with a blank slate (apart from the few modules needed for installing further modules), thus being isolated from dependencies installed elsewhere.

To create a new virtual environment in directory `.venv`:

```
python3 -m venv .venv
```

To use the virtual environment in your current shell:

```
source .venv/bin/activate
```

(If this doesn't work, you might have to use a different activate script for your shell of choice, for example `.venv/bin/activate.fish` in case of the fish shell).

Once the environment is active, the `python3` and `pip3` commands can be used as usual but they will act inside the virtual environment. This means you can install dependencies in the same way as you would globally.

> **Note:** remember to activate your virtual environment everytime you want to work on the project in a new shell.

## Running

```
python3 ./chicken_bonds.py
```
