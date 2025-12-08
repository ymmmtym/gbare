#!/bin/bash

# Integration test cleanup script

echo "Cleaning up git server..."

cd "$(dirname "$0")/.."
docker-compose down -v

echo "Cleanup complete!"
