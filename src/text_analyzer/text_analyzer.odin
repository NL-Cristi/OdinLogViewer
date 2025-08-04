package text_analyzer

import "core:fmt"
import "core:os"
import "core:strings"
import "core:math"
import rl "vendor:raylib"
import "core:c"
import tfd "tinyfiledialogs"

// Font loading functions
@(export)
load_embedded_font :: proc(font_size: i32) -> rl.Font {
    font_file := strings.clone_to_cstring("MyFont.ttf")
    defer delete(font_file)

    // Use LoadFontEx to load font at the specified size
    font := rl.LoadFontEx(font_file, font_size, nil, 0)

    // Check if font loaded successfully
    if font.texture.id == 0 {
        fmt.println("Warning: Failed to load MyFont.ttf, using default font")
        return rl.GetFontDefault()
    }

    fmt.printf("DEBUG: Loaded font from MyFont.ttf at size %d - texture ID: %d, base size: %d, glyph count: %d\n",
               font_size, font.texture.id, font.baseSize, font.glyphCount)

    return font
}

// Reload font (for font size changes)
@(export)
reload_embedded_font :: proc(font_size: i32) -> rl.Font {
    return load_embedded_font(font_size)
}

// State management (Phase 1.3)
State :: struct {
    logical_lines: [dynamic]string,
    display_lines: [dynamic]DisplayLine,
    scroll_offset: f32,
    word_wrap: bool,
    show_line_numbers: bool,
    needs_redraw_display_lines: bool,
    font_size: i32,
    font: rl.Font,
    text_area: rl.Rectangle,
    menu_height: f32,
    // Advanced features (Phase 3)
    filters: [dynamic]Filter,
    find_text: string,
    find_history: [dynamic]string,
    marked_lines: map[int]bool,
    selected_lines: [dynamic]int,
    show_filter_dialog: bool,
    filter_input: string,
    show_find_dialog: bool,
    find_input: string,
    show_highlight_dialog: bool,
    highlight_input: string,
    highlight_color: rl.Color,
    show_help_dialog: bool,
    active_input_field: InputField,
    original_lines: [dynamic]string, // Keep original lines for filtering
    editing_filter_index: int, // Track which filter is being edited
    editing_highlight_index: int, // Track which highlight is being edited
    clicked_line: int, // Track which line was clicked (-1 if none)
    last_clicked_line: int, // Track last clicked line for range selection
    highlights: [dynamic]Highlight, // Color highlighting rules
    theme: Theme, // Current theme (Light/Dark)
    // Search state
    current_search_position: int, // Current position for search (display line index)
    show_search_message: bool, // Show "nothing found" message
    search_message_timer: f32, // Timer for search message
    // Application version
    version: string,
}

DisplayLine :: struct {
    logical_line_index: int,
    is_first_of_logical: bool,
    text: string,
}

Filter :: struct {
    type: FilterType,
    pattern: string,
    is_regex: bool,
    enabled: bool,
}

Highlight :: struct {
    type: HighlightType,
    pattern: string,
    color: rl.Color,
    enabled: bool,
}

FilterType :: enum {
    Include,
    Exclude,
}

HighlightType :: enum {
    Background,
    Letters,
}

InputField :: enum {
    None,
    Filter,
    Find,
    Highlight,
}

Theme :: enum {
    Light,
    Dark,
}

ThemeColors :: struct {
    background: rl.Color,
    text: rl.Color,
    menu_background: rl.Color,
    menu_text: rl.Color,
    border: rl.Color,
    selection: rl.Color,
    dialog_background: rl.Color,
    dialog_text: rl.Color,
    input_background: rl.Color,
    input_text: rl.Color,
    input_border: rl.Color,
    button_background: rl.Color,
    button_text: rl.Color,
}

// Theme color functions
get_theme_colors :: proc(theme: Theme) -> ThemeColors {
    switch theme {
    case .Light:
        return ThemeColors{
            background = rl.WHITE,
            text = rl.BLACK,
            menu_background = rl.LIGHTGRAY,
            menu_text = rl.BLACK,
            border = rl.GRAY,
            selection = rl.Color{255, 255, 0, 100}, // Light yellow
            dialog_background = rl.LIGHTGRAY,
            dialog_text = rl.BLACK,
            input_background = rl.WHITE,
            input_text = rl.BLACK,
            input_border = rl.DARKGRAY,
            button_background = rl.LIGHTGRAY,
            button_text = rl.BLACK,
        }
    case .Dark:
        return ThemeColors{
            background = rl.Color{30, 30, 30, 255}, // Dark gray
            text = rl.Color{220, 220, 220, 255}, // Light gray
            menu_background = rl.Color{50, 50, 50, 255}, // Darker gray
            menu_text = rl.Color{220, 220, 220, 255}, // Light gray
            border = rl.Color{100, 100, 100, 255}, // Medium gray
            selection = rl.Color{255, 255, 0, 100}, // Light yellow (same for visibility)
            dialog_background = rl.Color{50, 50, 50, 255}, // Darker gray
            dialog_text = rl.Color{220, 220, 220, 255}, // Light gray
            input_background = rl.Color{60, 60, 60, 255}, // Slightly lighter dark
            input_text = rl.Color{220, 220, 220, 255}, // Light gray
            input_border = rl.Color{120, 120, 120, 255}, // Medium gray
            button_background = rl.Color{70, 70, 70, 255}, // Medium dark
            button_text = rl.Color{220, 220, 220, 255}, // Light gray
        }
    }
    return get_theme_colors(.Light) // Default fallback
}



// Initialize and destroy state
// Note: init_state() is removed as main.odin uses init_state_with_font() directly
// to avoid duplicate font loading logic

// Initialize state with a pre-loaded font
init_state_with_font :: proc(font: rl.Font, font_size: i32, version: string) -> State {
    return State{
        logical_lines = make([dynamic]string),
        display_lines = make([dynamic]DisplayLine),
        scroll_offset = 0,
        word_wrap = false,
        show_line_numbers = false,
        needs_redraw_display_lines = true,
        font_size = font_size,
        font = font,
        text_area = {10, 60, 1180, 720},
        menu_height = 50,
        filters = make([dynamic]Filter),
        find_text = "",
        find_history = make([dynamic]string),
        marked_lines = make(map[int]bool),
        selected_lines = make([dynamic]int),
        show_filter_dialog = false,
        filter_input = "",
        version = version,
        show_find_dialog = false,
        find_input = "",
        show_highlight_dialog = false,
        highlight_input = "",
        highlight_color = rl.RED,
        active_input_field = .None,
        original_lines = make([dynamic]string),
        editing_filter_index = -1,
        editing_highlight_index = -1,
        clicked_line = -1,
        last_clicked_line = -1,
        highlights = make([dynamic]Highlight),
        theme = .Dark, // Start with light theme
        current_search_position = -1,
        show_search_message = false,
        search_message_timer = 0,
    }
}

destroy_state :: proc(state: ^State) {
    delete(state.logical_lines)
    delete(state.display_lines)
    delete(state.filters)
    delete(state.find_history)
    clear(&state.marked_lines)
    delete(state.selected_lines)
    delete(state.original_lines)
    delete(state.highlights)
    rl.UnloadFont(state.font)
}

