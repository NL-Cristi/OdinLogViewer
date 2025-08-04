# OdinLogViewer

A cross-platform log file viewer and text analysis tool implemented in Odin using raylib, inspired by TextAnalysisTool.NET. This application provides advanced text viewing capabilities with features like word wrap, line numbers, text search, filtering, and highlighting.

## Features

### Core Functionality ✅
- **File Loading**: Open and view text/log files with native file dialogs
- **Word Wrap**: Toggle word wrap on/off for better text readability
- **Line Numbers**: Display line numbers with toggle functionality
- **Virtual Scrolling**: Smooth scrolling with mouse wheel support
- **Font Scaling**: Dynamic font size adjustment (CTRL+=, CTRL+-)

### Text Analysis Features ✅
- **Find Functionality**: Search text with case-sensitive options
- **Line Filtering**: Filter lines based on text content
- **Text Highlighting**: Highlight specific text patterns
- **Line Selection**: Select and mark specific lines
- **Save Display**: Save current filtered/processed view to file

### User Interface ✅
- **Modern GUI**: Clean interface with buttons and toggles
- **Keyboard Shortcuts**: Comprehensive shortcut support
- **Help System**: Built-in help dialog with all shortcuts
- **Version Information**: Command-line version display (-h parameter)
- **Responsive Design**: Adapts to window resizing

### Advanced Features ✅
- **Custom Fonts**: Support for custom fonts (rename any .ttf file to `MyFont.ttf`)
- **Embedded Fonts**: Currently uses CaskaydiaCoveNerdFontMono-Regular.ttf (renamed to MyFont.ttf)
- **Theme Support**: Dark and light color themes
- **Cross-Platform**: Works on Windows, Linux, and macOS
- **Memory Efficient**: Handles large files with virtual scrolling

## Keyboard Shortcuts

### File Operations
- `CTRL+O` - Open file dialog
- `ALT+S` - Save current display to file

### App Control
- `ALT+F4` / `CTRL+W` - Close application
- `ESC` - Close dialogs or clear input fields

### Display Options
- `ALT+Z` - Toggle word wrap
- `ALT+N` - Toggle line numbers
- `CTRL+=` - Increase font size
- `CTRL+-` - Decrease font size

### Text Analysis
- `CTRL+F` - Open find dialog
- `ALT+F` - Open filter dialog
- `ALT+H` - Open highlight dialog
- `CTRL+H` - Open help dialog

### Navigation
- Mouse wheel - Scroll through text
- Arrow keys - Navigate through text

## Building and Running

### Prerequisites
- [Odin compiler](https://odin-lang.org/docs/install/) installed
- raylib vendor package available

### Build Commands

#### Windows (GUI mode - recommended)
```bash
# Use the provided build script
build.bat

# Or build manually
odin build src/main.odin -out:Binary/OdinLogViewer.exe -subsystem:windows
```

#### Windows (Console mode - for debugging)
```bash
odin build src/main.odin -out:Binary/OdinLogViewer.exe
```

#### Linux/macOS
```bash
# Use the provided build script
./build.sh

# Or build manually
odin build src/main.odin -out:Binary/OdinLogViewer
```

### Running the Application

#### Normal Mode
```bash
# Windows
Binary/OdinLogViewer.exe

# Linux/macOS
./Binary/OdinLogViewer
```

#### Command Line Parameters
```bash
# Display version information
OdinLogViewer.exe -h

# Open a specific file
OdinLogViewer.exe -f path/to/your/file.txt
```

## Project Structure

```
OdinLogViewer/
├── src/
│   ├── main.odin                    # Main entry point and command-line parsing
│   └── text_analyzer/
│       ├── text_analyzer.odin       # Core functionality and UI rendering
│       ├── filters.odin             # Filter system implementation
│       └── tinyfiledialogs/         # Native file dialogs integration
├── Binary/                          # Build output directory
├── build.bat                        # Windows build script
├── build.sh                         # Linux/macOS build script
├── MyFont.ttf                       # Custom font (CaskaydiaCoveNerdFontMono-Regular.ttf)
└── example.txt                      # Sample file for testing
```

## Usage

1. **Start the Application**: Run the executable to open the main window
2. **Load a File**: Use `CTRL+O` or the Open button to select a text/log file
3. **Navigate**: Use mouse wheel to scroll through the text
4. **Search**: Press `CTRL+F` to open the find dialog
5. **Filter**: Press `ALT+F` to filter lines based on text content
6. **Highlight**: Press `ALT+H` to highlight specific text patterns
7. **Adjust Display**: Use `ALT+Z` for word wrap, `ALT+N` for line numbers
8. **Font Scaling**: Use `CTRL+=` and `CTRL+-` to adjust font size
9. **Get Help**: Press `CTRL+H` to view all available shortcuts

## Technical Implementation

### Core Technologies
- **Odin Language**: High-performance systems programming language
- **Raylib**: Cross-platform graphics and input library
- **Raygui**: Immediate mode GUI library
- **TinyFileDialogs**: Native file dialog integration

### Key Features
- **Virtual Scrolling**: Only renders visible lines for performance
- **Dynamic Font Loading**: Custom font support with fallback to system default
- **Font Customization**: Any .ttf font file can be used by renaming it to `MyFont.ttf`
- **Memory Management**: Efficient string handling and cleanup
- **Cross-Platform**: Single codebase for Windows, Linux, and macOS

### Performance Optimizations
- Virtual scrolling for large files
- Efficient text measurement and rendering
- Proper memory management with defer statements
- Optimized string operations

## Inspired By

This project is inspired by [TextAnalysisTool.NET](https://textanalysistool.com/), a powerful log file analysis tool. OdinLogViewer aims to provide similar functionality while leveraging the performance and cross-platform capabilities of the Odin programming language.

## Version

Current version: v1.1

## License

This project is open source and follows the same license as the Odin programming language.