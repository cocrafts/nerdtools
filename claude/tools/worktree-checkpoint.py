import os
import sys

os.execvp("bun", ["bun", os.path.join(os.path.dirname(os.path.abspath(__file__)), "worktree-checkpoint.ts"), *sys.argv[1:]])