// File handling (Phase 2.1)
load_file :: proc(state: ^State, filename: string) {
    if content, ok := os.read_entire_file(filename); ok {
        defer delete(content)

        // Clear existing lines
        clear(&state.logical_lines)
        clear(&state.original_lines)

        // Split into logical lines
        lines := strings.split_lines(string(content))
        for line in lines {
            original_line := strings.clone(line)
            append(&state.original_lines, original_line)
            append(&state.logical_lines, strings.clone(original_line))
        }

        // Regenerate display lines
        state.needs_redraw_display_lines = true
        state.scroll_offset = 0
    }
}

// Save current display content to file
save_current_display_to_file :: proc(state: ^State, filename: string) {
    // Build the content to save based on current display
    content := strings.builder_make()
    defer strings.builder_destroy(&content)

    // Save the current display lines (what the user sees)
    for display_line in state.display_lines {
        line_text := display_line.text

        // Add line number if enabled and this is the first line of a logical line
        if state.show_line_numbers && display_line.is_first_of_logical {
            line_num_str := fmt.tprintf("%d ", display_line.logical_line_index + 1)
            strings.write_string(&content, line_num_str)
        }

        // Add the actual line text
        strings.write_string(&content, line_text)
        strings.write_byte(&content, '\n')
    }

    // Write to file
    content_string := strings.to_string(content)
    if ok := os.write_entire_file(filename, transmute([]u8)content_string); ok {
        fmt.printf("Successfully saved to: %s\n", filename)
    } else {
        fmt.printf("Error: Failed to save file: %s\n", filename)
    }
}

// Word wrap and display lines (Phase 2.2)
generate_display_lines :: proc(logical_lines: []string, max_width: f32, font_size: i32, word_wrap: bool, font: rl.Font) -> [dynamic]DisplayLine {
    display_lines := make([dynamic]DisplayLine)

    for i := 0; i < len(logical_lines); i += 1 {
        line := logical_lines[i]
        if !word_wrap {
            append(&display_lines, DisplayLine{
                logical_line_index = i,
                is_first_of_logical = true,
                text = line,
            })
        } else {
            wrapped := generate_wrapped_for_line(line, max_width, font_size, font)
            for j := 0; j < len(wrapped); j += 1 {
                wrapped_text := wrapped[j]
                is_first := (j == 0)
                append(&display_lines, DisplayLine{
                    logical_line_index = i,
                    is_first_of_logical = is_first,
                    text = wrapped_text,
                })
            }
            delete(wrapped)
        }
    }

    return display_lines
}

generate_wrapped_for_line :: proc(line: string, max_width: f32, font_size: i32, font: rl.Font) -> [dynamic]string {
    wrapped := make([dynamic]string)
    words := strings.fields(line)
    current_line := ""

    for word in words {
        // Check if the word itself is too long for the line
        word_cstr := strings.clone_to_cstring(word)
        defer delete(word_cstr)
        word_width := rl.MeasureTextEx(font, word_cstr, f32(font_size), 1).x

        if word_width > max_width {
            // Word is too long, need to break it character by character
            if len(current_line) > 0 {
                append(&wrapped, current_line)
                current_line = ""
            }

            // Break the long word into smaller chunks
            temp_word := ""
            for i := 0; i < len(word); i += 1 {
                test_char := fmt.tprintf("%s%c", temp_word, word[i])
                test_cstr := strings.clone_to_cstring(test_char)
                defer delete(test_cstr)

                if rl.MeasureTextEx(font, test_cstr, f32(font_size), 1).x > max_width {
                    if len(temp_word) > 0 {
                        append(&wrapped, temp_word)
                        temp_word = fmt.tprintf("%c", word[i])
                    } else {
                        // Even a single character is too wide, just add it
                        append(&wrapped, fmt.tprintf("%c", word[i]))
                    }
                } else {
                    temp_word = test_char
                }
            }

            if len(temp_word) > 0 {
                current_line = temp_word
            }
        } else {
            // Normal word processing
            test_line := current_line
            if len(test_line) > 0 {
                test_line = fmt.tprintf("%s %s", test_line, word)
            } else {
                test_line = word
            }

            test_cstr := strings.clone_to_cstring(test_line)
            defer delete(test_cstr)

            if rl.MeasureTextEx(font, test_cstr, f32(font_size), 1).x > max_width {
                if len(current_line) > 0 {
                    append(&wrapped, current_line)
                    current_line = word
                } else {
                    append(&wrapped, word)
                    current_line = ""
                }
            } else {
                if len(current_line) > 0 {
                    current_line = fmt.tprintf("%s %s", current_line, word)
                } else {
                    current_line = word
                }
            }
        }
    }

    if len(current_line) > 0 {
        append(&wrapped, current_line)
    }

    return wrapped
}

// Text rendering (Phase 2.3) - Custom rendering with word wrap and line numbers
render_text_area :: proc(state: ^State, text_area: rl.Rectangle, font_size: i32) {
    colors := get_theme_colors(state.theme)

    if len(state.logical_lines) == 0 do return

    // Use cached display lines instead of regenerating every frame
    if len(state.display_lines) == 0 do return

    // Calculate line height and visible lines
    line_height := f32(font_size + 2)
    first_visible_line := int(state.scroll_offset / line_height)
    visible_lines := int(text_area.height / line_height) + 1
    end_line := min(first_visible_line + visible_lines, len(state.display_lines))

    // Calculate text start position (accounting for line numbers)
    text_start_x := text_area.x + 10
    if state.show_line_numbers {
        // Calculate maximum line number width
        max_line_num := len(state.logical_lines)
        line_num_str := fmt.tprintf("%d", max_line_num)
        line_num_cstr := strings.clone_to_cstring(line_num_str)
        defer delete(line_num_cstr)
        max_line_num_width := rl.MeasureTextEx(state.font, line_num_cstr, f32(font_size), 1).x
        text_start_x = text_area.x + f32(max_line_num_width) + 20
    }

    // Begin scissor mode for clipping
    rl.BeginScissorMode(i32(text_area.x), i32(text_area.y), i32(text_area.width), i32(text_area.height))
    defer rl.EndScissorMode()

    // Render visible lines
    for i := first_visible_line; i < end_line; i += 1 {
        display_line := state.display_lines[i]
        y := text_area.y + f32(i - first_visible_line) * line_height - (state.scroll_offset - f32(first_visible_line) * line_height)

        // Highlight selected lines
        is_selected := false
        if state.clicked_line >= 0 && display_line.logical_line_index == state.clicked_line {
            is_selected = true
        } else {
            // Check if this line is in the multi-selection
            for selected_line in state.selected_lines {
                if display_line.logical_line_index == selected_line {
                    is_selected = true
                    break
                }
            }
        }

        // Check for color highlighting
        highlight_color, has_highlight := check_line_highlight(state, display_line.text)

        if is_selected {
            line_rect := rl.Rectangle{text_area.x, y, text_area.width, line_height}
            rl.DrawRectangleRec(line_rect, colors.selection)
        } else if has_highlight {
            // Apply color highlighting
            line_rect := rl.Rectangle{text_area.x, y, text_area.width, line_height}
            rl.DrawRectangleRec(line_rect, highlight_color)
        }

        // Render line number if enabled and this is the first line of a logical line
        if state.show_line_numbers && display_line.is_first_of_logical {
            line_num_str := fmt.tprintf("%d", display_line.logical_line_index + 1)
            line_num_cstr := strings.clone_to_cstring(line_num_str)
            defer delete(line_num_cstr)
            rl.DrawTextEx(state.font, line_num_cstr, {text_area.x + 10, y}, f32(font_size), 1, colors.text)
        }

        // Render text with potential letter highlighting
        text_cstr := strings.clone_to_cstring(display_line.text)
        defer delete(text_cstr)

        // Check if we need letter highlighting
        letter_color := colors.text
        for highlight in state.highlights {
            if !highlight.enabled do continue
            if highlight.type == .Letters && strings.contains(display_line.text, highlight.pattern) {
                letter_color = highlight.color
                break
            }
        }

        // Debug: Print font info on first render
        //if i == 0 && display_line.logical_line_index == 0 {
         //   fmt.printf("DEBUG: Using font with texture ID: %d, base size: %d, glyph count: %d\n",
         //       state.font.texture.id, state.font.baseSize, state.font.glyphCount)
        //}
        rl.DrawTextEx(state.font, text_cstr, {text_start_x, y}, f32(font_size), 1, letter_color)
    }
}

