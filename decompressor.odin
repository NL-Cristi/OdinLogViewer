package main

import "core:os"
import "core:path/filepath"
import "core:fmt"
import "core:mem"
import "vendor:zlib"

// Embed compressed files

opengl_dll_compressed := #load("src/resources/zlib/opengl32.dll.zlib");
myfont_ttf_compressed := #load("src/resources/zlib/MyFont.ttf.zlib");

// Function to decompress and extract an embedded file to the executable's directory
extract_embedded_file :: proc(compressed_data: []byte, filename: string) -> bool {
    // Prepare decompression buffer
    dest_len := u32(len(compressed_data) * 10)
    decompressed_data := make([]u8, dest_len, context.allocator)
    defer delete(decompressed_data, context.allocator)

    // Decompress the data
    result := zlib.uncompress(
        raw_data(decompressed_data), &dest_len,
        raw_data(compressed_data), u32(len(compressed_data)),
    )
    if result != zlib.OK {
        fmt.eprintf("Failed to decompress %s: zlib error %d\n", filename, result)
        return false
    }

    // Get the executable's directory
    exe_path := os.get_current_directory()
    defer delete(exe_path, context.allocator)

    // Construct the output path
    output_path := filepath.join({exe_path, filename})
    defer delete(output_path, context.allocator)

    // Write the decompressed file
    write_ok := os.write_entire_file(output_path, decompressed_data[:dest_len], false)
    if !write_ok {
        fmt.eprintf("Failed to write %s\n", output_path)
        return false
    }

    fmt.printf("Successfully extracted %s to %s (%d bytes)\n", filename, output_path, dest_len)
    return true
}

main :: proc() {
    // Extract both files
    if !extract_embedded_file(opengl_dll_compressed[:], "opengl32.dll") {
        fmt.eprintf("Extraction failed for opengl32.dll\n")
    }

    if !extract_embedded_file(myfont_ttf_compressed[:], "MyFont.ttf") {
        fmt.eprintf("Extraction failed for MyFont.ttf\n")
    }
}