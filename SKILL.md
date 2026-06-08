---
name: mineru-pdf-parser
description: Parse PDFs or document files with MinerU on Ubuntu/Linux or Windows through WSL2. Use when Codex needs to install MinerU, choose between native Ubuntu and Windows WSL workflows, convert Windows paths to WSL paths, run MinerU backends such as pipeline, vlm-auto-engine, or hybrid-auto-engine, and save Markdown plus image outputs without relying on machine-specific private paths.
---

# MinerU PDF Parser

Use MinerU to convert PDFs and supported document files into Markdown, JSON, and extracted assets. Prefer the bundled runner scripts for repeatable execution:

- Windows with WSL2: use `scripts/mineru-wsl.ps1`.
- Ubuntu or other Linux: use `scripts/mineru-linux.sh`.

Use raw commands only when the user explicitly asks for them or a runner script cannot fit the environment.

Do not assume local usernames, private folders, cloud-drive folders, or a specific WSL distro name. Ask for or infer only from paths the user provides.

## Official References

Use these as the source of truth when installation details look stale:

- MinerU Quick Start: https://opendatalab.github.io/MinerU/quick_start/
- MinerU Extension Modules: https://opendatalab.github.io/MinerU/quick_start/extension_modules/
- MinerU Model Source: https://opendatalab.github.io/MinerU/usage/model_source/
- MinerU GitHub: https://github.com/opendatalab/MinerU

## Environment Decision

1. If the user gives a Windows path such as `C:\...` or `D:\...`, prefer Windows WSL2.
2. If the user gives a Linux path such as `/home/...`, `/mnt/...`, or `~/...`, prefer native Ubuntu/Linux.
3. If the user does not say which WSL distro to use, run `wsl -l -v` and choose an installed Ubuntu distro. Do not assume any specific distro alias.
4. If no GPU or less than 8 GB VRAM is available, prefer `pipeline`.
5. If an 8 GB or larger NVIDIA GPU is available, prefer `hybrid-auto-engine` for quality, with `pipeline` as fallback.

## Information To Resolve Before Running

Resolve these values before invoking MinerU:

- `InputPath`: one or more files or an expanded list from a directory.
- `Environment`: Windows WSL2 or native Ubuntu/Linux.
- `OutputRoot`: default to `./mineru-output` unless the user requests another location.
- `Backend`: default to `hybrid-auto-engine` when a suitable GPU is available; otherwise use `pipeline`.
- `Distro`: for Windows WSL2, use `wsl -l -v` when not supplied. The WSL runner auto-selects an installed Ubuntu distro when possible.
- `VenvPath`: default to `~/venvs/mineru`.
- `ModelSource`: leave unset by default; use `modelscope` when Hugging Face is slow or blocked.
- `MineruVersion`: leave unset to install the latest available MinerU release; set it only when the user needs a pinned version.
- `Install`: use only when MinerU is missing or the user asks to install it.

Run the relevant script with `--dry-run` or `-DryRun` first when paths contain spaces, Unicode, or shell-special characters.

## Version Strategy

Do not pin MinerU by default. The runner install mode uses the latest available MinerU release unless the user provides a version. This keeps normal MinerU upgrades independent from skill updates.

Update this skill only when a MinerU release changes CLI flags, backend names, installation extras, model source behavior, or output layout in a way that breaks the documented workflow.

For safer upgrades, install a new environment first, run a representative PDF, then switch the runner to that environment:

```bash
python3 -m venv ~/venvs/mineru-<version>
bash "<skill-dir>/scripts/mineru-linux.sh" --input "/path/to/test.pdf" --venv ~/venvs/mineru-<version> --install --mineru-version <version> --dry-run
```

## Requirements

MinerU's documented local deployment support includes:

- Python 3.10 to 3.13 on Linux.
- Python 3.10 to 3.12 on native Windows because a key dependency does not support Python 3.13 there.
- Linux distributions from 2019 or later.
- `pipeline` backend for CPU-compatible parsing.
- VLM or hybrid auto engine for higher quality when the machine has sufficient GPU resources, commonly 8 GB or more VRAM.
- At least 20 GB free disk space for full local deployment is a practical baseline.

