# Core-Only Binary

### Table of Contents
- [Premise](#premise)
- [Implementation](#implementation)
- [Custom Target](#custom-target)

### Premise
Before we can do absolutely anything we need to strip Rust down to its basics. Programmers are familiar with the std libs of Rust, C/C++, Go, etc. Unfortunately, the standard library is designed to perform OS specific operations (i.e. the `std::fs` library of Rust needs a filesystem and set of OS-specific operations in order to do its "thing"). Currently we don't even have the semblance of an OS, and even if we did, we'd need to define all of these specific operations in the Rust standard library for our specific OS.

Fortunately, programming languages are much more than their standard libraries, and standard libraries merely use the "core" of the underlying programming language (and a dash assembly) to implement and abstract these operations from users. In Rust we are provided with the "core" crate of the language which implements all of Rust's OS-agnostic functionality such as functions, `Result`/`Option`, core data-types etc. Thus we aren't completely out of luck, we can still compile a bare-bones binary using this concept.

### Implementation
To do this we take advantage of three attributes in the `main.rs` source file of our soon (unlikely) to be Kernel:
- `#![no_std]`: Tells the compiler to not include Rust's standard library since we cannot use it.
- `#![no_main]`: Main is a process entrypoint convention provided by the runtime. Since we don't have a runtime because we're at the bare-metal we'll need an entrypoint that will be understood in the future by our bootloader
- `#[panic_handler]`: This allows us to define a custom panic handler (for now we'll just define it as an infinite loop) since we don't have a runtime or unwinding support. If we don't implement this we won't be able to compile.

```rust
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
```

Lastly, we need to define our "main". Those familiar with Assembly programming have seen the `_start:` entrypoint symbol before that assemblers use as an entrypoint to the process. We will define our own `_start:` function that for now will just keep the program running with an infinite loop. Since the compiler usually doesn't care what a function is called (unlike us humans who like fancy names) the function name symbol will end up being some string of gibberish. So that we can make sure this symbol stays `_start` we use the `#[unsafe(no_mangle)]` attribute to prevent name mangling which is essentially just the symbol name randomization the compiler does when it doesn't care what a symbol is called. In the future, GRUB, the bootloader we plan to implement, will know that this `_start` symbol is the entrypoint to our OS.

```rust
#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    loop {}
}
```

Now we can build out binary with `cargo build` and we've successfully made a Rust binary with no standard library. If we attempt to run it, our "kernel" entrypoint will just loop forever until we've defined real functionality.

### Custom Target

When we compiled previously we were using our system's default target (basically a recipe for how Rust compilation is to be done) on different systems. Since we are making the system we have to avoid making some of these assumptions that match that of our base-OS and configure our own that will allow this binary to truly run on bare-metal. Below is the recipe we will be using for now. It is subject to change as the OS grows and we implement more.

- `x86_64-helios.json`:
```json
{
    // Signal that we are on 64-bit x86_64 with no vendor and no OS (bare-metal)
    "llvm-target": "x86_64-unknown-none",
    // LLVM string for how data is laid out in memory (taken from x86_64-unknown-none)
    "data-layout": "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i128:128-f64:32:64-f80:32-n8:16:32-S128",
    // CPU Architecture (target arch for cfg and codegen)
    "arch": "x86",
    // Byte order
    "target-endian": "little",
    // Size of our pointers
    "target-pointer-width": 32,
    // Size of C-ints on our system for C ABI interoperability
    "target-c-int-width": 32,
    // We are the OS!
    "os": "none",
    // The kernel is executable (ELF executable/kernel image)
    "executables": true,
    // Emit an ELF executable binary
    "exe-suffix": ".elf",
    // Use GNU ld-like mode for linker
    "linker-flavor": "ld.lld",
    // Use Rust's shipped linker for cross-platform support
    "linker": "rust-lld",
    // We don't have unwinding support
    "panic-strategy": "abort",
    // Emulate floats
    "features": "-mmx,-sse,+soft-float",
    "rustc-abi": "x86-softfloat"
}
```

To build now we must point cargo to our custom target. Rust stable doesn't support this yet for our flow, so we use nightly and pass the unstable flags directly. The command to achieve this is:

`cargo +nightly build -p helios-core -Zjson-target-spec -Z build-std=core --target template/x86_64-helios.json`

(add nightly toolchain with `rustup toolchain install nightly`).

We also wire this into the project build scripts (`make kd`, `make kr`, or `just build core <debug|release>`) so we don't have to type the full cargo command every time.

Historically this was configured in `.cargo/config.toml` with:

```toml
[unstable]
json-target-spec = true # So we can use a custom target
build-std = [
    "core",
    "compiler_builtins",
] # So we can use the core lib (Result, Option, etc.) without the full standard library

```

Now you should be able to build the binary properly and this freestanding ELF binary will be the entrypoint our bootloader will use for our operating system.

### Resources

- [Rust Core](https://doc.rust-lang.org/core/)
- [Rust Targets](https://doc.rust-lang.org/beta/rustc/targets/index.html)
- [Rust Binaries w/out Std](https://medium.com/@theopinionatedev/inside-rusts-no-main-world-how-binaries-run-without-std-a0d15d9dcb11)
- [Name mangling](https://en.wikipedia.org/wiki/Name_mangling)
- [Red Zone](https://en.wikipedia.org/wiki/Red_zone_(computing))

---
[[Index]](./index.md) [[Next Page]](booting-simple-kernel.md)
