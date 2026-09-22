#!/bin/bash
set -e
cd "$(dirname "$0")/../src/logging-system"
rm -f ../../lambda_package.zip
zip ../../lambda_package.zip lambda_function.py
echo "lambda_package.zip generado"
