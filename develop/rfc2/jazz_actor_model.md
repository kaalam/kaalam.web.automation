# Jazz Actor model

Jazz is a single monolithic process that runs multithreaded. This mandatory guide is the specification on how that is implemented.

## Processes, threads, fibers

There is only one process, the server. No actor model is implemented at process level.

Jazz does not use fibers since fibers would not solve the fundamental problem, exploiting the 64 cores in a CPU at the minimum
cost in terms of cache misses, etc. The mix of threads and fibers would be even worse. We need threads and cannot replace them by
anything else.

Threads are created in a pool by libmicrohttpd and each API call runs in a thread. The only mechanism to "parallelize" computation to
more threads is starting more API calls. Anyway as complexity grows (from elements to bop to agents) this scaling happens automatically.
Jazz is not prioritizing being a "backend tensor workhorse" anymore and does not provide mechanisms to multithread a single backend
computation.

## The actor model

Is implemented at thread level.

It is **almost** canonical, the only exception is how some things are possibly shared (see shared resources below).

### The canonical parts

  - There is nothing in control, nothing schedules. The processing of messages to completion does everything.
  - An actor is whatever runs to handle an API call up to completion.
  - The (almost) only state is the state inside the actors. (Shared resources being the only exception to this.)
  - All messages are one-way. The answer may trigger more messages.
  - Actors execute just one message always to completion, concurrently and asynchronously. They **never** wait for an answer.

## Shared resources

And, therefore, the only place where thread control happens ... are the **Container** objects. And this is done using only two mechanisms

  - The methods enter_read(), enter_write(), leave_read() and leave_write() inherited from the Container class.
  - The internal LMDB mechanisms (in the case of the Persisted container).

Otherwise, **nothing** is shared between actors outside a Container.

### Physical safety of shared resources

By physical safety, we mean avoiding catastrophic interactions (including but not limited to, crashes, locking, data corruption). This
is avoided by the logic in the Container objects. Anything possibly compromising this physical safety is a bug.

### Logical safety of shared resources

This is about racing conditions in reading, writing or deleting shared resources.

For agents implementing higher level algorithms, this may be crucial and require some higher level access logic to be implemented.

It is not a "Jazz-level" decision to do so. Platform-wise Jazz actors will just use shared resources regardless of any other actors. It's
the Jungle!

This will be prevented when the resources are not really shared because their names include unique handles known by their owners and nobody
"spies" at this stage to create problems. These "owners" will have some housekeeping logic to do to prevent wasting resources.

This part will surely change in the future moving towards ironclad security.
