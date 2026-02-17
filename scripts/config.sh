#!/usr/bin/env bash
# scripts/config.sh — 共通設定 (各スクリプトから source される)
IMAGE_NAME="${IMAGE_NAME:-mt-base-image}"
# shellcheck disable=SC2034
PERL_VERSIONS=("5.16" "5.32")
