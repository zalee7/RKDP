#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-earned-showcase.sh Tests/WalletCatalogExport.swift
