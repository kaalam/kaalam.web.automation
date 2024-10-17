# Jazz Services, APIs and instantiation

Jazz is a single monolithic process. It allocates data and code (which is data) through some classes that only have one instance of each.
This document describes the logic behind it.


## Services

In Jazz, all the classes that define data and metadata neither have a configuration nor do they allocate RAM. They also don't have a
logger to write to.

These classes are:

```
StaticBlockHeader -> Block -> Tuple
                       +----> Kind
```

All the classes that do have configuration, a logger and can allocate memory are inherited from the `Service` class. While you will
typically instantiate many objects of data and metadata classes, you will only have one instance of each service.


A Service is constructed by passing a ConfigFile (a key-value store that reads a file and exposes it as keys to the Service) and
a Logger (Which exposes a variadic log_printf() function and automatically annotates time, level and thread info) to the Service
descendant constructor.

Services are always inherited.

Services, ConfigFiles and Loggers are all defined in jazz_elements::utils.

Services also have a start() and shut_down() methods, typically run only once when the server starts and closes.


## Containers

```
Service -> Container
   +-----> HttpServer
```

1. Some `Container` descendant owns every `Block`, `Kind` and `Tuple` instances in Jazz (no exceptions). It wraps them in a `Transaction`
object. Transactions have a common interface for both persitence `StoredTransaction` and memory `VolatileTransaction`.

2. Memory management is handled through custom allocation methods (malloc, block_malloc) that track allocated bytes and ensure
proper alignment.

3. Every `Block`, `Tuple` and `Kind` is created by one of the 8 forms of `new_block()` included in the parent class. This uses RAM from
the Container's memory pool. These methods allow for creating Tensors from raw data, filtering rows from other Tensors, selecting items
from Tuples, and more.

4. Resources inside a container are identified through a `Locator`. Locators have a string form (`///node//base/entity/key++`) that
is parsed into its components.

5. Containers provide a CRUD interface: (get, header, put, new_entity, remove, copy). These methods exist as a high-level interface (the
unparsed string form) and a locator-based interface (each component separately).

6. Code execution is done via exec() (normal function calls) or modify() (external call made to services via Channels).

7. The class also includes methods for locking and unlocking the container or entering and leaving read and write states
(enter_read, enter_write, leave_read, leave_write), which are essential for managing concurrent access to the container.
Also, two methods for transaction management (new_transaction, destroy_transaction).

8. All the string parsing for both locators and constants supported by the different new_block() methods is done by the `Container` class.

9. A method `base_names()` adds (keys and a pointer to itself) to a map passed by reference. This tell an API who manages what base. (A
base is the part of a Locator that identifies a functionality).

Overall, the Container class is a robust and flexible component designed to manage complex data structures and transactions, providing
a rich API for creating, modifying, and querying data while ensuring thread safety and efficient memory management.


## Container descendants in jazz_elements

There are three of them:

  * **Channels**: A Container doing block transactions across media (files, folders, shell, http urls and zeroMQ servers).
  * **Volatile**: A Container to manage data objects in RAM as a deque, an index (map), a priority queue or a tree.
  * **Persisted**: A Container to manage data objects in LMDB.


## Code execution

TODO: A mechanism to separate API from HttpAPI is required!!

  * TBD


## Communicating with a model

  * TBD


## API

  * TBD


## Instantiation (and Uplifting)

  * TBD
