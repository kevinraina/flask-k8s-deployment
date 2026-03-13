#!/bin/bash
set -e

echo "==============================="
echo " Full Pipeline: Build → Push → Deploy"
echo "==============================="

bash scripts/build.sh
bash scripts/push.sh
bash scripts/deploy.sh

echo "Pipeline complete!"
