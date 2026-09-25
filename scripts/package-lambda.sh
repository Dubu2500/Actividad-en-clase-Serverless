#!/bin/bash
set -e
# Empaqueta cada carpeta de src/ en build/<nombre>.zip
cd "$(dirname "$0")/.."
mkdir -p build
for dir in src/*/; do
  NAME=$(basename "$dir")
  rm -f "build/$NAME.zip"
  (cd "$dir" && zip -q -r "../../build/$NAME.zip" .)
  echo "build/$NAME.zip generado"
done