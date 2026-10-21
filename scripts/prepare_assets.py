#!/usr/bin/env python3
"""Prepara arquivos de imagem do Survev para o cliente LÖVE2D.

A fonte é a cópia PINNED no ramo referencia-survev, nunca sprites inventados.
As imagens vetoriais SVG são rasterizadas em PNG (LÖVE não carrega SVG).
Preserva a árvore de pastas, os nomes e os arquivos de atribuição.

Uso:
  python scripts/prepare_assets.py <upstream-client-public> <destination>
Requer rsvg-convert (librsvg) disponível no PATH.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import shutil
import subprocess
import sys


def prepare(source: Path, dest: Path) -> None:
    if not (source / "img").is_dir():
        raise SystemExit(f"Diretório original inexistente: {source / 'img'}")
    if shutil.which("rsvg-convert") is None:
        raise SystemExit("rsvg-convert ausente. Instale librsvg2-bin ou execute o workflow do GitHub.")
    svg_files = []
    copied = 0
    for section in ["img", "audio", "fonts", "l10n"]:
        section_root = source / section
        if not section_root.exists():
            continue
        for file in section_root.rglob("*"):
            if not file.is_file():
                continue
            out = dest / file.relative_to(source)
            out.parent.mkdir(parents=True, exist_ok=True)
            if file.suffix.lower() == ".svg":
                svg_files.append((file, out.with_suffix(".png")))
            else:
                shutil.copy2(file, out)
                copied += 1

    for name in ["attribution.txt"]:
        path = source / name
        if path.exists():
            shutil.copy2(path, dest / name)
            copied += 1

    def rasterize(entry: tuple[Path, Path]) -> None:
        src, target = entry
        subprocess.run(
            ["rsvg-convert", "--format", "png", "--output", str(target), str(src)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )

    errors = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(rasterize, task): task for task in svg_files}
        for future in as_completed(futures):
            try:
                future.result()
            except subprocess.CalledProcessError as exc:
                errors.append((futures[future][0], exc.stderr.decode("utf-8", errors="replace")))
    if errors:
        for f, err in errors[:20]:
            print(f"ERRO ao converter {f}: {err}", file=sys.stderr)
        raise SystemExit(f"Falha na conversão de {len(errors)} SVGs: não serão substituídos por desenhos falsos.")

    print(f"Arquivos originais copiados: {copied}")
    print(f"SVGs originais rasterizados: {len(svg_files)}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Uso: prepare_assets.py <upstream-client-public> <destination>")
    prepare(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())


if __name__ == "__main__":
    main()