// Scrolling (Phase 2.4)
update_scrolling :: proc(state: ^State, text_area: rl.Rectangle) {
    wheel := rl.GetMouseWheelMove()
    if wheel != 0 {
        line_height := f32(state.font_size + 2)
        state.scroll_offset -= f32(wheel) * line_height
        max_scroll := f32(len(state.display_lines)) * line_height - text_area.height
        state.scroll_offset = max(0, min(state.scroll_offset, max_scroll))
    }
}

// Handle mouse clicks on text area
handle_text_area_clicks :: proc(state: ^State, text_area: rl.Rectangle) {
    if !rl.IsMouseButtonPressed(rl.MouseButton(0)) do return // Left mouse button

    // Don't process text area clicks if any dialog is active
    if state.show_filter_dialog || state.show_find_dialog || state.show_highlight_dialog || state.show_help_dialog {
        return
    }

    mouse_pos := rl.GetMousePosition()
    if !rl.CheckCollisionPointRec(mouse_pos, text_area) do return

    // Calculate which line was clicked
    line_height := f32(state.font_size + 2)
    relative_y := mouse_pos.y - text_area.y
    clicked_display_line := int((relative_y + state.scroll_offset) / line_height)

    if clicked_display_line >= 0 && clicked_display_line < len(state.display_lines) {
        display_line := state.display_lines[clicked_display_line]
        logical_line_index := display_line.logical_line_index

        // Check for modifier keys
        ctrl_pressed := rl.IsKeyDown(rl.KeyboardKey(341)) // CTRL
        shift_pressed := rl.IsKeyDown(rl.KeyboardKey(340)) // SHIFT

        if ctrl_pressed {
            // CTRL+Click: Toggle individual line selection
            toggle_line_selection(state, logical_line_index)
            state.last_clicked_line = logical_line_index
        } else if shift_pressed && state.last_clicked_line >= 0 {
            // SHIFT+Click: Range selection
            select_line_range(state, state.last_clicked_line, logical_line_index)
        } else {
            // Normal click: Single line selection
            clear(&state.selected_lines)
            append(&state.selected_lines, logical_line_index)
            state.clicked_line = logical_line_index
            state.last_clicked_line = logical_line_index
        }

        fmt.printf("Clicked line %d (logical line %d): %s\n", clicked_display_line + 1, logical_line_index + 1, display_line.text)
    }
}

// Handle keyboard shortcuts
handle_keyboard_shortcuts :: proc(state: ^State) {
    // Debug logging for key states
    ctrl_pressed := rl.IsKeyDown(rl.KeyboardKey(341))
    equals_pressed := rl.IsKeyPressed(rl.KeyboardKey(61))
    minus_pressed := rl.IsKeyPressed(rl.KeyboardKey(45))

    // Log key states when any of the relevant keys are pressed
    if ctrl_pressed || equals_pressed || minus_pressed {
        fmt.printf("DEBUG: CTRL: %v, EQUALS: %v, MINUS: %v\n",
                   ctrl_pressed, equals_pressed, minus_pressed)
    }

    // CTRL+O for Open file dialog
    if rl.IsKeyDown(rl.KeyboardKey(341)) && rl.IsKeyPressed(rl.KeyboardKey(79)) { // CTRL + O
        // File dialog for opening files
        filter_patterns: [2]cstring = {"*.txt", "*.log"}
        selected_file := tfd.openFileDialog(
            "Open File",
            nil, // Default path
            2, // Number of filter patterns
            raw_data(filter_patterns[:]),
            "Text Files", // Filter description
            0, // No multiple selection
        )

        if selected_file != nil {
            file_path := string(selected_file)
            if os.exists(file_path) {
                load_file(state, file_path)
            } else {
                fmt.printf("Error: File not found: %s\n", file_path)
            }
        }
    }

    // ALT+S for Save file dialog
    if rl.IsKeyDown(rl.KeyboardKey(342)) && rl.IsKeyPressed(rl.KeyboardKey(83)) { // ALT + S
        // Save dialog for saving current display content
        filter_patterns: [2]cstring = {"*.txt", "*.log"}
        selected_file := tfd.saveFileDialog(
            "Save File",
            nil, // Default path
            2, // Number of filter patterns
            raw_data(filter_patterns[:]),
            "Text Files", // Filter description
        )

        if selected_file != nil {
            file_path := string(selected_file)
            save_current_display_to_file(state, file_path)
        }
    }

    // ALT+Z for word wrap toggle
    if rl.IsKeyDown(rl.KeyboardKey(342)) && rl.IsKeyPressed(rl.KeyboardKey(90)) { // ALT + Z
        state.word_wrap = !state.word_wrap
        state.needs_redraw_display_lines = true
        fmt.printf("Word wrap %s\n", state.word_wrap ? "enabled" : "disabled")
    }

    // ALT+N for line numbers toggle
    if rl.IsKeyDown(rl.KeyboardKey(342)) && rl.IsKeyPressed(rl.KeyboardKey(78)) { // ALT + N
        state.show_line_numbers = !state.show_line_numbers
        fmt.printf("Line numbers %s\n", state.show_line_numbers ? "enabled" : "disabled")
    }

    // CTRL+C to copy selected line(s)
    if rl.IsKeyDown(rl.KeyboardKey(341)) && rl.IsKeyPressed(rl.KeyboardKey(67)) { // CTRL + C
        if len(state.selected_lines) > 0 {
            // Copy multiple selected lines
            copy_multiple_lines_to_clipboard(state)
        } else if state.clicked_line >= 0 && state.clicked_line < len(state.logical_lines) {
            // Copy single clicked line
            copy_single_line_to_clipboard(state, state.clicked_line)
        }
    }

    // CTRL+F for Find dialog
    if rl.IsKeyDown(rl.KeyboardKey(341)) && rl.IsKeyPressed(rl.KeyboardKey(70)) { // CTRL + F
        state.show_find_dialog = !state.show_find_dialog
        // Set focus to input field when dialog opens
        if state.show_find_dialog {
            state.active_input_field = .Find
        }
    }

            // CTRL + = for Increase Font (VS Code style)
        if rl.IsKeyDown(rl.KeyboardKey(341)) && rl.IsKeyPressed(rl.KeyboardKey(61)) { // CTRL + =
            fmt.printf("DEBUG: Font increase shortcut triggered!\n")
            state.font_size += 1
            // Reload font with new size
            rl.UnloadFont(state.font)
            state.font = reload_embedded_font(state.font_size)
            state.needs_redraw_display_lines = true
            fmt.printf("Font size increased to %d\n", state.font_size)
        }

        // CTRL + - for Decrease Font (VS Code style)
        if rl.IsKeyDown(rl.KeyboardKey(341)) && rl.IsKeyPressed(rl.KeyboardKey(45)) { // CTRL + -
            fmt.printf("DEBUG: Font decrease shortcut triggered!\n")
            if state.font_size > 1 { // Prevent font size from going below 1
                state.font_size -= 1
                // Reload font with new size
                rl.UnloadFont(state.font)
                state.font = reload_embedded_font(state.font_size)
                state.needs_redraw_display_lines = true
                fmt.printf("Font size decreased to %d\n", state.font_size)
            }
        }

    // ALT+F4 and CTRL+W are now handled in main.odin
}

