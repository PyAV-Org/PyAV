# Dev Workflow

Run `source ./scripts/activate.sh` if not in virtualenv

# 1. Make changes

# 2. Build

make

# 3. Test

make test # All tests
python -m pytest tests/some_file.py # Individual file
python -m pytest -k "substring"

# 4. Lint before commiting

make lint

# Gotchas

- Uses Cython so look out for UB
