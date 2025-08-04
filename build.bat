@echo off
echo Building OdinLogViewer for Windows (GUI mode)...
copy .\src\resources\CascadiaCode\CaskaydiaCoveNerdFont-Regular.ttf .\Binary\MyFont.ttf
copy .\src\resources\CascadiaCode\CaskaydiaCoveNerdFont-Regular.ttf .\MyFont.ttf
odin build .\src -out:.\Binary\OdinLogViewer.exe -subsystem:windows

if %ERRORLEVEL% EQU 0 (
    echo Build successful!
    echo Run with: OdinLogViewer.exe
    echo Note: No console window will appear - only the GUI
) else (
    echo Build failed!
)
pause