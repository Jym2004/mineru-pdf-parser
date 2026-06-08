# MinerU PDF Parser Skill

[中文](./README.md)

A Codex skill for running MinerU PDF and document parsing on Ubuntu/Linux or Windows through WSL2.

MinerU converts PDFs, images, and Office documents into Markdown and extracted image assets. This skill does not reimplement MinerU. It wraps the practical workflow around MinerU: installation guidance, Windows-to-WSL path conversion, backend selection, output directory conventions, and repeatable runner scripts.

## What It Includes

- `SKILL.md`: the Codex skill instructions.
- `scripts/mineru-wsl.ps1`: Windows + WSL2 runner.
- `scripts/mineru-linux.sh`: Ubuntu/Linux runner.
- `agents/openai.yaml`: UI metadata for the skill.

## Quick Examples

Windows + WSL2 dry run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\mineru-wsl.ps1" `
  -InputPath "D:\papers\paper.pdf" `
  -OutputRoot ".\mineru-output" `
  -Backend hybrid-auto-engine `
  -DryRun
```

Ubuntu/Linux dry run:

```bash
bash "./scripts/mineru-linux.sh" \
  --input "/path/to/paper.pdf" \
  --output-root "./mineru-output" \
  --backend hybrid-auto-engine \
  --dry-run
```

Remove the dry-run flag after checking the generated command, input path, and output directory.

## Notes

- Use `pipeline` as the fallback backend when GPU/VLM parsing fails or resources are limited.
- The runners pass only the backend output root to MinerU's `-o`; MinerU creates per-document result directories itself.
- Install mode uses the latest MinerU release by default. Use `-MineruVersion` on Windows or `--mineru-version` on Linux when a pinned version is required.
- Successful runs clean MinerU JSON and other intermediate files by default, keeping only `.md` files and non-empty `images` folders.
- Use `-KeepIntermediate` on Windows or `--keep-intermediate` on Linux only when debugging raw MinerU output.
- See `SKILL.md` for full installation, model source, path conversion, and troubleshooting guidance.

## References

- MinerU documentation: https://opendatalab.github.io/MinerU/quick_start/
- MinerU GitHub: https://github.com/opendatalab/MinerU
