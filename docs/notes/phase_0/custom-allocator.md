# Bootstrapping a Free-List Allocator from Raw Memory

## Premise

The next post in this series covers building a custom async runtime. Before we can get there, we need a heap, without one, every data structure is fixed-size and stack-allocated. This means no `Box`, no `Vec`, and no way to store a dynamically-dispatched `Future`. This post builds that foundation: a free-list allocator bootstrapped from raw memory, implemented from scratch.

Getting this right also unlocks something ergonomically valuable: once we have a heap, we can wrap any function's state in a `Box<dyn Future>` without needing to hand-roll a custom `Future` impl for it. That's the machinery behind:

```rust
struct Task {
    future: Pin<Box<dyn Future<Output = ()>>>,
}
```

---

## Brief Overview of Stack vs. Heap

In terms of memory management, there are two regions we need to be concerned with: the **stack** and the **heap**.

The **stack** stores local variables and function call information. When a function returns, its stack frame is popped and that memory is automatically reclaimed, hence you cannot return a reference to a locally-created variable. The **heap**, on the other hand, is used for dynamic allocation. When you call `Box::new()` in Rust, you're allocating memory on the heap, and you can safely return that `Box` because the memory persists until explicitly dropped (no in scope).

```rust
/// Returns heap-allocated memory that remains valid after the function returns.
fn heap_memory() -> Box<i32> {
    Box::new(42)
}

/// Fails to compile: returns a reference to stack memory that will be
/// deallocated when the function returns, causing a dangling reference.
fn stack_memory() -> &i32 {
    let i = 42;
    &i
}
```

This is a core source of Rust's safety guarantees. The ownership system prevents dangling references, and the borrow checker prevents simultaneous mutable aliasing. We will be taking advantage of these features along with Rust's heap allocation API via our custom allocator.

Hooking into Rust's allocator infrastructure is straightforward: implement the [`GlobalAlloc`](https://doc.rust-lang.org/std/alloc/trait.GlobalAlloc.html) trait, and Rust will route all `Box::new()`, `Vec`, and other heap allocation calls through it. By default, Rust invisibly injects its own system allocator:

```rust
use std::alloc::System;

#[global_allocator]
static GLOBAL: System = System;
```

Since Helios is a custom OS, we won't always have a `System` allocator available, so we'll implement our own from scratch.

---

## Types of Heap Allocators

There are three common allocator designs worth knowing. We're using the free-list, but the others are useful reference points for understanding the trade-offs.

| Allocator | Alloc speed | Dealloc | Variable sizes | Fragmentation |
|---|---|---|---|---|
| **Bump / Arena** | O(1) | Bulk only | No | None |
| **Free-List** | O(n) | O(n) | Yes | Yes |
| **Pool** | O(1) | O(1) | No (fixed size) | Low (if sized well) |

**Bump / Arena**: maintains a single pointer to the next free address and bumps it forward on each allocation. Extremely fast, but deallocation is all-or-nothing. The managed region must be contiguous, and expansion requires remapping. No fragmentation since memory is always linear.

**Free-List**: maintains a linked list of free blocks. Allocation searches for a block large enough to satisfy the request; deallocation returns the block to the list. Supports arbitrary sizes and non-contiguous heap growth, but is slower and fragmentation is a real concern.

**Pool**: manages a fixed-size pool of uniformly-sized blocks. O(1) for same-sized objects, but unsuitable for variable-size allocations.

