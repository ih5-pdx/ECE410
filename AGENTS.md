# AGENTS.md

## Cursor Cloud specific instructions

This is a university AI/ML course repository (ECE 410). It uses Python 3 with common ML/data-science libraries.

### Installed packages

`numpy`, `pandas`, `scikit-learn`, `matplotlib`, `jupyter` (and their dependencies) are installed via `pip3 install`.

### Running code

- Python scripts: `python3 <script.py>`
- Jupyter notebooks: `jupyter notebook --no-browser --ip=0.0.0.0` (or `jupyter lab`)
- The `~/.local/bin` directory must be on `PATH` for Jupyter CLI tools: `export PATH="$HOME/.local/bin:$PATH"`

### Notes

- Matplotlib requires the `Agg` backend for non-interactive (headless) plot generation: `matplotlib.use('Agg')`.
- There is no linter, test suite, or build system configured yet — the repo is in early stages.
- As homework files (`.py`, `.ipynb`) are added, run them directly with `python3` or `jupyter`.
