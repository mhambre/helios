//! Entry point for the Helios OS kernel. This is where the kernel begins execution after the bootloader hands
//! control over to it.
#![no_std]
#![no_main]

/// The entry point for the kernel. This function is called by the bootloader after
/// it has loaded the kernel.
#[unsafe(no_mangle)]
pub extern "C" fn _start() -> ! {
    loop {}
}

/// Raw panic handler that does nothing but loop indefinitely for now. We'll
/// need to implement a more robust panic handler later, but this will allow us to
/// compile and run our code without crashing immediately on panic.
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