## Install MinerU

### Ubuntu Or Linux

Use a dedicated virtual environment:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip build-essential
python3 -m venv ~/venvs/mineru
source ~/venvs/mineru/bin/activate
python -m pip install --upgrade pip uv
uv pip install -U "mineru[all]"
mineru --help
```

Use a smaller install only when the task needs it:

```bash
uv pip install -U "mineru[core]"
uv pip install -U "mineru[core,vllm]"
uv pip install -U "mineru[core,lmdeploy]"
```

Do not install both `vllm` and `lmdeploy` extras unless there is a clear reason; MinerU documents them as alternative acceleration choices.

### Windows With WSL2

First identify the installed distro:

```powershell
wsl -l -v
```

Install inside the selected distro:

```powershell
wsl -d <DistroName>
```

Then run inside the Linux shell:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip build-essential
python3 -m venv ~/venvs/mineru
source ~/venvs/mineru/bin/activate
python -m pip install --upgrade pip uv
uv pip install -U "mineru[all]"
mineru --help
```

For repeated Windows calls, wrap the command with `wsl -d <DistroName> -- bash -lc ...`.

The bundled scripts can install MinerU when requested:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\mineru-wsl.ps1" `
  -InputPath "C:\path\to\paper.pdf" `
  -Install `
  -DryRun
```

```bash
bash "<skill-dir>/scripts/mineru-linux.sh" --input "/path/to/paper.pdf" --install --dry-run
```

To pin a specific MinerU version during install:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\mineru-wsl.ps1" `
  -InputPath "C:\path\to\paper.pdf" `
  -Install `
  -MineruVersion "3.2.1" `
  -DryRun
```

```bash
bash "<skill-dir>/scripts/mineru-linux.sh" --input "/path/to/paper.pdf" --install --mineru-version "3.2.1" --dry-run
```

## Model Source

MinerU uses Hugging Face as the default model source. Use ModelScope when Hugging Face is slow or blocked:

```bash
export MINERU_MODEL_SOURCE=modelscope
```

Use local models only after `mineru-models-download` has created or updated the user's MinerU model config:

```bash
mineru-models-download
export MINERU_MODEL_SOURCE=local
```

Set `MINERU_MODEL_SOURCE` in the shell before running `mineru`; do not invent a `mineru` CLI flag for model source.

## Run On Ubuntu Or Linux

Use the bundled script. It creates a backend-specific output root and does not append the PDF basename to `-o`.

```bash
bash "<skill-dir>/scripts/mineru-linux.sh" \
  --input "/path/to/paper.pdf" \
  --output-root "./mineru-output" \
  --backend hybrid-auto-engine
```

Use `--install` when the virtual environment does not exist. Use `--model-source modelscope` when needed.
By default, the runner removes MinerU JSON and other intermediate files after a successful run, keeping only Markdown files and files inside `images` directories. Pass `--keep-intermediate` only when debugging MinerU raw output.

Raw equivalent:

```bash
source ~/venvs/mineru/bin/activate
mkdir -p "$HOME/mineru-output/hybrid-auto-engine"
mineru -p "/path/to/paper.pdf" -o "$HOME/mineru-output/hybrid-auto-engine" -b hybrid-auto-engine
```

CPU fallback:

```bash
source ~/venvs/mineru/bin/activate
mkdir -p "$HOME/mineru-output/pipeline"
mineru -p "/path/to/paper.pdf" -o "$HOME/mineru-output/pipeline" -b pipeline
```

## Run On Windows With WSL2

Convert paths before calling WSL:

- `C:\Users\Example\Documents\paper.pdf` becomes `/mnt/c/Users/Example/Documents/paper.pdf`.
- `D:\papers\paper.pdf` becomes `/mnt/d/papers/paper.pdf`.

