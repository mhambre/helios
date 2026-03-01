# Phase #0 - Core Architecture and Mock System Call Interface

In this phase, we will be building the core components of the Helios system, including the daemon, CLI, and basic APIs. The focus will be on establishing a solid foundation for the system's architecture, ensuring modularity, scalability, and maintainability. We will also be defining the core data structures and interfaces that will be used throughout the system, as well as implementing basic functionality for managing and monitoring the system's resources. This phase will set the stage for future development and expansion of the Helios system, allowing us to build upon a strong architectural foundation as we add more features and capabilities in subsequent phases.

The fundamental design principles for this phase will include separation of concerns, modularity, and extensibility, ensuring that the system can evolve and adapt to changing requirements over time. As such there will be a mock system call interface that will be used to simulate interactions with the underlying operating system, allowing us to test and validate our design without needing to implement a full operating system kernel at this stage. By having this abstract layer, when we eventually implement the actual system call interface, we can simply replace the mock implementation with the real one without needing to change the higher-level components of the system. This approach will allow us to focus on building the core architecture and functionality of the system without getting bogged down in low-level details at this early stage of development.

### Key Deliverables:
- Core Daemon Implementation:
    - Build with core datastructures from libraries (e.g. https://docs.rs/lsm-tree/latest/lsm_tree/)
    - Hand rolled HTTP server for exposing APIs
    - Basic resource monitoring and management capabilities (e.g. CPU, memory, disk usage)
    - Basic process management capabilities endpoints (e.g. start/stop processes, monitor resource usage)
    - Basic logging and error handling mechanisms (e.g. using the `log` crate for structured logging)
    - Core file management capabilities (e.g. read/write files, manage file metadata)
    - Basic configuration management (e.g. load/save configuration files, manage system settings)
    - After this is all done, we will have a functional daemon that can manage and monitor system resources, and do our basic file management operations. This will be a critical milestone in our development process, unfortunately, we're going to have to go back through and rewrite all functionality using non-std dependencies in this codebase in the next phase, but for now, we can use these libraries to quickly iterate and build out our core functionality without needing to worry about low-level details of implementing these features ourselves at this stage.

- Command-Line Interface (CLI)
    - Basic CLI tool for interacting with the daemon (e.g. using `clap` crate for argument parsing)
    - Commands for managing processes, monitoring resources, and performing file operations
    - Basic output formatting and error handling for CLI commands
    - This will allow us to have a simple interface for users to interact with the daemon and perform basic operations on the system. The CLI will be designed to be extensible, allowing us to easily add new commands and functionality as we continue to develop the system in future phases.

- Mock System Call Interface
    - low-level/std-lib operations cfg gated behind our custom target
    - tokio-fs for async file operations to mock file system interactions
    - mock implementations for process management, networking (sockets), memory management, and other system/sysinfo interactions

---
[[Index]](index.md) [[Next Page]](phase_1.md)
