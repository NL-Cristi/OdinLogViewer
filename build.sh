#!/bin/bash
echo "Building OdinLogAnalyzer..."

# Build for Linux
cp ./src/resources/CascadiaCode/CaskaydiaCoveNerdFont-Regular.ttf ./Binary/MyFont.ttf
cp ./src/resources/CascadiaCode/CaskaydiaCoveNerdFont-Regular.ttf ./MyFont.ttf
odin build src -out:./Binary/OdinLogViewer

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "Run with: ./OdinLogViewer"
    echo ""
    echo "Note: To run without terminal, use: nohup ./OdinLogViewer &"
    echo "Or launch from your desktop environment's application launcher"
else
    echo "Build failed!"
fi