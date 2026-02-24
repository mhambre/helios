use std::path::PathBuf;
use std::{env, fs};

fn main() {
    dotenvy::dotenv().expect("read `.env`");

    println!("cargo:rerun-if-changed=template/linker.ld.in");
    println!("cargo:rerun-if-env-changed=TARGET");

    let target = env::var("TARGET").expect("TARGET not set");
    let project_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");

    let (out_format, out_arch) = match target.as_str() {
        "x86_64-helios" => ("elf64-x86-64", "i386:x86-64"),
        other => panic!("unsupported TARGET for linker script: {other}"),
    };

    let template =
        fs::read_to_string(PathBuf::from(&project_dir).join("../../template/linker.ld.in")).expect("read linker.ld.in");
    let rendered = template
        .replace("__OUTPUT_FORMAT__", out_format)
        .replace("__OUTPUT_ARCH__", out_arch);

    let out_path = PathBuf::from(project_dir).join("src/linker.ld");
    fs::write(&out_path, rendered).expect("write generated src/linker.ld");

    // Tell rustc to pass the script to the linker
    println!("cargo:rustc-link-arg=-T{}", out_path.display());
}
