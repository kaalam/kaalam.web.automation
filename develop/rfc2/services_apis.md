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
object. Transactions have a common interface for both persistence `StoredTransaction` and memory `VolatileTransaction`.

2. Memory management is handled through custom allocation methods (malloc, block_malloc) that track allocated bytes and ensure
proper alignment.

3. Every `Block`, `Tuple` and `Kind` is created by one of the 8 forms of `new_block()` included in the parent class. This uses RAM from
the Container's memory pool. These methods allow for creating Tensors from raw data, filtering rows from other Tensors, selecting items
from Tuples, and more.

4. Resources inside a container are identified through a `Locator`. Locators have a string form (`///node//base/entity/key++`) that
is parsed into its components.

5. Containers provide a CRUD interface: (get, header, put, new_entity, remove, copy). These methods exist as a high-level interface (the
unparsed string form) and a locator-based interface (each component separately).

6. Code execution is done via exec() (normal function calls) or modify() (external call made to services via Channels). At the level of
jazz_elements, exec() is only declared but not implemented and modify() is used only in `Channels`.

7. The class also includes methods for locking and unlocking the container or entering and leaving read and write states
(enter_read, enter_write, leave_read, leave_write), which are essential for managing concurrent access to the container.
Also, two methods for transaction management (new_transaction, destroy_transaction).

8. All the string parsing for both locators and constants supported by the different new_block() methods is done by the `Container` class.

9. A method `base_names()` adds (keys and a pointer to itself) to a map passed by reference. This tells an API who manages what base. (A
base is the part of a Locator that identifies a functionality).

Overall, the Container class is a robust and flexible component designed to manage complex data structures and transactions, providing
a rich API for creating, modifying, and querying data while ensuring thread safety and efficient memory management.


## Container descendants in jazz_elements

```
Service -> Container -> Channels
               +------> Volatile
               +------> Persisted
```

There are three of them:

  * **Channels**: A Container doing block transactions across media (files, folders, shell, http urls and zeroMQ servers).
  * **Volatile**: A Container to manage data objects in RAM as a deque, an index (map), a priority queue or a tree.
  * **Persisted**: A Container to manage data objects in LMDB.


## Instantiation (and Uplifting)

  * **Uplifting** is the process of implementing a descendant of a class in another source tree --and possibly under a different
license-- while still instantiating it in a (customized) Jazz server. The source of the uplifts is located below the `uplifts`
folder in the Jazz source tree and will typically have its own version control repository. The `.config.sh` file applied to the
parent Jazz repository will create the appropriate makefile and headers to compile Jazz as if the uplifted classes were part of
the Jazz source tree. You can only uplift the `API` and the `ModelsAPI` classes. An uplifted `ModelsAPI` class will typically serve
customized `Model` descendants that inherit from the Jazz `Model` class. A customized `API` class will typically restrict the
access, making parts of it inaccessible, use credentials, tokens, etc. to make a Jazz server secure for internet access.

  * **Instantiation**: As mentioned, you will only have one instance of each service. Besides `HttpServer` (which does not require
special attention since customizing `API` is all you need to create commercial secure servers), every `Service` is a `Container`.
`BaseAPI` and `API` are containers since they need to at least momentarily allocate `Block` objects. Containers have a `base_names()`
mechanism to make `BaseAPI` descendants see where they are instantiated and call them.

  * **instances.h/instances.cpp  in jazz_main**: Is a little module that instantiates everything (callback functions, Services possibly
including uplifted ones) and provides a `start_service()`/`stop_service()` mechanism that logs and provides user feedback.


## Code execution (and BaseAPI)

```
Service -> Container -> BaseAPI -> Core  [Compiles and runs code]
```

Code is executed in the `Core` class. This class descends from `BaseAPI` which is a `Container`. `Core` implements the `exec()` method.
It inherits from `BaseAPI` which provides control over the containers in `jazz_elements`. Everything implemented under `jazz_bebop`:
`Space` (a common ancestor of `DataSpace` and `SemSpace`), `OpCodes` (the ONNX language), `Bop` (the compiler), `Snippet` (a `Concept`
ancestor that contains both the source and the object code) and the core (like a CPU-core, the onnx-runtime) is provided by a single
service: `Core`.

You can consider `Core` an `API` that is a wrapper over the onnx-runtime and defines the Bop language at compilable level.


## Models are a superior form of code execution

```
Service -> Container -> BaseAPI -> ModelsAPI  [serves Model descendants]
               +-----------------> Model      [uses Core to compile and run solutions]
```

At the level of `jazz_bebop`, we have a compiler that converts **formal** compilable Bebop code into **formal** object code. In this higher
level of abstraction (`jazz_models`) we convert **informal** natural language into **formal** compilable Bebop code. This requires a
`Model`. How a specific model works is beyond the scope of this document. As far as the Jazz server is concerned, a `Model` is just a
`Service->Container->BaseAPI` descendant with access to the `Core` to compile, run and evaluate solutions (formal representations to
the informal input). We can think of the whole model as a **resolver** vs. a **compiler** that is used in `Core`.

A `ModelsAPI` can be informally seen as a `Core` that executes a higher level language (natural language) that has to be resolved into
Bebop that can be compiled and executed by the `Core`. A single service serves multiple models using the same mechanism the other
containers have: a base (a part of a locator) identifies the model.


## API

```
Service -> Container -> BaseAPI -> API  [Single http entry point aware of all Containers]
```

So far we have seen:

  * [Lowest level] `Container` provides a language to define data as constants and move blocks around containers using locators.
  * [Level jazz_bebop] `BaseAPI` provides a language to access any container by base using locators, `Core` provides a language to abstract
data, tables and indexing and execute programs.
  * [Level jazz_models] `ModelsAPI` provides a mechanism to resolve natural language into Bebop code.
  * [Now] API Gives unrestricted access to everything to anyone.
  * [Highest level: Uplifted API]: Establishes access restrictions, credentials, tokens, etc.

The `API` class is a `Container` aware of every base in every other container, that routes requests to the appropriate container. The
`API` is called by the `http_request_callback()` callback function of the `HttpServer` class. Except for developing purposes it is
typically uplifted to provide security and access control. Note that without restrictions, the `API` can execute any code on the server
since it has access to the console via the `Chanel` container. The least harmful thing it can do is stop the server.
