package text_analyzer

import "core:fmt"
import "core:strings"

// Filter application (Phase 3.1)
apply_filters :: proc(state: ^State) {
    if len(state.filters) == 0 {
        // No filters, restore original lines
        clear(&state.logical_lines)
        for line in state.original_lines {
            append(&state.logical_lines, strings.clone(line))
        }
        state.needs_redraw_display_lines = true
        return
    }

    // Create filtered logical lines
    filtered_lines := make([dynamic]string)
    defer delete(filtered_lines)

    for i := 0; i < len(state.original_lines); i += 1 {
        line := state.original_lines[i]
        include_line := true

        // Check Include filters (OR logic - any include filter can match)
        has_include_filters := false
        include_matches := false
        for filter in state.filters {
            if !filter.enabled do continue
            if filter.type == .Include {
                has_include_filters = true
                if strings.contains(line, filter.pattern) {
                    include_matches = true
                    break
                }
            }
        }

        // If we have include filters but none match, exclude this line
        if has_include_filters && !include_matches {
            include_line = false
        }

        // Check Exclude filters (AND logic - any exclude filter excludes)
        for filter in state.filters {
            if !filter.enabled do continue
            if filter.type == .Exclude {
                if strings.contains(line, filter.pattern) {
                    include_line = false
                    break
                }
            }
        }

        if include_line {
            append(&filtered_lines, strings.clone(line))
        }
    }

    // Update logical lines with filtered content
    clear(&state.logical_lines)
    for line in filtered_lines {
        append(&state.logical_lines, line)
    }

    // Mark that we need to regenerate display lines
    state.needs_redraw_display_lines = true
}

// Add a new filter
add_filter :: proc(state: ^State, filter_type: FilterType, pattern: string, is_regex: bool) {
    filter := Filter{
        type = filter_type,
        pattern = strings.clone(pattern),
        is_regex = is_regex,
        enabled = true,
    }
    append(&state.filters, filter)
    apply_filters(state)
}

// Remove a filter
remove_filter :: proc(state: ^State, index: int) {
    if index >= 0 && index < len(state.filters) {
        delete(state.filters[index].pattern)
        ordered_remove(&state.filters, index)
        apply_filters(state)
    }
}

// Toggle filter enabled state
toggle_filter :: proc(state: ^State, index: int) {
    if index >= 0 && index < len(state.filters) {
        state.filters[index].enabled = !state.filters[index].enabled
        apply_filters(state)
    }
}