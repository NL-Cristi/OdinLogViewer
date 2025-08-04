#!/bin/bash
echo "Building OdinLogAnalyzer..."

# Build for Linux
cp ./
odin build src -out:OdinLogAnalyzer

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Run with: ./OdinLogAnalyzer"
    echo ""
    echo "Note: To run without terminal, use: nohup ./OdinLogAnalyzer &"
    echo "Or launch from your desktop environment's application launcher"
else
    echo "Build failed!"
fi