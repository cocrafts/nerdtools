import os
import sys

os.execvp("bun", ["bun", os.path.join(os.path.dirname(os.path.abspath(__file__)), "card-state.ts"), *sys.argv[1:]])
