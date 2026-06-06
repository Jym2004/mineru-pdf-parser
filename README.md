# MinerU PDF Parser Skill

[English](./README.en.md)

这是一个用于运行 MinerU PDF 和文档解析的 Codex skill，支持 Ubuntu/Linux，也支持 Windows 通过 WSL2 调用 MinerU。

MinerU 可以把 PDF、图片和 Office 文档解析成 Markdown 和图片资源。这个 skill 不重新实现 MinerU，而是封装实际使用 MinerU 时容易出错的流程：安装指引、Windows 到 WSL 的路径转换、backend 选择、输出目录规则，以及可重复运行的脚本。

## 包含内容

- `SKILL.md`：Codex skill 的主说明。
- `scripts/mineru-wsl.ps1`：Windows + WSL2 runner。
- `scripts/mineru-linux.sh`：Ubuntu/Linux runner。
- `agents/openai.yaml`：skill 的 UI 元数据。

## 快速示例

Windows + WSL2 dry run：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\mineru-wsl.ps1" `
  -InputPath "D:\papers\paper.pdf" `
  -OutputRoot ".\mineru-output" `
  -Backend hybrid-auto-engine `
  -DryRun
```

Ubuntu/Linux dry run：

```bash
bash "./scripts/mineru-linux.sh" \
  --input "/path/to/paper.pdf" \
  --output-root "./mineru-output" \
  --backend hybrid-auto-engine \
  --dry-run
```

确认 dry-run 输出的命令、输入路径和输出目录都正确后，再去掉 dry-run 参数正式执行。

## 使用建议

- GPU/VLM 解析失败或资源不足时，使用 `pipeline` 作为 fallback backend。
- runner 只会把 backend 输出根目录传给 MinerU 的 `-o` 参数；每个文档自己的结果目录由 MinerU 创建。
- 成功运行后，runner 默认清理 MinerU JSON 等中间文件，只保留 `.md` 和非空 `images` 图片目录，避免输出目录占用过多空间。
- 调试 MinerU 原始输出时，Windows 使用 `-KeepIntermediate`，Linux 使用 `--keep-intermediate`。
- 完整安装、模型源、路径转换和故障处理规则见 `SKILL.md`。

## 参考链接

- MinerU 官方文档：https://opendatalab.github.io/MinerU/quick_start/
- MinerU GitHub：https://github.com/opendatalab/MinerU
