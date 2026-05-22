#!/bin/bash
# Script to flatten the plugins directory for OpenKore
cd plugins || exit
echo "Moving plugins to root..."
find plugins.diag -name "*.pl" -type f -exec mv {} . \;
echo "Cleanup empty directories..."
find plugins.diag -type d -empty -delete
echo "Done."
