# Booting a Simple Kernel

Now that we've found a way to [produce a binary without a standard library in Rust](./core-only-binary.md), we are able to use that binary as our kernel. The next logical step is to find a way to run this code without an operating system underneath it. This is where bootloaders come in. The goal of a bootloader is to find and execute the kernel of one or more operating systems on a disk. They are pretty nifty, and from my research it is not hard to make a very simple one for very specific hardware like the [i386](https://en.wikipedia.org/wiki/I386). However, things can start to get complicated when you want cross-compatibility and the ability to support multiple operating systems on one disk.

This is why I chose to make my operating system bootable with [GRUB](https://en.wikipedia.org/wiki/GNU_GRUB), the standard bootloader used by most Linux distributions. The first step was figuring out how to make a usable [ISO](https://en.wikipedia.org/wiki/Optical_disc_image). Fortunately, GRUB provides a utility called `grub-mkrescue` for crafting a rescue ISO in the event something (Windows is a common culprit) overwrites your bootloader.

GRUB expects a specific folder layout for building an ISO, but the core requirement is a file at `/boot/grub/grub.cfg` for your configuration. A GRUB config defines what we want our bootloader menu to include. While we can place our kernel ELF in a specific directory, traditionally `/boot`, we still need to tell GRUB how to treat it as a bootable kernel. This is how we configure GRUB:

```
set timeout=15                         # How long we wait before booting our default (seconds)
set default=0                          # Set first index option to be default boot (Helios)

menuentry "Helios" {                   # Name to show in GRUB boot menu
    multiboot /boot/helios-core.elf    # Kernel location on ISO (use Multiboot spec, will explain and change)
    boot                               # Validate the binary and execute it
}
```

As a side note, because I am using [devcontainers](https://containers.dev/) for this project, I will not have graphics to boot an operating system within the container. Because of that, I also have an additional configuration with GRUB serial support. This is achieved with the following config options:

```
serial --unit=0 --speed=115200
terminal --timeout=5 serial console
```

Now that we have our GRUB configuration, the proper folder layout, and our binary in place, we can produce our ISO with the command:

```
grub-mkrescue -o <ISO File> <Directory Holding GRUB Scaffold>
```

Most of that should seem pretty intuitive. We can load the produced ISO into a hypervisor like QEMU and we will boot into GRUB. However, if we attempt to boot our kernel, we will receive an error:

```
error: no multiboot header found
```

This error is pretty indicative of what went wrong, but what is a Multiboot header? According to the [OSDev Wiki](https://wiki.osdev.org/Multiboot): "The Multiboot specification is an open standard that provides kernels with a uniform way to be booted by Multiboot-compliant bootloaders. The reference implementation of the Multiboot specification is provided by GRUB."

In our GRUB config, we annotated our binary as `multiboot` without much thought to what that meant. Essentially, our binary is not bootable because GRUB expects it to contain a specific header, and we never provided one. Multiboot is the original specification, but there is a newer version supported by GRUB called Multiboot2, so we will use that instead. To start, we need to change the annotation to `multiboot2`.

Next, we need to add a Multiboot2 header to our compiled binary. The header is a small data structure with required fields defined in the [Multiboot2 specification](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.pdf). In Rust, this looks like the following:

```rust
/* main.rs */
const MULTIBOOT2_MAGIC: u32 = 0xE85250D5;        // Multiboot2 magic number
const MULTIBOOT2_ARCHITECTURE: u32 = 0;          // i386 architecture
const MULTIBOOT2_END_TAG_SIZE: u32 = 1 << 3;     // Size of the end tag (8 bytes)

#[repr(C)]
#[repr(align(8))] // Align the header on an 8 byte boundary as required by the spec
struct MultibootHeader {
    magic: u32,
    architecture: u32,
    length: u32,
    checksum: u32,
    // End tag: type(u16), flags(u16), size(u32)
    end_tag_type: u16,
    end_tag_flags: u16,
    end_tag_size: u32,
}

#[used]
#[unsafe(link_section = ".multiboot")]           // Force linker section name
static MULTIBOOT_HEADER: MultibootHeader = MultibootHeader {
    magic: MULTIBOOT2_MAGIC,
    architecture: MULTIBOOT2_ARCHITECTURE,
    length: core::mem::size_of::<MultibootHeader>() as u32,
    checksum: {
        let sum = MULTIBOOT2_MAGIC
            .wrapping_add(MULTIBOOT2_ARCHITECTURE)
            .wrapping_add(core::mem::size_of::<MultibootHeader>() as u32);
        (!sum).wrapping_add(1) // Two's complement
    },
    end_tag_type: 0,
    end_tag_flags: 0,
    end_tag_size: MULTIBOOT2_END_TAG_SIZE,
};
```

Now we have a Multiboot2-compliant header in our binary, but it is not really a header yet because we make no guarantee about where the linker will place it. To control the layout of the final binary, we use a linker script. Our linker script looks like this, and it ensures the Multiboot header is placed before the rest of the kernel while keeping `_start` as the entry point:

```ld
/* linker.ld */
ENTRY(_start)                             /* Entrypoint symbol defined in main.rs */

OUTPUT_FORMAT("elf32-i686")             /* Output ELF file format */
OUTPUT_ARCH(i386)                  /* Target architecture */

SECTIONS
{
    . = 1M;                               /* Load address for the kernel (1 MiB)
                                             This keeps us above the real-mode/BIOS area.
                                          */

    .multiboot ALIGN(4K) : {
        KEEP(*(.multiboot))               /* Keep Multiboot header even though it is unused */
    }

    .text ALIGN(4K) : {
        *(.text._start)                   /* Force start symbol to front of text section */
        *(.text*)
    }

    .rodata ALIGN(4K) : {
        *(.rodata*)
    }

    .data ALIGN(4K) : {
        *(.data*)
    }

    .bss ALIGN(4K) : {
        __bss_start = .;
        *(.bss*)                          /* Rest of bss */
        *(COMMON)                         /* Legacy common symbols */
        __bss_end = .;
    }
}
```

We also use the `ALIGN(4K)` directive to match the page size, which keeps page table mappings clean. This does slightly inflate the binary because of padding, but it keeps the layout simple.

To make Cargo use this linker script, we add the following line to our [build script](https://doc.rust-lang.org/cargo/reference/build-scripts.html):

```rust
// Linker file location is relative to CARGO_MANIFEST_DIR
println!("cargo:rustc-link-arg=-T{LINKER_FILE_LOCATION}");
```

After compiling, we can verify that our binary is Multiboot2-compatible with this command:

```bash
grub-file --is-x86-multiboot2 {Your binary location} && echo "Kernel binary is Multiboot2 compliant" || echo "Kernel binary is not Multiboot2 compliant"
```

Now if we rebuild our GRUB ISO and attempt to boot into Helios, we will see a black screen. This may not seem like much, but it means that we successfully booted into our binary and it is now running and looping forever. At this point, we have officially created a very simple "operating system".

### Resources

* [Getting Started with EFI](https://krinkinmu.github.io/2020/10/11/efi-getting-started.html)
* [Using GRUB to boot your OS](https://wiki.osdev.org/GRUB#Using_GRUB_to_boot_your_OS)
* [Serial QEMU](https://support.hpe.com/hpesc/public/docDisplay?docId=a00105236en_us&page=GUID-BA63AAEB-4274-4A99-8C1D-39B6BF87BD16.html&docLocale=en_US)
* [Making a GRUB bootable CD-ROM](https://www.gnu.org/software/grub/manual/grub/html_node/Making-a-GRUB-bootable-CD_002dROM.html)
* [GNU Parted](https://www.gnu.org/software/parted/manual/parted.html)
* [Multiboot](https://wiki.osdev.org/Multiboot)
* [Linker Scripts](https://wiki.osdev.org/Linker_Scripts)
* [Multiboot2 Spec](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.pdf)


---

[[Previous Page]](./core-only-binary.md) [[Index]](./index.md) [[Next Page]](stub)
