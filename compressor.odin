package main

import "core:os"
import "core:path/filepath"
import "core:fmt"
import "core:strings"
import "core:mem"
import "vendor:zlib"

compress_file :: proc(input_path, output_path: string) -> bool {
    fmt.printf("Starting compression of: %s\n", input_path)

    // Read the input file
    data, read_ok := os.read_entire_file(input_path, context.allocator)
    if !read_ok {
        fmt.eprintf("Failed to read %s\n", input_path)
        return false
    }

    fmt.printf("File read successfully, size: %d bytes\n", len(data))

    // Prepare compression buffers
    // zlib.compress2 requires a destination buffer sized at least 0.1% larger than source + 12 bytes
    dest_len := u32(len(data) + (len(data) >> 10) + 12)
    compressed_data := make([]u8, dest_len, context.allocator)

    fmt.printf("Compression buffer allocated, size: %d bytes\n", dest_len)

    // Compress the data (level 9 for maximum compression)
    result := zlib.compress2(
        raw_data(compressed_data), &dest_len,
        raw_data(data), u32(len(data)),
        9, // Compression level (0-9, 9 is max)
    )
    if result != zlib.OK {
        fmt.eprintf("Failed to compress %s: zlib error %d\n", input_path, result)
        delete(data, context.allocator)
        delete(compressed_data, context.allocator)
        return false
    }

    fmt.printf("Compression completed, compressed size: %d bytes\n", dest_len)

    // Write the compressed data
    write_ok := os.write_entire_file(output_path, compressed_data[:dest_len], false)
    if !write_ok {
        fmt.eprintf("Failed to write %s\n", output_path)
        delete(data, context.allocator)
        delete(compressed_data, context.allocator)
        return false
    }

    fmt.printf("Successfully compressed %s to %s (%d bytes)\n", input_path, output_path, dest_len)

    // Clean up memory manually
    delete(data, context.allocator)
    delete(compressed_data, context.allocator)

    fmt.printf("Compression of %s completed successfully\n", input_path)
    return true
}

main :: proc() {
    // Input and output directories
    input_dir := "src/resources"
    output_dir := filepath.join({input_dir, "zlib"})
    defer delete(output_dir, context.allocator)

    // Create output directory if it doesn't exist
    if !os.exists(output_dir) {
        err := os.make_directory(output_dir, 0o755)
        if err != nil {
            fmt.eprintf("Failed to create directory %s: %v\n", output_dir, err)
            return
        }
    }

    // Files to compress
    files := [2]string{"opengl32.dll", "MyFont.ttf"}



        // Process opengl32.dll first
    fmt.printf("=== Processing opengl32.dll ===\n")
    input_path1 := filepath.join({input_dir, "opengl32.dll"})
    output_path1 := filepath.join({output_dir, "opengl32.dll.zlib"})

    if !compress_file(input_path1, output_path1) {
        fmt.eprintf("Failed to compress opengl32.dll\n")
        return
    }

    delete(input_path1, context.allocator)
    delete(output_path1, context.allocator)

    fmt.printf("=== opengl32.dll completed ===\n")

    // Process MyFont.ttf second
    fmt.printf("=== Processing MyFont.ttf ===\n")
    input_path2 := filepath.join({input_dir, "MyFont.ttf"})
    output_path2 := filepath.join({output_dir, "MyFont.ttf.zlib"})

    if !compress_file(input_path2, output_path2) {
        fmt.eprintf("Failed to compress MyFont.ttf\n")
        return
    }

    delete(input_path2, context.allocator)
    delete(output_path2, context.allocator)

    fmt.printf("=== MyFont.ttf completed ===\n")
    fmt.printf("All files processed successfully!\n")

}