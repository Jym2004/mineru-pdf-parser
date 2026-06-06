#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: mineru-linux.sh --input PATH [--input PATH ...] [options]

Options:
  --backend pipeline|vlm-auto-engine|hybrid-auto-engine
      MinerU backend. Default: hybrid-auto-engine.
  --output-root PATH
      Output root. Default: ./mineru-output.
  --venv PATH
      Python virtual environment path. Default: ~/venvs/mineru.
  --model-source VALUE
      Set MINERU_MODEL_SOURCE, for example modelscope, huggingface, or local.
  --install
      Create the venv and install mineru[all] before running.
  --dry-run
      Print commands without executing MinerU.
  --keep-intermediate
      Keep MinerU JSON and other intermediate files. Default keeps only Markdown and images.
  -h, --help
      Show this help.
EOF
}

backend="hybrid-auto-engine"
output_root="$PWD/mineru-output"
venv_path="$HOME/venvs/mineru"
model_source=""
install=0
dry_run=0
keep_intermediate=0
inputs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      [[ $# -ge 2 ]] || { echo "--input requires a value" >&2; exit 2; }
      inputs+=("$2")
      shift 2
      ;;
    --backend)
      [[ $# -ge 2 ]] || { echo "--backend requires a value" >&2; exit 2; }
      backend="$2"
      shift 2
      ;;
    --output-root)
      [[ $# -ge 2 ]] || { echo "--output-root requires a value" >&2; exit 2; }
      output_root="$2"
      shift 2
      ;;
    --venv)
      [[ $# -ge 2 ]] || { echo "--venv requires a value" >&2; exit 2; }
      venv_path="$2"
      shift 2
      ;;
    --model-source)
      [[ $# -ge 2 ]] || { echo "--model-source requires a value" >&2; exit 2; }
      model_source="$2"
      shift 2
      ;;
    --install)
      install=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --keep-intermediate)
      keep_intermediate=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ${#inputs[@]} -eq 0 ]]; then
  echo "At least one --input path is required." >&2
  usage >&2
  exit 2
fi

case "$backend" in
  pipeline|vlm-auto-engine|hybrid-auto-engine) ;;
  *)
    echo "Unsupported backend: $backend" >&2
    exit 2
    ;;
esac

run_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [[ "$dry_run" -eq 0 ]]; then
    "$@"
  fi
}

activate_venv() {
  printf '+ source %q\n' "$venv_path/bin/activate"
  if [[ "$dry_run" -eq 0 ]]; then
    # shellcheck disable=SC1091
    source "$venv_path/bin/activate"
  fi
}

clean_intermediate_outputs() {
  local root="$1"
  [[ -d "$root" ]] || return 0

  while IFS= read -r -d '' file; do
    local filename parent ext
    filename="$(basename "$file")"
    parent="$(basename "$(dirname "$file")")"
    ext="${filename##*.}"
    ext="${ext,,}"

    if [[ "$ext" == "md" ]]; then
      continue
    fi

    if [[ "$parent" == "images" ]]; then
      case "$ext" in
        jpg|jpeg|png|webp|gif|bmp|tif|tiff|svg)
          continue
          ;;
      esac
    fi

    rm -f -- "$file"
  done < <(find "$root" -type f -print0)

  find "$root" -depth -type d -empty -delete
}

if [[ "$install" -eq 1 ]]; then
  run_cmd sudo apt update
  run_cmd sudo apt install -y python3 python3-venv python3-pip build-essential
  run_cmd python3 -m venv "$venv_path"
  activate_venv
  run_cmd python -m pip install --upgrade pip uv
  run_cmd uv pip install -U "mineru[all]"
else
  if [[ ! -f "$venv_path/bin/activate" && "$dry_run" -eq 0 ]]; then
    echo "Virtual environment not found: $venv_path" >&2
    echo "Run with --install or pass --venv PATH." >&2
    exit 1
  fi
  activate_venv
fi

if [[ -n "$model_source" ]]; then
  export MINERU_MODEL_SOURCE="$model_source"
fi

backend_output_root="$output_root/$backend"
run_cmd mkdir -p "$backend_output_root"

for input in "${inputs[@]}"; do
  if [[ ! -f "$input" ]]; then
    echo "Input file not found: $input" >&2
    exit 1
  fi

  base_name="$(basename "$input")"
  doc_name="${base_name%.*}"
  printf 'Input: %s\n' "$input"
  printf 'Output root passed to -o: %s\n' "$backend_output_root"
  printf 'Expected per-document directory: %s/%s\n' "$backend_output_root" "$doc_name"
  run_cmd mineru -p "$input" -o "$backend_output_root" -b "$backend"
done

if [[ "$dry_run" -eq 0 && "$keep_intermediate" -eq 0 ]]; then
  printf 'Cleaning intermediate outputs; keeping Markdown files and images folders.\n'
  clean_intermediate_outputs "$backend_output_root"
fi

printf 'Markdown files:\n'
find "$backend_output_root" -name '*.md' -print 2>/dev/null || true