// Toggle individual line selection (CTRL+Click)
toggle_line_selection :: proc(state: ^State, line_index: int) {
    // Check if line is already selected
    for i := 0; i < len(state.selected_lines); i += 1 {
        if state.selected_lines[i] == line_index {
            // Remove from selection
            ordered_remove(&state.selected_lines, i)
            return
        }
    }
    // Add to selection
    append(&state.selected_lines, line_index)
}

// Select range of lines (SHIFT+Click)
select_line_range :: proc(state: ^State, start_line: int, end_line: int) {
    clear(&state.selected_lines)

    // Ensure start is smaller than end
    actual_start := start_line
    actual_end := end_line
    if start_line > end_line {
        actual_start = end_line
        actual_end = start_line
    }

    // Add all lines in range
    for i := actual_start; i <= actual_end; i += 1 {
        append(&state.selected_lines, i)
    }
}

// Add highlight rule
add_highlight :: proc(state: ^State, type: HighlightType, pattern: string, color: rl.Color) {
    highlight := Highlight{
        type = type,
        pattern = strings.clone(pattern),
        color = color,
        enabled = true,
    }
    append(&state.highlights, highlight)
}

// Toggle highlight rule
toggle_highlight :: proc(state: ^State, index: int) {
    if index >= 0 && index < len(state.highlights) {
        state.highlights[index].enabled = !state.highlights[index].enabled
    }
}

// Remove highlight rule
remove_highlight :: proc(state: ^State, index: int) {
    if index >= 0 && index < len(state.highlights) {
        delete(state.highlights[index].pattern)
        ordered_remove(&state.highlights, index)
    }
}

// Check if a line should be highlighted
check_line_highlight :: proc(state: ^State, line: string) -> (rl.Color, bool) {
    for highlight in state.highlights {
        if !highlight.enabled do continue
        if strings.contains(line, highlight.pattern) {
            return highlight.color, true
        }
    }
    return rl.BLACK, false
}

// Copy text to clipboard
copy_to_clipboard :: proc(text: string) {
    // Convert string to cstring for raylib
    text_cstr := strings.clone_to_cstring(text)
    defer delete(text_cstr)

    // Use raylib's SetClipboardText function
    rl.SetClipboardText(text_cstr)
}

// Copy single line to clipboard
copy_single_line_to_clipboard :: proc(state: ^State, line_index: int) {
    // Find the display line that corresponds to the logical line
    display_text := ""
    for display_line in state.display_lines {
        if display_line.logical_line_index == line_index {
            // Build the text as it appears on screen
            if state.show_line_numbers && display_line.is_first_of_logical {
                // Include line number
                line_num_str := fmt.tprintf("%d ", display_line.logical_line_index + 1)
                display_text = fmt.tprintf("%s%s", line_num_str, display_line.text)
            } else {
                // Just the text without line number
                display_text = display_line.text
            }
            break
        }
    }

    if len(display_text) > 0 {
        copy_to_clipboard(display_text)
        fmt.printf("Copied display line to clipboard: %s\n", display_text)
    }
}

// Copy multiple selected lines to clipboard
copy_multiple_lines_to_clipboard :: proc(state: ^State) {
    if len(state.selected_lines) == 0 do return

    // Sort selected lines to maintain order
    sorted_lines := make([dynamic]int)
    defer delete(sorted_lines)

    for selected_line in state.selected_lines {
        append(&sorted_lines, selected_line)
    }

    // Simple bubble sort (for small arrays)
    for i := 0; i < len(sorted_lines) - 1; i += 1 {
        for j := 0; j < len(sorted_lines) - 1 - i; j += 1 {
            if sorted_lines[j] > sorted_lines[j + 1] {
                sorted_lines[j], sorted_lines[j + 1] = sorted_lines[j + 1], sorted_lines[j]
            }
        }
    }

    // Build combined text
    combined_text := ""
    for i := 0; i < len(sorted_lines); i += 1 {
        line_index := sorted_lines[i]

        // Find the display line for this logical line
        for display_line in state.display_lines {
            if display_line.logical_line_index == line_index {
                // Build the text as it appears on screen
                if state.show_line_numbers && display_line.is_first_of_logical {
                    // Include line number
                    line_num_str := fmt.tprintf("%d ", display_line.logical_line_index + 1)
                    if i > 0 {
                        combined_text = fmt.tprintf("%s\n%s%s", combined_text, line_num_str, display_line.text)
                    } else {
                        combined_text = fmt.tprintf("%s%s", line_num_str, display_line.text)
                    }
                } else {
                    // Just the text without line number
                    if i > 0 {
                        combined_text = fmt.tprintf("%s\n%s", combined_text, display_line.text)
                    } else {
                        combined_text = display_line.text
                    }
                }
                break
            }
        }
    }

    if len(combined_text) > 0 {
        copy_to_clipboard(combined_text)
        fmt.printf("Copied %d selected lines to clipboard\n", len(state.selected_lines))
    }
}