A good visual overview of these can be found [here](https://www.youtube.com/watch?v=Cdger2-hlt4).

For general-purpose use we'll implement a **free-list allocator**, which is the most flexible of the three. Interestingly, for the async runtime specifically, a bump allocator would actually be a better fit because futures are recursive structures and the all-at-once deallocation model maps well onto a task's lifetime. We'll revisit that in the next post.

---

## Deep Dive into Free-List Allocators

The free-list allocator maintains a linked list of available memory blocks. On allocation, it searches for a block large enough to satisfy the request, unlinks it, and returns a pointer. If no suitable block exists, it asks the kernel for more memory. On deallocation, the block is reinserted into the list.

The main drawbacks are potential fragmentation and the linear-time cost of searching the list. For now we'll use **first-fit** allocation and a simple **linked list**, the simplest combination, and optimize later down the road.

### Placement Strategies

- **First-Fit**: Returns the first block large enough to satisfy the request. Simple and fast, but tends to leave small unusable gaps scattered through the heap.
- **Best-Fit**: Searches the entire list for the closest-sized block. Reduces fragmentation but incurs a full-list scan on every allocation.
- **Worst-Fit**: Returns the largest available block. Leaves behind large remainders but can still cause fragmentation over time.

### Free-List Data Structures

- **Linked List**: Simple to implement. Coalescing adjacent freed blocks requires care but is manageable, as we'll see.
- **Balanced Binary Tree**: Enables O(log n) insertion and deletion and makes coalescing easier, at the cost of implementation complexity.
- **Bitmap**: Efficient for large uniform blocks; less so for small variable-size allocations.
- **Segregated Free Lists**: Separate lists per size class reduce fragmentation but add management complexity.

---

## Implementation

### Getting Raw Memory from the Kernel

The first step is obtaining raw memory. We'll use the `mmap` system call, which can allocate anonymous memory (not backed by any file), the modern replacement for the older `sbrk` interface. Unlike `sbrk`, `mmap` doesn't invalidate existing pointers and supports multiple independent heap regions.

Rather than depending on the `libc` crate, we'll make syscalls directly with inline assembly so there's nothing to swap out when we move to our own kernel. The only portion of `libc` we'll use is the provided constants for things like flags and errno codes. The x86_64 Linux syscall convention is:

- Syscall number → `rax`
- Arguments → `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9` (in order)
- Invoke with the `syscall` instruction
- Return value → `rax` (negative values indicate errors)

To avoid writing the same assembly boilerplate for every syscall, we define a macro that generates typed wrappers:

```rust
use core::arch::asm;

#[inline(always)]
fn decode_ret(ret: isize) -> Result<usize, i32> {
    if (-4095..=-1).contains(&ret) {
        Err((-ret) as i32)
    } else {
        Ok(ret as usize)
    }
}

macro_rules! define_syscall {
    ($name:ident ( $($arg:ident),* ) [ $($operands:tt)* ]) => {
        #[inline(always)]
        pub(crate) unsafe fn $name(num: u64 $(, $arg: usize)*) -> Result<usize, i32> {
            let ret: isize;
            unsafe {
                asm!(
                    "syscall",
                    inlateout("rax") num as usize => ret,
                    $($operands)*
                    lateout("rcx") _,
                    lateout("r11") _,
                );
            }
            decode_ret(ret)
        }
    };
}

define_syscall!(syscall0() []);
define_syscall!(syscall1(a1) [in("rdi") a1,]);
define_syscall!(syscall2(a1, a2) [in("rdi") a1, in("rsi") a2,]);
define_syscall!(syscall3(a1, a2, a3) [in("rdi") a1, in("rsi") a2, in("rdx") a3,]);
define_syscall!(syscall4(a1, a2, a3, a4) [in("rdi") a1, in("rsi") a2, in("rdx") a3, in("r10") a4,]);
define_syscall!(syscall5(a1, a2, a3, a4, a5) [in("rdi") a1, in("rsi") a2, in("rdx") a3, in("r10") a4, in("r8") a5,]);
define_syscall!(syscall6(a1, a2, a3, a4, a5, a6) [in("rdi") a1, in("rsi") a2, in("rdx") a3, in("r10") a4, in("r8") a5, in("r9") a6,]);
```

Using these, our `mmap` wrapper becomes:

```rust
pub(crate) unsafe fn mmap(
    addr: usize, length: usize, prot: usize,
    flags: usize, fd: usize, offset: usize,
) -> Result<usize, i32> {
    // mmap requires page-aligned offsets.
    if (offset & 0xFFF) != 0 {
        return Err(libc::EINVAL);
    }
    let ret = unsafe { syscall6(SYS_MMAP, addr, length, prot, flags, fd, offset) };
    decode_ret(ret)
}
```

The key `mmap` parameters for our use case:

- `addr = 0`: let the kernel choose the mapping address
- `prot = PROT_READ | PROT_WRITE`: readable and writable
- `flags = MAP_PRIVATE | MAP_ANONYMOUS`: not backed by a file; not shared with other processes
- `fd = -1`, `offset = 0`: ignored for anonymous mappings

---

### The Base Trait

The trait to implement is [`GlobalAlloc`](https://doc.rust-lang.org/beta/core/alloc/trait.GlobalAlloc.html) from `core::alloc` (usable in `no_std`):

```rust
pub unsafe trait GlobalAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8;
    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout);
}
```

`Layout` carries the size and alignment requirements for each allocation. We'll do minimal work directly in these trait methods and delegate everything to helper methods on our allocator struct.

---

### Core Data Structures

```rust
pub struct FLAllocator {
    /// Head of the free list (stored as a raw address for atomic access).
    head: AtomicUsize,
    /// Initialization state: ensures setup runs exactly once.
    state: AtomicAllocState,
}
```

The `AtomicAllocState` wraps an enum generated by the `atomic_enum` macro:

```rust
#[derive(PartialEq)]
#[atomic_enum]
pub(super) enum AllocState {
    Uninitialized,
    InProgress,
    Ready,
}
```

Free blocks in the list are represented as:

```rust
struct FreeBlock {
    size: usize,
    next: *mut FreeBlock,
}
```

---

### Initialization

On the first allocation, we ask the kernel for an initial heap region and bootstrap it into a single `FreeBlock` spanning the entire region. After that call, the raw memory looks like this:

![Initial heap layout](../../static/notes/phase0/Helios-Sci-Initial-Heap.svg)

The `FreeBlock` header occupies the first `mem::size_of::<FreeBlock>()` bytes of the mapped region, with its `size` field covering the full mapping including itself. Everything after the header is allocatable space. The `&FreeBlock` pointer stored in `head` points to the start of this region.

```rust
impl FLAllocator {
    unsafe fn init(&self) -> Result<(), i32> {
        // Fast path: already initialized.
        if self.state.load(Ordering::Acquire) == AllocState::Ready {
            return Ok(());
        }

        cfg_if::cfg_if! {
            if #[cfg(target_os = "linux", target_arch = "x86_64")] {
                let heap = crate::util::functions::mmap(
                    0, DEFAULT_HEAP_SIZE,
                    libc::PROT_WRITE | libc::PROT_READ,
                    libc::MAP_PRIVATE | libc::MAP_ANON,
                    -1, 0
                ).unwrap_or(null_mut());
            } else {
                compile_error!("Unsupported Target OS");
            }
        }

        let block = heap as *mut FreeBlock;
        unsafe {
            (*block).size = DEFAULT_HEAP_SIZE;
            (*block).next = null_mut();
        }

        // Publish with Release so subsequent Acquire loads observe all writes above.
        self.head.store(block as usize, Ordering::Release);
        self.state.store(AllocState::Ready, Ordering::Release);
        Ok(())
    }
}
```

A note on the atomic orderings: we use `Ordering::Acquire` on the fast-path load and `Ordering::Release` on the stores. If you're not familiar with atomics, the key idea is that `Release` on a store "publishes" all preceding writes, and `Acquire` on a load "sees" everything published before that store. In practice: any thread that observes `Ready` is guaranteed to also observe the fully-initialized `head` pointer and the `FreeBlock` it points to.

---

### Extending the Heap

When the free list can't satisfy a request, we map additional memory:

```rust
unsafe fn extend(&self, min_size: usize) -> *mut FreeBlock {
    // Round up to at least DEFAULT_HEAP_SIZE and align to a page boundary.
    let size = align_up(cmp::max(min_size, DEFAULT_HEAP_SIZE), PAGE_SIZE);

    cfg_if::cfg_if! {
        if #[cfg(target_os = "linux", target_arch = "x86_64")] {
            let ptr = crate::util::functions::mmap(
                0, size,
                libc::PROT_WRITE | libc::PROT_READ,
                libc::MAP_PRIVATE | libc::MAP_ANON,
                -1, 0
            ).unwrap_or(null_mut());
        } else {
            compile_error!("Unsupported Target OS");
        }
    }

    if ptr.is_null() {
        return null_mut();
    }

    let block = ptr as *mut FreeBlock;
    unsafe {
        (*block).size = size;
        (*block).next = null_mut();
    }
    block
}
```

`align_up` rounds an address up to the nearest multiple of `align`, which must be a power of two:

```rust
#[inline]
pub(crate) fn align_up(addr: usize, align: usize) -> usize {
    let mask = align - 1;
    (addr + mask) & !mask
}
```

We ask for at least `DEFAULT_HEAP_SIZE` bytes even if the immediate request is smaller, to avoid making a syscall for every large allocation. The size is also rounded up to a page boundary since `mmap` requires it.

---

### Inserting Free Blocks and Coalescing

Free blocks are inserted in address order so that adjacent blocks can be merged. This is used both after `extend` and after `dealloc`.

![FreeNode reinsertion and coalescing](../../static/notes/phase0/Helios-Sci-FreeNode-Reinsert.svg)

The diagram shows three cases. The top layout is the free list before any reinsertion: two tracked free blocks separated by kernel-controlled unmanaged memory. The middle shows a block returned from a fresh `mmap` call being inserted, it extends the managed region but isn't adjacent to anything, so no merging happens. The bottom shows a block being returned after deallocation; it was carved out of a previously-free region and sits between two live allocations, so again no merge is possible. When a returned block *is* adjacent to its neighbours, the merge checks below handle it.

```rust
unsafe fn insert_free_block(&self, block: *mut FreeBlock) {
    let mut prev: *mut FreeBlock = null_mut();
    let mut curr = self.head.load(Ordering::Relaxed) as *mut FreeBlock;

    // Walk to the insertion point (first block at a higher address).
    while !curr.is_null() && (curr as usize) < (block as usize) {
        prev = curr;
        curr = unsafe { (*curr).next };
    }

    unsafe {
        (*block).next = curr;
        if prev.is_null() {
            self.head.store(block as usize, Ordering::Relaxed);
        } else {
            (*prev).next = block;
        }

        // Coalesce forward: merge with next block if adjacent.
        if !curr.is_null() && (block as usize + (*block).size == curr as usize) {
            (*block).size += (*curr).size;
            (*block).next = (*curr).next;
        }

        // Coalesce backward: merge with previous block if adjacent.
        if !prev.is_null() && (prev as usize + (*prev).size == block as usize) {
            (*prev).size += (*block).size;
            (*prev).next = (*block).next;
        }
    }
}
```

Coalescing is critical for long-term allocator health. Without it, repeated allocate/deallocate cycles fragment the heap into small unusable pieces that can never be recombined to satisfy larger requests.

---

### Allocation: First-Fit with Splitting

Before implementing allocation we define a small header stored immediately before each returned pointer. This lets `dealloc` recover the allocation size without relying on the caller's `Layout`, important because we may round up the allocation slightly, and we need to free exactly what we gave out:

```rust
struct AllocHeader {
    size: usize,
}

const MIN_FREE_BLOCK_SIZE: usize = mem::size_of::<FreeBlock>();
const ALLOC_HEADER_SIZE: usize  = mem::size_of::<AllocHeader>();
```

The layout of an allocated region looks like this:

```
[ Prefix (optional FreeBlock) | AllocHeader | Payload | Suffix (optional FreeBlock) ]
                              ↑             ↑
                          header_addr     returned ptr
```

![Heap allocation layout and splitting](../../static/notes/phase0/Helios-Sci-Heap-Insert.svg)

The diagram walks through a concrete example with `Layout.align = 16 bytes`. Starting from `block_start`, we call `align_up()` to find where the payload can land. The gap between `block_start` and `header_addr` is the **prefix**. If the prefix is non-zero but too small to hold a `FreeBlock` (less than `MIN_FREE_BLOCK_SIZE`), we bump the payload forward by one `align` increment and try again, you can see this in the middle panel of the diagram. The **suffix** is any leftover space after the payload. If it's also too small to hold a `FreeBlock`, we absorb it into the allocation rather than leave behind an unusable fragment.

```rust
unsafe fn alloc_from_list(&self, layout: Layout) -> *mut u8 {
    let size  = cmp::max(layout.size(),  1);
    let align = cmp::max(layout.align(), mem::align_of::<usize>());

    let mut prev: *mut FreeBlock = null_mut();
    let mut curr = self.head.load(Ordering::Relaxed) as *mut FreeBlock;
    let mut iterations: usize = 0;

    while !curr.is_null() {
        iterations += 1;
        if iterations > MAX_ITERATIONS {
            return null_mut();
        }

        let block_start = curr as usize;
        let block_size  = unsafe { (*curr).size };
        let next        = unsafe { (*curr).next };

        let mut payload     = align_up(block_start + ALLOC_HEADER_SIZE, align);
        let mut header_addr = payload - ALLOC_HEADER_SIZE;
        let mut prefix      = header_addr - block_start;

        // Ensure the prefix is either zero or large enough to be a valid FreeBlock.
        while prefix > 0 && prefix < MIN_FREE_BLOCK_SIZE {
            payload = match payload.checked_add(align) {
                Some(v) => v,
                None    => return null_mut(),
            };
            header_addr = payload - ALLOC_HEADER_SIZE;
            prefix      = header_addr - block_start;
        }

        let mut needed = match prefix
            .checked_add(ALLOC_HEADER_SIZE)
            .and_then(|v| v.checked_add(size))
        {
            Some(v) => v,
            None    => return null_mut(),
        };

        // Block too small, try the next one.
        if needed > block_size {
            prev = curr;
            curr = next;
            continue;
        }

        // Absorb a too-small suffix into the allocation.
        let mut suffix = block_size - needed;
        if suffix > 0 && suffix < MIN_FREE_BLOCK_SIZE {
            needed += suffix;
            suffix  = 0;
        }

        // Absorb a misaligned suffix as well.
        if suffix >= MIN_FREE_BLOCK_SIZE {
            let suffix_addr = block_start + needed;
            if !suffix_addr.is_multiple_of(mem::align_of::<FreeBlock>()) {
                needed += suffix;
                suffix  = 0;
            }
        }

        unsafe {
            if prefix >= MIN_FREE_BLOCK_SIZE {
                // Keep the prefix as a free block; optionally attach a suffix block.
                let prefix_block = curr;
                (*prefix_block).size = prefix;

                if suffix >= MIN_FREE_BLOCK_SIZE {
                    let suffix_block = (block_start + needed) as *mut FreeBlock;
                    (*suffix_block).size = suffix;
                    (*suffix_block).next = next;
                    (*prefix_block).next = suffix_block;
                } else {
                    (*prefix_block).next = next;
                }

                if prev.is_null() {
                    self.head.store(prefix_block as usize, Ordering::Relaxed);
                } else {
                    (*prev).next = prefix_block;
                }
            } else if suffix >= MIN_FREE_BLOCK_SIZE {
                // No prefix to keep; relink around the suffix block.
                let suffix_block = (block_start + needed) as *mut FreeBlock;
                (*suffix_block).size = suffix;
                (*suffix_block).next = next;

                if prev.is_null() {
                    self.head.store(suffix_block as usize, Ordering::Relaxed);
                } else {
                    (*prev).next = suffix_block;
                }
            } else if prev.is_null() {
                // Perfect fit at the head.
                self.head.store(next as usize, Ordering::Relaxed);
            } else {
                // Perfect fit mid-list.
                (*prev).next = next;
            }

            let alloc_size = needed - prefix;
            let header = header_addr as *mut AllocHeader;
            (*header).size = alloc_size;
            return payload as *mut u8;
        }
    }

    null_mut()
}
```

---

### `GlobalAlloc`: `alloc`

```rust
unsafe impl GlobalAlloc for FLAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if unsafe { self.init() }.is_err() {
            return null_mut();
        }

        let mut ptr = unsafe { self.alloc_from_list(layout) };

        if ptr.is_null() {
            // Compute the minimum extension size needed for this allocation.
            let min = match layout
                .size()
                .checked_add(ALLOC_HEADER_SIZE)
                .and_then(|v| v.checked_add(MIN_FREE_BLOCK_SIZE))
            {
                Some(v) => cmp::max(v, DEFAULT_HEAP_SIZE),
                None    => return null_mut(),
            };

            let block = unsafe { self.extend(min) };
            if !block.is_null() {
                unsafe { self.insert_free_block(block) };
                ptr = unsafe { self.alloc_from_list(layout) };
            }
        }

        ptr
    }
```

The flow is: initialize (no-op after first call) → search the free list → if that fails, extend the heap and retry.

---

### `GlobalAlloc`: `dealloc`

```rust
    unsafe fn dealloc(&self, ptr: *mut u8, _layout: Layout) {
        if ptr.is_null() {
            return;
        }
        if unsafe { self.init() }.is_err() {
            return;
        }

        unsafe {
            // Recover the allocation size from the header stored just before the pointer.
            let header = ptr.sub(ALLOC_HEADER_SIZE) as *mut AllocHeader;
            let size   = (*header).size;

            // Only return to the free list if the block is large enough to hold metadata.
            // Otherwise, accept it as a permanent fragment.
            if size >= MIN_FREE_BLOCK_SIZE {
                let block = header as *mut FreeBlock;
                (*block).size = size;
                (*block).next = null_mut();
                self.insert_free_block(block);
            }
        }
    }
}
```

We use the `AllocHeader` rather than the caller-supplied `Layout` because we may have given the caller a slightly larger block than requested (due to alignment rounding or suffix absorption), and we need to return the correct amount of memory to the free list.

---

## Full Source: `flalloc.rs`

See here: [flalloc.rs](../../../crates/helios-sci/src/mem/allocator/flalloc.rs)

---

## Using the Allocator

Register it as the global allocator with a single attribute:

```rust
use helios_sci::mem::allocator::FLAllocator;

#[global_allocator]
static ALLOCATOR: FLAllocator = FLAllocator::new();

fn main() {
    let x = Box::new(42);
    println!("Allocated a box with value: {}", x);
}
```

All `Box`, `Vec`, and other standard heap allocations will now flow through `FLAllocator`.

---

## Summary

We've implemented a free-list allocator bootstrapped from raw `mmap` syscalls, with lazy initialization, on-demand heap growth, address-ordered insertion, and adjacency coalescing. The design prioritizes simplicity and correctness over raw performance, which is the right call at this stage. The next post will use this as the foundation for an async runtime, and once that takes shape we'll have enough context to revisit allocator design. A [Two-Level Segregated Fit (TLSF) allocator](https://ricefields.me/2024/04/20/tlsf-allocator.html) is the likely destination, it's a significant step up in complexity but well worth understanding regardless (O(1) search and O(1) insertion), and the foundational knowledge from this walkthrough provides more than enough context to tackle it. When we get there, we'll also want to implement locking and thread-safety features, which are currently absent for the most part since our async runtime will be single-threaded for the foreseeable future.