Use the bundled script from PowerShell. It discovers installed WSL distros, chooses an Ubuntu distro when `-Distro` is omitted, converts Windows paths to WSL paths, and quotes paths safely.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\mineru-wsl.ps1" `
  -InputPath "C:\Users\Example\Documents\paper.pdf" `
  -OutputRoot ".\mineru-output" `
  -Backend hybrid-auto-engine `
  -DryRun
```

Remove `-DryRun` after the printed command and output root look correct. Pass `-Distro "<DistroName>"` when auto-selection chooses the wrong distro. Pass `-Install` when MinerU is not installed in the selected distro.
By default, the runner removes MinerU JSON and other intermediate files after a successful run, keeping only Markdown files and files inside `images` directories. Pass `-KeepIntermediate` only when debugging MinerU raw output.

Raw equivalent:

From PowerShell, call WSL directly and keep the Linux command in single quotes:

```powershell
wsl -d <DistroName> -- bash -lc 'source ~/venvs/mineru/bin/activate && mkdir -p ~/mineru-output/hybrid-auto-engine && mineru -p "/mnt/c/Users/Example/Documents/paper.pdf" -o ~/mineru-output/hybrid-auto-engine -b hybrid-auto-engine'
```

If writing output back to Windows storage, pass a WSL-mounted output root:

```powershell
wsl -d <DistroName> -- bash -lc 'source ~/venvs/mineru/bin/activate && mkdir -p "/mnt/c/Users/Example/Documents/mineru-output/hybrid-auto-engine" && mineru -p "/mnt/c/Users/Example/Documents/paper.pdf" -o "/mnt/c/Users/Example/Documents/mineru-output/hybrid-auto-engine" -b hybrid-auto-engine'
```

Use `powershell -NoProfile` when launching these commands from a non-interactive wrapper, so the user's PowerShell profile does not add unrelated startup output.

Prefer output under the Linux filesystem, such as `~/mineru-output`, for speed. Use `/mnt/c/...` or `/mnt/d/...` when the user needs files immediately visible in Windows.

## Output Layout

Use this convention:

```text
<chosen-output-root>/<backend>/<document-name>/<mineru-backend-result-dir>/
```

Examples:

```text
~/mineru-output/hybrid-auto-engine/paper/hybrid_auto/paper.md
~/mineru-output/pipeline/paper/auto/paper.md
```

The backend-specific result directory name is created by MinerU and may vary by version and backend. After completion, find Markdown with:

The bundled runners clean successful outputs by default. The retained tree should contain the generated `.md` files and any non-empty `images` folders with image assets. Use `--keep-intermediate` on Linux or `-KeepIntermediate` on Windows only when the intermediate JSON/layout files are needed for troubleshooting.

```bash
find "$HOME/mineru-output" -name "*.md" -print
```

On Windows:

```powershell
Get-ChildItem -Path "<OutputRoot>" -Recurse -Filter *.md
```

## Path And Quoting Rules

- Quote every input and output path.
- Preserve spaces and Unicode characters.
- Strip a leading `file:///` URL prefix before path conversion.
- Convert only drive-letter Windows paths to `/mnt/<drive>/...` for WSL.
- Do not pass raw Windows paths like `D:\...` directly to Linux commands.
- Do not append the document basename to `-o`; pass the backend-specific root only.

## Troubleshooting

- `WSL_E_DISTRO_NOT_FOUND`: run `wsl -l -v`, then retry with an installed distro name.
- `conda activate` fails: use the virtualenv workflow above, or verify the user's conda init script and environment name.
- CUDA or VLM backend fails: retry with `-b pipeline`.
- GPU memory is insufficient: retry `pipeline`, or lower backend-specific GPU memory options only when `mineru --help` confirms the installed version supports them.
- Model download fails: switch between Hugging Face and ModelScope with `MINERU_MODEL_SOURCE`.
- Output path is empty: confirm `-o` points to an existing writable directory parent and search recursively for `*.md`.

## Reporting

After running MinerU, report:

- Environment used: Ubuntu/Linux or Windows WSL2, and distro name when applicable.
- Backend used.
- Input path.
- Output root passed to `-o`.
- Markdown files found.
- Any fallback used, such as `hybrid-auto-engine` to `pipeline`.