// Menu rendering
render_menu :: proc(state: ^State) {
    colors := get_theme_colors(state.theme)

    button_height: f32 = 30
    button_width: f32 = 80
    spacing: f32 = 10
    x := spacing
    y := spacing

    // Draw menu background
    menu_rect := rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), 50}
    rl.DrawRectangleRec(menu_rect, colors.menu_background)

    // Open button
    if rl.GuiButton({x, y, button_width, button_height}, "Open") {
        // File dialog for opening files
        filter_patterns: [2]cstring = {"*.txt", "*.log"}
        selected_file := tfd.openFileDialog(
            "Open File",
            nil, // Default path
            2, // Number of filter patterns
            raw_data(filter_patterns[:]),
            "Text Files", // Filter description
            0, // No multiple selection
        )

        if selected_file != nil {
            file_path := string(selected_file)
            if os.exists(file_path) {
                load_file(state, file_path)
            } else {
                fmt.printf("Error: File not found: %s\n", file_path)
            }
        }
    }
    x += button_width + spacing

    // Save button
    if rl.GuiButton({x, y, button_width, button_height}, "Save") {
        // Save dialog for saving current display content
        filter_patterns: [2]cstring = {"*.txt", "*.log"}
        selected_file := tfd.saveFileDialog(
            "Save File",
            nil, // Default path
            2, // Number of filter patterns
            raw_data(filter_patterns[:]),
            "Text Files", // Filter description
        )

        if selected_file != nil {
            file_path := string(selected_file)
            save_current_display_to_file(state, file_path)
        }
    }
    x += button_width + spacing

    // Find button
    if rl.GuiButton({x, y, button_width, button_height}, "Find") {
        state.show_find_dialog = !state.show_find_dialog
        // Set focus to input field when dialog opens
        if state.show_find_dialog {
            state.active_input_field = .Find
        }
    }
    x += button_width + spacing

    // Filter button
    if rl.GuiButton({x, y, button_width, button_height}, "Filter") {
        state.show_filter_dialog = !state.show_filter_dialog
        // Set focus to input field when dialog opens
        if state.show_filter_dialog {
            state.active_input_field = .Filter
        }
    }
    x += button_width + spacing

    // Highlight button
    if rl.GuiButton({x, y, button_width, button_height}, "Highlight") {
        state.show_highlight_dialog = !state.show_highlight_dialog
        // Set focus to input field when dialog opens
        if state.show_highlight_dialog {
            state.active_input_field = .Highlight
        }
    }
    x += button_width + spacing

    // Theme toggle button
    theme_text := state.theme == .Light ? "Dark Theme" : "Light Theme"
    theme_cstr := strings.clone_to_cstring(theme_text)
    defer delete(theme_cstr)
    if rl.GuiButton({x, y, button_width, button_height}, theme_cstr) {
        // Toggle theme
        state.theme = state.theme == .Light ? .Dark : .Light
    }
    x += button_width + spacing

    // Word wrap toggle
    old_word_wrap := state.word_wrap
    rl.GuiToggle({x, y, button_width, button_height}, "Word Wrap", &state.word_wrap)
    if old_word_wrap != state.word_wrap {
        state.needs_redraw_display_lines = true
    }
    x += button_width + spacing

    // Increase Font button
    if rl.GuiButton({x, y, button_width, button_height}, "IncreaseFont") {
        state.font_size += 1
        // Reload font with new size
        rl.UnloadFont(state.font)
        state.font = reload_embedded_font(state.font_size)
        state.needs_redraw_display_lines = true
    }
    x += button_width + spacing

    // Decrease Font button
    if rl.GuiButton({x, y, button_width, button_height}, "DecreaseFont") {
        if state.font_size > 1 { // Prevent font size from going below 1
            state.font_size -= 1
            // Reload font with new size
            rl.UnloadFont(state.font)
            state.font = reload_embedded_font(state.font_size)
            state.needs_redraw_display_lines = true
        }
    }
    x += button_width + spacing

    // Line numbers toggle
    rl.GuiToggle({x, y, button_width, button_height}, "Line Numbers", &state.show_line_numbers)
    x += button_width + spacing

    // Help button
    if rl.GuiButton({x, y, button_width, button_height}, "Help") {
        state.show_help_dialog = !state.show_help_dialog
    }
}

// Filter dialog rendering
render_filter_dialog :: proc(state: ^State) {
    colors := get_theme_colors(state.theme)

    dialog_width: f32 = 400
    dialog_height: f32 = 300
    dialog_x := (1200 - dialog_width) / 2
    dialog_y := (800 - dialog_height) / 2

    // Draw dialog background
    rl.DrawRectangle(i32(dialog_x), i32(dialog_y), i32(dialog_width), i32(dialog_height), colors.dialog_background)
    rl.DrawRectangleLinesEx({dialog_x, dialog_y, dialog_width, dialog_height}, 2, colors.input_border)

    // Dialog title
    title := state.editing_filter_index >= 0 ? "Edit Filter" : "Filter Lines"
    title_cstr := strings.clone_to_cstring(title)
    defer delete(title_cstr)
    rl.DrawTextEx(state.font, title_cstr, {dialog_x + 10, dialog_y + 10}, 20, 1, colors.dialog_text)

    // Filter input
    input_rect := rl.Rectangle{dialog_x + 10, dialog_y + 50, dialog_width - 20, 30}
    filter_cstr := strings.clone_to_cstring(state.filter_input)
    defer delete(filter_cstr)

    // Check if mouse is over input field
    mouse_pos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mouse_pos, input_rect) && rl.IsMouseButtonPressed(rl.MouseButton(0)) { // MOUSE_LEFT_BUTTON
        state.active_input_field = .Filter
    }

    // Draw input field with different color if active
    if state.active_input_field == .Filter {
        rl.DrawRectangleRec(input_rect, colors.input_background)
        rl.DrawRectangleLinesEx(input_rect, 2, colors.input_border)
    } else {
        rl.DrawRectangleRec(input_rect, colors.input_background)
        rl.DrawRectangleLinesEx(input_rect, 1, colors.input_border)
    }
    rl.DrawTextEx(state.font, filter_cstr, {input_rect.x + 5, input_rect.y + 5}, 16, 1, colors.input_text)

    // Buttons
    button_width: f32 = 80
    button_height: f32 = 30
    button_y := dialog_y + dialog_height - 50

    // Include button
    include_rect := rl.Rectangle{dialog_x + 10, button_y, button_width, button_height}
    if rl.GuiButton(include_rect, "Include") {
        if len(state.filter_input) > 0 {
            if state.editing_filter_index >= 0 {
                // Update existing filter
                if state.editing_filter_index < len(state.filters) {
                    delete(state.filters[state.editing_filter_index].pattern)
                    state.filters[state.editing_filter_index].pattern = strings.clone(state.filter_input)
                    state.filters[state.editing_filter_index].type = .Include
                    apply_filters(state)
                }
                state.editing_filter_index = -1
            } else {
                // Add new filter
                add_filter(state, .Include, state.filter_input, false)
            }
            state.filter_input = ""
        }
    }

    // Exclude button
    exclude_rect := rl.Rectangle{dialog_x + 100, button_y, button_width, button_height}
    if rl.GuiButton(exclude_rect, "Exclude") {
        if len(state.filter_input) > 0 {
            if state.editing_filter_index >= 0 {
                // Update existing filter
                if state.editing_filter_index < len(state.filters) {
                    delete(state.filters[state.editing_filter_index].pattern)
                    state.filters[state.editing_filter_index].pattern = strings.clone(state.filter_input)
                    state.filters[state.editing_filter_index].type = .Exclude
                    apply_filters(state)
                }
                state.editing_filter_index = -1
            } else {
                // Add new filter
                add_filter(state, .Exclude, state.filter_input, false)
            }
            state.filter_input = ""
        }
    }

    // Clear button
    clear_rect := rl.Rectangle{dialog_x + 190, button_y, button_width, button_height}
    if rl.GuiButton(clear_rect, "Clear All") {
        clear(&state.filters)
        apply_filters(state) // This will restore original lines
    }

    // Cancel button (when editing)
    if state.editing_filter_index >= 0 {
        cancel_rect := rl.Rectangle{dialog_x + 280, button_y, button_width, button_height}
        if rl.GuiButton(cancel_rect, "Cancel") {
            state.filter_input = ""
            state.editing_filter_index = -1
            state.active_input_field = .None
        }
    }

    // Close button
    close_rect := rl.Rectangle{dialog_x + dialog_width - 90, button_y, button_width, button_height}
    if rl.GuiButton(close_rect, "Close") {
        state.show_filter_dialog = false
        state.editing_filter_index = -1
        state.filter_input = ""
    }

    // Show active filters with individual controls
    filter_y := dialog_y + 100
    for i := 0; i < len(state.filters); i += 1 {
        filter := state.filters[i]

        // Filter text
        filter_text := fmt.tprintf("%s: %s", filter.type == .Include ? "Include" : "Exclude", filter.pattern)
        filter_cstr := strings.clone_to_cstring(filter_text)
        defer delete(filter_cstr)
        rl.DrawTextEx(state.font, filter_cstr, {dialog_x + 10, filter_y + f32(i * 30)}, 14, 1, rl.BLACK)

        // Toggle button (Enable/Disable)
        toggle_text := filter.enabled ? "Disable" : "Enable"
        toggle_cstr := strings.clone_to_cstring(toggle_text)
        defer delete(toggle_cstr)
        toggle_rect := rl.Rectangle{dialog_x + 200, filter_y + f32(i * 30), 60, 20}
        if rl.GuiButton(toggle_rect, toggle_cstr) {
            toggle_filter(state, i)
        }

        // Remove button
        remove_rect := rl.Rectangle{dialog_x + 270, filter_y + f32(i * 30), 60, 20}
        if rl.GuiButton(remove_rect, "Remove") {
            remove_filter(state, i)
        }

        // Edit button
        edit_rect := rl.Rectangle{dialog_x + 340, filter_y + f32(i * 30), 50, 20}
        if rl.GuiButton(edit_rect, "Edit") {
            state.filter_input = filter.pattern
            state.editing_filter_index = i
            state.active_input_field = .Filter
        }
    }
}

