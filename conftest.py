# This file is intentionally empty.
#
# Its mere presence at the repository root tells pytest that THIS folder is
# the project root, and pytest adds it to the import path. That is what lets
# the tests do `from app.main import app` without any extra configuration or
# environment variables. Without it, pytest might not find the `app` package.
