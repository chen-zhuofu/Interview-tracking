#!/bin/bash
cd "$(dirname "$0")"
echo "Building & launching InterviewTracker…"
swift build || exit 1
exec .build/debug/InterviewTracker
