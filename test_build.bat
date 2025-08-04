@echo off
echo Testing Odin Text Analyzer Build...
echo.

echo Checking if Odin is available...
odin version
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Odin compiler not found in PATH
    echo Please install Odin and add it to your PATH
    pause
    exit /b 1
)

echo.
echo Building project...
odin build src -out:text_analyzer.exe
if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: Build completed successfully!
    echo.
    echo To run the application:
    echo text_analyzer.exe
    echo.
    echo The application will load example.txt if it exists.
) else (
    echo.
    echo ERROR: Build failed!
    echo Please check the error messages above.
)

pause