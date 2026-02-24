//! Entry point for the Helios OS kernel. This is where the kernel begins execution after the bootloader hands
//! control over to it.
#![no_std]
#![no_main]

const MULTIBOOT2_MAGIC: u32 = 0xE85250D6; // Multiboot magic number
const MULTIBOOT2_ARCHITECTURE: u32 = 0; // i386
const MULTIBOOT2_END_TAG_SIZE: u32 = 1 << 3; // Size of the end tag

#[repr(C)]
#[repr(align(8))] // Align the header at an 8 byte boundary, as required by the Multiboot specification
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
#[unsafe(link_section = ".multiboot")]
static MULTIBOOT_HEADER: MultibootHeader = MultibootHeader {
    magic: MULTIBOOT2_MAGIC,
    architecture: MULTIBOOT2_ARCHITECTURE,
    length: core::mem::size_of::<MultibootHeader>() as u32,
    checksum: {
        let sum = MULTIBOOT2_MAGIC
            .wrapping_add(MULTIBOOT2_ARCHITECTURE)
            .wrapping_add(core::mem::size_of::<MultibootHeader>() as u32);
        (!sum).wrapping_add(1) // Two's complement to get the checksum
    },
    end_tag_type: 0,
    end_tag_flags: 0,
    end_tag_size: MULTIBOOT2_END_TAG_SIZE,
};

/// The entry point for the kernel. This function is called by the bootloader after
/// it has loaded the kernel.
#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    #[allow(clippy::empty_loop)]
    loop {}
}

/// Raw panic handler that does nothing but loop indefinitely for now. We'll
/// need to implement a more robust panic handler later, but this will allow us to
/// compile and run our code without crashing immediately on panic.
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    #[allow(clippy::empty_loop)]
    loop {}
}
