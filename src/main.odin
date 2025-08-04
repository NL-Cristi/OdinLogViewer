package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:math"
import rl "vendor:raylib"
import "text_analyzer"
import "core:c"
import tfd "text_analyzer/tinyfiledialogs"

// Global version variable
VERSION :: "v1.1"

main :: proc() {
    // Parse command line arguments
    args := os.args
    file_to_open := ""

    // Check for -h parameter (help/version)
    for i := 1; i < len(args); i += 1 {
        if args[i] == "-h" {
            message := fmt.tprintf("OdinLogViewer %s\n\nGithubRepo: https://github.com/NL-Cristi/OdinLogViewer", VERSION)
            message_cstr := strings.clone_to_cstring(message)
            defer delete(message_cstr)

            tfd.messageBox("OdinLogViewer", message_cstr, "ok", "info", 0)
            return
        }
    }

    // Check for -f parameter (file input)
    for i := 1; i < len(args); i += 1 {
        if args[i] == "-f" && i + 1 < len(args) {
            file_to_open = args[i + 1]
            break
        }
    }

    // Initialize raylib window with resizable flag
    rl.SetConfigFlags(rl.ConfigFlags{rl.ConfigFlags.WINDOW_RESIZABLE})

    // Configure exit keys - disable automatic exit key behavior completely
    rl.SetExitKey(rl.KeyboardKey(0)) // Set to 0 to disable automatic exit key behavior

    rl.InitWindow(1200, 800, "Text Analysis Tool")
    defer rl.CloseWindow()

    // Load the embedded font after raylib window initialization
    initial_font_size: i32 = 20

    // Load embedded font using the new embedded font functions
    font := text_analyzer.load_embedded_font(initial_font_size)

    // Check if font loaded successfully
    if font.texture.id == 0 {
        fmt.println("Error: Failed to load embedded font, using default font")
        font = rl.GetFontDefault()
    } else {
        fmt.printf("INFO: FONT: Embedded font loaded successfully (%d pixel size | %d glyphs)\n", initial_font_size, font.glyphCount)
        fmt.printf("DEBUG: Font texture ID: %d\n", font.texture.id)
        fmt.printf("DEBUG: Font base size: %d\n", font.baseSize)
    }

    // Initialize application state with the loaded font
    state := text_analyzer.init_state_with_font(font, initial_font_size, VERSION)
    defer text_analyzer.destroy_state(&state)

    // Load file based on command line argument or fallback
    if len(file_to_open) > 0 {
        if os.exists(file_to_open) {
            fmt.printf("Loading file from command line argument: %s\n", file_to_open)
            text_analyzer.load_file(&state, file_to_open)
        } else {
            fmt.printf("Error: File not found: %s\n", file_to_open)
            // Fall back to default file
            load_default_file(&state)
        }
    } else {
        // Load default file if no command line argument provided
        load_default_file(&state)
    }

    // Main loop
    should_close := false
    for !should_close {
        // Check for ALT+F4 or CTRL+W to close application
        if (rl.IsKeyDown(rl.KeyboardKey(342)) && rl.IsKeyPressed(rl.KeyboardKey(115))) || // ALT + F4
           (rl.IsKeyDown(rl.KeyboardKey(341)) && rl.IsKeyPressed(rl.KeyboardKey(87))) { // CTRL + W
            should_close = true
        } else if rl.WindowShouldClose() {
            // Check if it's an escape key press that should not close the app
            if rl.IsKeyPressed(rl.KeyboardKey(256)) { // KEY_ESCAPE
                // Don't close on ESC - let the text_analyzer handle it
                // The escape handling is done in text_analyzer.update()
            } else {
                // Close for other reasons (X button, etc.)
                should_close = true
            }
        }

        // Update
        text_analyzer.update(&state)

        // Draw
        rl.BeginDrawing()
        text_analyzer.render(&state)
        rl.EndDrawing()
    }
}

// Helper function to load default file
load_default_file :: proc(state: ^text_analyzer.State) {
    if os.exists("example.txt") {
        text_analyzer.load_file(state, "example.txt")
    } else {
        fmt.println("No default file found. Use -f parameter to specify a file to open.")
    }
}