// Find dialog rendering
render_find_dialog :: proc(state: ^State) {
    colors := get_theme_colors(state.theme)

    dialog_width: f32 = 400
    dialog_height: f32 = 200
    dialog_x := (1200 - dialog_width) / 2
    dialog_y := (800 - dialog_height) / 2

    // Draw dialog background
    rl.DrawRectangle(i32(dialog_x), i32(dialog_y), i32(dialog_width), i32(dialog_height), colors.dialog_background)
    rl.DrawRectangleLinesEx(rl.Rectangle{dialog_x, dialog_y, dialog_width, dialog_height}, 2, colors.input_border)

    // Dialog title
    title := "Find Text"
    title_cstr := strings.clone_to_cstring(title)
    defer delete(title_cstr)
    rl.DrawTextEx(state.font, title_cstr, {dialog_x + 10, dialog_y + 10}, 20, 1, colors.dialog_text)

    // Find input
    input_rect := rl.Rectangle{dialog_x + 10, dialog_y + 50, dialog_width - 20, 30}
    find_cstr := strings.clone_to_cstring(state.find_input)
    defer delete(find_cstr)

    // Check if mouse is over input field
    mouse_pos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mouse_pos, input_rect) && rl.IsMouseButtonPressed(rl.MouseButton(0)) { // MOUSE_LEFT_BUTTON
        state.active_input_field = .Find
    }

    // Draw input field with different color if active
    if state.active_input_field == .Find {
        rl.DrawRectangleRec(input_rect, colors.input_background)
        rl.DrawRectangleLinesEx(input_rect, 2, colors.input_border)
    } else {
        rl.DrawRectangleRec(input_rect, colors.input_background)
        rl.DrawRectangleLinesEx(input_rect, 1, colors.input_border)
    }
    rl.DrawTextEx(state.font, find_cstr, {input_rect.x + 5, input_rect.y + 5}, 16, 1, colors.input_text)

    // Buttons
    button_width: f32 = 80
    button_height: f32 = 30
    button_y := dialog_y + dialog_height - 50

    // Search Down button
    search_down_rect := rl.Rectangle{dialog_x + 10, button_y, button_width, button_height}
    if rl.GuiButton(search_down_rect, "Search Down") {
        if len(state.find_input) > 0 {
            // Search down from current position
            search_text_down(state, state.find_input)
            // Add to history
            append(&state.find_history, strings.clone(state.find_input))
        }
    }

    // Search Up button
    search_up_rect := rl.Rectangle{dialog_x + 100, button_y, button_width, button_height}
    if rl.GuiButton(search_up_rect, "Search Up") {
        if len(state.find_input) > 0 {
            // Search up from current position
            search_text_up(state, state.find_input)
            // Add to history
            append(&state.find_history, strings.clone(state.find_input))
        }
    }

    // Close button
    close_rect := rl.Rectangle{dialog_x + dialog_width - 90, button_y, button_width, button_height}
    if rl.GuiButton(close_rect, "Close") {
        state.show_find_dialog = false
    }
}

