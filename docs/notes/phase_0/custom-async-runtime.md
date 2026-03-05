# Custom Async Runtime

Before I can start building the Helios daemon ([helid](https://github.com/mhambre/helid)) in userspace on Linux as a proof-of-concept, I need an HTTP server to back it so it can act as a control plane that [helictl](https://github.com/mhambre/helictl) can interact with. Unfortunately, as with many aspects of this project, we can't just reach for an HTTP library like [axum](https://github.com/tokio-rs/axum). This is because we'd lose visibility into the OS-specific operations happening under the hood. So we're building our own crate, [helios-http](https://github.com/mhambre/helios-http), to give us full control over those operations and make it possible to eventually migrate to the [helios-core](http://github.com/mhambre/helios-core) kernel down the line.

To keep that future migration as painless as possible, we're not allowing any `std` usage in userspace libraries. Instead, we're building a syscall interface as an abstraction layer between userspace and both our kernel and Linux's. For networking, we're scaffolding an API similar to `std::net::{TcpListener, TcpStream, SocketAddr}`, where the Helios implementation is [cfg-gated](https://doc.rust-lang.org/rust-by-example/attribute/cfg.html) and the Linux implementation wraps `std::net`, converting errors to our own types. You can see those changes in this [commit](https://github.com/mhambre/helios-sci/commit/e743fd91fb6aa96caa09a8d747e32a1ebc72a4b0).

Networking is the minimum we need for a working HTTP server, but since we want to support multiple clients talking to the daemon at once, we also need some form of concurrency or parallelism. That's where things get interesting because surprisingly we can implement a large portion of it to be OS-agnostic.

**Concurrency vs. Parallelism**

Concurrency is about maximizing how much useful work a CPU core does by interleaving multiple tasks. Parallelism is about literally running multiple tasks at the same time across multiple cores. Concurrency is typically achieved through threading or async programming; parallelism through multi-core execution (multiprocessing).

We're starting with concurrency and skipping parallelism for now, once you go parallel you have to start thinking about load balancing and IPC, which are both way down the road for our operating system.

**Threads vs. Async**

In multithreading, the kernel gives each function a time slice, saves state when the slice is up, and hands control to the next one. Functions interleave their execution until they all complete, with no single function blocking the others.

In async programming, instead of the kernel managing time slices, the programmer marks points explicitly where control can be handed away and a runtime handles scheduling. The `await` keyword is how you tell the runtime "this might take a while and the CPU isn't the bottleneck here (e.g. I/O, network), go do something else in the meantime."

For `helios-http`, we're going with async. It gives us the concurrency we need to support simultaneous uploads and downloads, and it leaves the door open to layer threading or multiprocessing on top later if we need it.

**Futures in Rust**

Since the 2018 edition Rust has shipped with the [async](https://doc.rust-lang.org/std/keyword.async.html) keyword, along withthe `core::Future` trait. This being apart of the core means that they can be executed without an operating system! Unfortunately, that's only part of the story. If we tried to use these as it stands, nothing would happen, and the reason behind that comes down to the fundamentals of what a `Future` is (Promise in JavaScript, Coroutine in Python, etc.).

Earlier I stated that asynchronous programming was interesting because rather than the kernel doing most of the work, pretty much all of the management happens in userspace under the control of an executor (tokio/smol in Rust, asyncio in Python). The executor essentially keeps track of which task is running, and when that task yields control, choosing the next task to continue working on.

That means that we just need to figure out how to make an executor and we are able to take advantage of async programming. First, lets go over briefly what a `Future` looks like in Rust and what the `async` keyword really means.

```rust
pub trait Future {
    type Output;

    // Required method
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}

pub enum Poll<T> {
    Ready(T),
    Pending,
}
```

This is the trait definition of a Future, essentially the interface into how an executor is able to know if an asynchronous function is working (`Pending`), and when the function finishes, what was returned (`Ready(T)`). When we chain these functions in the call stack we produce a state machine. Take this snippet for example:

```rust
async fn file_size_printer(filename: &str) {
    let file: Result<Path> = download_file(filename).await;

    let Ok(path) = &file_path else {
        eprintln!("File not downloaded!");
        return
    }

    let contents = read_file(path).await;
    println!("File length: {}", contents.len());
}
```

In the diagram you can see that when `download_file()` is run we use `await` to yield control back to the executor since we can't control the speed of a download on the CPU. The executor will hand control to other tasks in the meantime and occasionally when it's deciding who to give control back to it'll call `poll()` on our `download_file()` Future. When that Future finally is `Ready` meaning we have the data to continue (in this case if we got a path back we can read the file, if not we just print the error) the execution flow. Assuming the file was downloaded properly we then call `read_file()` which is also IO bound so we yield control again. In a blocking workflow where async programming isn't used this entire time spent including the time downloading and reading the file is wasted because even though our program isn't executing any instructions during majority of that time, our process can't do any other work until it's done. Based on this logic you can think of an executor as follows:

```python
tasks = [future1, future2, future3]

while True:
    if tasks.empty():
        park_thread()

    task = tasks.pop()
    task.future.poll(task.context)

    # Not ready yet
    if result == Pending:
        continue
    elif result == Ready:
        destroy_task(task)
```

TO BE CONTINUED

- https://doc.rust-lang.org/book/ch17-00-async-await.html
- https://doc.rust-lang.org/core/future/trait.Future.html
- https://man7.org/linux/man-pages/man7/epoll.7.html

[[Index]](./index.md)