// Highlight dialog rendering
render_highlight_dialog :: proc(state: ^State) {
    colors := get_theme_colors(state.theme)

    dialog_width: f32 = 450
    dialog_height: f32 = 350
    dialog_x := (1200 - dialog_width) / 2
    dialog_y := (800 - dialog_height) / 2

    // Draw dialog background
    rl.DrawRectangle(i32(dialog_x), i32(dialog_y), i32(dialog_width), i32(dialog_height), colors.dialog_background)
    rl.DrawRectangleLinesEx({dialog_x, dialog_y, dialog_width, dialog_height}, 2, colors.input_border)

    // Dialog title
    title := state.editing_highlight_index >= 0 ? "Edit Highlight" : "Color Highlight"
    title_cstr := strings.clone_to_cstring(title)
    defer delete(title_cstr)
    rl.DrawTextEx(state.font, title_cstr, {dialog_x + 10, dialog_y + 10}, 20, 1, colors.dialog_text)

    // Pattern input
    input_rect := rl.Rectangle{dialog_x + 10, dialog_y + 50, dialog_width - 20, 30}
    highlight_cstr := strings.clone_to_cstring(state.highlight_input)
    defer delete(highlight_cstr)

    // Check if mouse is over input field
    mouse_pos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mouse_pos, input_rect) && rl.IsMouseButtonPressed(rl.MouseButton(0)) { // MOUSE_LEFT_BUTTON
        state.active_input_field = .Highlight
    }

    // Draw input field with different color if active
    if state.active_input_field == .Highlight {
        rl.DrawRectangleRec(input_rect, colors.input_background)
        rl.DrawRectangleLinesEx(input_rect, 2, colors.input_border)
    } else {
        rl.DrawRectangleRec(input_rect, colors.input_background)
        rl.DrawRectangleLinesEx(input_rect, 1, colors.input_border)
    }
    rl.DrawTextEx(state.font, highlight_cstr, {input_rect.x + 5, input_rect.y + 5}, 16, 1, colors.input_text)

    // Color picker
    color_rect := rl.Rectangle{dialog_x + 10, dialog_y + 100, 200, 30}
    rl.GuiColorPicker(color_rect, "Color", &state.highlight_color)

    // Buttons
    button_width: f32 = 80
    button_height: f32 = 30
    button_y := dialog_y + dialog_height - 50

    // Background button
    background_rect := rl.Rectangle{dialog_x + 10, button_y, button_width, button_height}
    if rl.GuiButton(background_rect, "Background") {
        if len(state.highlight_input) > 0 {
            if state.editing_highlight_index >= 0 {
                // Update existing highlight
                if state.editing_highlight_index < len(state.highlights) {
                    delete(state.highlights[state.editing_highlight_index].pattern)
                    state.highlights[state.editing_highlight_index].pattern = strings.clone(state.highlight_input)
                    state.highlights[state.editing_highlight_index].type = .Background
                    state.highlights[state.editing_highlight_index].color = state.highlight_color
                }
                state.editing_highlight_index = -1
            } else {
                // Add new highlight
                add_highlight(state, .Background, state.highlight_input, state.highlight_color)
            }
            state.highlight_input = ""
        }
    }

    // Letters button
    letters_rect := rl.Rectangle{dialog_x + 100, button_y, button_width, button_height}
    if rl.GuiButton(letters_rect, "Letters") {
        if len(state.highlight_input) > 0 {
            if state.editing_highlight_index >= 0 {
                // Update existing highlight
                if state.editing_highlight_index < len(state.highlights) {
                    delete(state.highlights[state.editing_highlight_index].pattern)
                    state.highlights[state.editing_highlight_index].pattern = strings.clone(state.highlight_input)
                    state.highlights[state.editing_highlight_index].type = .Letters
                    state.highlights[state.editing_highlight_index].color = state.highlight_color
                }
                state.editing_highlight_index = -1
            } else {
                // Add new highlight
                add_highlight(state, .Letters, state.highlight_input, state.highlight_color)
            }
            state.highlight_input = ""
        }
    }

    // Clear button
    clear_rect := rl.Rectangle{dialog_x + 190, button_y, button_width, button_height}
    if rl.GuiButton(clear_rect, "Clear All") {
        clear(&state.highlights)
    }

    // Cancel button (when editing)
    if state.editing_highlight_index >= 0 {
        cancel_rect := rl.Rectangle{dialog_x + 280, button_y, button_width, button_height}
        if rl.GuiButton(cancel_rect, "Cancel") {
            state.highlight_input = ""
            state.editing_highlight_index = -1
            state.active_input_field = .None
        }
    }

    // Close button
    close_rect := rl.Rectangle{dialog_x + dialog_width - 90, button_y, button_width, button_height}
    if rl.GuiButton(close_rect, "Close") {
        state.show_highlight_dialog = false
        state.editing_highlight_index = -1
        state.highlight_input = ""
    }

    // Show active highlights with individual controls
    highlight_y := dialog_y + 150
    for i := 0; i < len(state.highlights); i += 1 {
        highlight := state.highlights[i]

        // Highlight text
        highlight_text := fmt.tprintf("%s: %s", highlight.type == .Background ? "Background" : "Letters", highlight.pattern)
        highlight_cstr := strings.clone_to_cstring(highlight_text)
        defer delete(highlight_cstr)
        rl.DrawTextEx(state.font, highlight_cstr, {dialog_x + 10, highlight_y + f32(i * 30)}, 14, 1, rl.BLACK)

        // Color preview
        color_preview_rect := rl.Rectangle{dialog_x + 200, highlight_y + f32(i * 30), 20, 20}
        rl.DrawRectangleRec(color_preview_rect, highlight.color)

        // Toggle button (Enable/Disable)
        toggle_text := highlight.enabled ? "Disable" : "Enable"
        toggle_cstr := strings.clone_to_cstring(toggle_text)
        defer delete(toggle_cstr)
        toggle_rect := rl.Rectangle{dialog_x + 230, highlight_y + f32(i * 30), 60, 20}
        if rl.GuiButton(toggle_rect, toggle_cstr) {
            toggle_highlight(state, i)
        }

        // Remove button
        remove_rect := rl.Rectangle{dialog_x + 300, highlight_y + f32(i * 30), 60, 20}
        if rl.GuiButton(remove_rect, "Remove") {
            remove_highlight(state, i)
        }

        // Edit button
        edit_rect := rl.Rectangle{dialog_x + 370, highlight_y + f32(i * 30), 50, 20}
        if rl.GuiButton(edit_rect, "Edit") {
            state.highlight_input = highlight.pattern
            state.highlight_color = highlight.color
            state.editing_highlight_index = i
            state.active_input_field = .Highlight
        }
    }
}

// Help dialog rendering
render_help_dialog :: proc(state: ^State) {
    // Create comprehensive help message
    help_message := fmt.tprintf("OdinLogViewer %s\n\n" +
        "KEYBOARD AND MOUSE SHORTCUTS:\n\n" +
        "File Operations:\n" +
        "  CTRL+O          Open file dialog\n" +
        "  ALT+S           Save current display to file\n\n" +
        "App Control:\n" +
        "  ALT+F4          Close application\n" +
        "  CTRL+W          Close application (alternative)\n" +
        "  ESC             Close dialogs or clear active input fields\n\n" +
        "Display Options:\n" +
        "  ALT+Z           Toggle word wrap on/off\n" +
        "  ALT+N           Toggle line numbers display on/off\n" +
        "  CTRL+=          Increase font size\n" +
        "  CTRL+-          Decrease font size\n\n" +
        "Line Selection:\n" +
        "  Single Click    Select a single line\n" +
        "  CTRL+Click      Toggle individual line selection\n" +
        "  SHIFT+Click     Range selection\n\n" +
        "Text Operations:\n" +
        "  CTRL+C          Copy selected line(s) to clipboard\n" +
        "  CTRL+F          Open find dialog\n" +
        "  BACKSPACE       Delete characters in active input fields\n\n" +
        "Navigation:\n" +
        "  Mouse Wheel     Scroll through text content\n" +
        "  Mouse Click     Interact with buttons and controls\n\n" +
        "NOTES:\n" +
        "- CTRL+C copies multiple lines if any are selected, otherwise copies the single clicked line\n" +
        "- Any printable character adds to active input field when a dialog is open\n" +
        "- ESC behavior depends on context: closes dialogs or clears active input fields\n\n" +
        "Repository: hbttps://github.com/NL-Cristi/OdinLogViewer",
        state.version)

    help_cstr := strings.clone_to_cstring(help_message)
    defer delete(help_cstr)

    // Show message box with help content
    ret := tfd.messageBox("Keyboard and Mouse Shortcuts", help_cstr, "ok", "info", 0)

    // Close the help dialog regardless of the response
    state.show_help_dialog = false
}

// Handle text input for active field
handle_text_input :: proc(state: ^State) {
    // Handle escape to close dialogs or clear active field
    if rl.IsKeyPressed(rl.KeyboardKey(256)) { // KEY_ESCAPE
        if state.show_filter_dialog {
            // Close filter dialog
            state.show_filter_dialog = false
            state.editing_filter_index = -1
            state.filter_input = ""
            state.active_input_field = .None
        } else if state.show_highlight_dialog {
            // Close highlight dialog
            state.show_highlight_dialog = false
            state.editing_highlight_index = -1
            state.highlight_input = ""
            state.active_input_field = .None
        } else if state.show_find_dialog {
            // Close find dialog
            state.show_find_dialog = false
            state.active_input_field = .None
        } else if state.show_help_dialog {
            // Close help dialog
            state.show_help_dialog = false
        } else if state.active_input_field != .None {
            // Clear active input field if no dialogs are open
            state.active_input_field = .None
        }
        return
    }

    // Handle text input for active field
    if state.active_input_field == .None do return

    key := rl.GetCharPressed()
    if key != 0 {
        // Add character to appropriate field
        if state.active_input_field == .Filter {
            state.filter_input = fmt.tprintf("%s%c", state.filter_input, rune(key))
        } else if state.active_input_field == .Find {
            state.find_input = fmt.tprintf("%s%c", state.find_input, rune(key))
        } else if state.active_input_field == .Highlight {
            state.highlight_input = fmt.tprintf("%s%c", state.highlight_input, rune(key))
        }
    }

    // Handle backspace
    if rl.IsKeyPressed(rl.KeyboardKey(259)) { // KEY_BACKSPACE
        if state.active_input_field == .Filter && len(state.filter_input) > 0 {
            state.filter_input = state.filter_input[:len(state.filter_input)-1]
        } else if state.active_input_field == .Find && len(state.find_input) > 0 {
            state.find_input = state.find_input[:len(state.find_input)-1]
        } else if state.active_input_field == .Highlight && len(state.highlight_input) > 0 {
            state.highlight_input = state.highlight_input[:len(state.highlight_input)-1]
        }
    }
}



// Search text down from current position
search_text_down :: proc(state: ^State, search_text: string) {
    if len(search_text) == 0 || len(state.display_lines) == 0 do return

    // Start from current position + 1, or from beginning if no current position
    start_index := state.current_search_position + 1
    if start_index >= len(state.display_lines) {
        start_index = 0 // Wrap around to beginning
    }

    // Search from current position down to end
    for i := start_index; i < len(state.display_lines); i += 1 {
        display_line := state.display_lines[i]
        if strings.contains(display_line.text, search_text) {
            // Found a match!
            state.current_search_position = i
            scroll_to_display_line(state, i)
            state.clicked_line = display_line.logical_line_index
            state.show_search_message = false
            return
        }
    }

    // If not found in the rest, search from beginning to current position
    if start_index > 0 {
        for i := 0; i < start_index; i += 1 {
            display_line := state.display_lines[i]
            if strings.contains(display_line.text, search_text) {
                // Found a match!
                state.current_search_position = i
                scroll_to_display_line(state, i)
                state.clicked_line = display_line.logical_line_index
                state.show_search_message = false
                return
            }
        }
    }

    // No match found
    state.show_search_message = true
    state.search_message_timer = 3.0 // Show message for 3 seconds
}

// Search text up from current position
search_text_up :: proc(state: ^State, search_text: string) {
    if len(search_text) == 0 || len(state.display_lines) == 0 do return

    // Start from current position - 1, or from end if no current position
    start_index := state.current_search_position - 1
    if start_index < 0 {
        start_index = len(state.display_lines) - 1 // Wrap around to end
    }

    // Search from current position up to beginning
    for i := start_index; i >= 0; i -= 1 {
        display_line := state.display_lines[i]
        if strings.contains(display_line.text, search_text) {
            // Found a match!
            state.current_search_position = i
            scroll_to_display_line(state, i)
            state.clicked_line = display_line.logical_line_index
            state.show_search_message = false
            return
        }
    }

    // If not found in the beginning, search from end to current position
    if start_index < len(state.display_lines) - 1 {
        for i := len(state.display_lines) - 1; i > start_index; i -= 1 {
            display_line := state.display_lines[i]
            if strings.contains(display_line.text, search_text) {
                // Found a match!
                state.current_search_position = i
                scroll_to_display_line(state, i)
                state.clicked_line = display_line.logical_line_index
                state.show_search_message = false
                return
            }
        }
    }

    // No match found
    state.show_search_message = true
    state.search_message_timer = 3.0 // Show message for 3 seconds
}

// Helper function to scroll to a specific display line
scroll_to_display_line :: proc(state: ^State, display_line_index: int) {
    line_height := f32(state.font_size + 4)
    target_scroll := f32(display_line_index) * line_height

    // Center the found line in the visible area
    visible_lines := int(state.text_area.height / line_height)
    target_scroll -= (f32(visible_lines) / 2) * line_height

    // Clamp scroll to valid range
    max_scroll := max(0, f32(len(state.display_lines)) * line_height - state.text_area.height)
    state.scroll_offset = max(0, min(target_scroll, max_scroll))
}

// Main update and render procedures
update :: proc(state: ^State) {
    // Handle window resize
    window_width := rl.GetScreenWidth()
    window_height := rl.GetScreenHeight()

    // Update text area dimensions if window size changed
    new_text_area := rl.Rectangle{10, 60, f32(window_width - 20), f32(window_height - 70)}
    if new_text_area != state.text_area {
        state.text_area = new_text_area
        state.needs_redraw_display_lines = true
    }

    // Handle text input
    handle_text_input(state)

    // Handle mouse clicks on text area
    handle_text_area_clicks(state, state.text_area)

    // Handle keyboard shortcuts
    handle_keyboard_shortcuts(state)

    // Update search message timer
    if state.show_search_message {
        state.search_message_timer -= rl.GetFrameTime()
        if state.search_message_timer <= 0 {
            state.show_search_message = false
        }
    }

    // Update scrolling
    update_scrolling(state, state.text_area)

    // Regenerate display lines if needed
    if state.needs_redraw_display_lines {
        delete(state.display_lines)
        state.display_lines = generate_display_lines(
            state.logical_lines[:],
            state.text_area.width - 20,
            state.font_size,
            state.word_wrap,
            state.font,
        )
        state.needs_redraw_display_lines = false
    }
}

render :: proc(state: ^State) {
    // Get current theme colors
    colors := get_theme_colors(state.theme)

    // Clear background with theme color
    rl.ClearBackground(colors.background)

    // Render menu
    render_menu(state)

    // Render text area
    render_text_area(state, state.text_area, state.font_size)

    // Draw text area border with theme color
    rl.DrawRectangleLinesEx(state.text_area, 1, colors.border)

    // Render dialogs on top (after text area)
    if state.show_filter_dialog {
        render_filter_dialog(state)
    }

    if state.show_find_dialog {
        render_find_dialog(state)
    }

    if state.show_highlight_dialog {
        render_highlight_dialog(state)
    }

    if state.show_help_dialog {
        render_help_dialog(state)
    }

    // Render search message if active
    if state.show_search_message {
        render_search_message(state)
    }
}

// Render search message overlay
render_search_message :: proc(state: ^State) {
    colors := get_theme_colors(state.theme)

    message := "Nothing found"
    message_cstr := strings.clone_to_cstring(message)
    defer delete(message_cstr)

    // Calculate message position (center of screen)
    message_width := rl.MeasureTextEx(state.font, message_cstr, 20, 1).x
    message_height: f32 = 30
    message_x := (f32(rl.GetScreenWidth()) - message_width) / 2
    message_y := (f32(rl.GetScreenHeight()) - message_height) / 2

    // Draw background rectangle
    rl.DrawRectangle(i32(message_x - 10), i32(message_y - 5), i32(message_width + 20), i32(message_height + 10), colors.dialog_background)
    rl.DrawRectangleLinesEx(rl.Rectangle{message_x - 10, message_y - 5, message_width + 20, message_height + 10}, 2, colors.input_border)

    // Draw message text
    rl.DrawTextEx(state.font, message_cstr, {message_x, message_y}, 20, 1, colors.dialog_text)
}