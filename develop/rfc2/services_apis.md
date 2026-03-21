# Jazz Services, APIs and Instantiation

> Last updated: 2026-03-21: Applies to Jazz 1.26.x

Jazz is a single monolithic process. It allocates data and code (which is data) through some classes that only have one instance of each.
This document describes the logic behind it.


## Services

In Jazz, all the classes that define data and metadata neither have a configuration nor do they allocate RAM. They also don't have a
logger to write to.

These classes are:

```
StaticBlockHeader -> Block -> Tuple -> Snippet -> Space -> Concept
                       |                            +----> DataSpace -> SemSpace
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
object. Transactions have a common interface for both persistence `StoredTransaction` and memory `VolatileTransaction`. This continues to
be true beyond `jazz_elements`, the `Snippet`, `Space`, `Concept`, `DataSpace` and `SemSpace` objects are just `Tuple` descendants
and created by some `Container` (`Core` for `Snippet`, `Bebop` for `Space`, and `ModelsAPI` for `Concept`, `DataSpace` and `SemSpace`).

2. Memory management is handled through custom allocation methods (malloc, block_malloc) that track allocated bytes and ensure
proper alignment.

3. Every `Block`, `Tuple` and `Kind` is created by one of the 8 forms of `new_block()` included in the parent class. This uses RAM from
the Container's memory pool. These methods allow for creating Tensors from raw data, filtering rows from other Tensors, selecting items
from Tuples, and more. Beyond `jazz_elements`, the Core, the Compiler or the Model create their own and the classes have constructors
that simplify its creation.

4. Resources inside a container are identified through a `Locator`. Locators have a string form (`///node//base/entity/key++`) that
is parsed into its components.

5. Containers provide a CRUD interface: (get, header, put, new_entity, remove, copy). These methods exist as a high-level interface (the
unparsed string form) and a locator-based interface (each component separately).

6. Code execution is done via exec() (normal function calls) or modify() (external call made to services via Channels). At the level of
jazz_elements, exec() is only declared but not implemented and modify() is used only in `Channels`. Code executed via exec() corresponds
to the API apply codes predicates APPLY_ASSIGN_FUNCTION and APPLY_ASSIGN_FUNCT_CONST. It is the most basic functionality that is later
extended in BaseAPI and its descendants. Beyond `jazz_elements`, `exec()` is connected to the calling mechanism of a `Snippet`, inherited
all the descendants and managed by `BaseAPI` descendant which is a `Container`.

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
the Jazz source tree. You can only uplift the `API`, the `ModelsAPI` and the `Bebop` classes. An uplifted `Bebop` is a compiler
that fundamentally converts the `src` of a `Space` into `asm` of its `Snippet`parent. An uplifted `ModelsAPI` class will
typically serve customized `Model` descendants that fundamentally converts `pain` of a `Concept` into the `src` of its `Space`
parent. A customized `API` class will typically restrict the access, making parts of it inaccessible, use credentials, tokens, etc.
to make a Jazz server secure for enterprise use.

  * **Instantiation**: As mentioned, you will only have one instance of each service. `BaseAPI` and therefore `API` are containers since
they need to at least momentarily allocate `Block` objects. Containers have a `base_names()` mechanism to make `BaseAPI` descendants see
where they are instantiated and call them.

  * **instances.h/instances.cpp  in jazz_main**: Is a little module that instantiates everything (callback functions, Services possibly
including uplifted ones) and provides a `start_service()`/`stop_service()` mechanism that logs and provides user feedback.


### How Services are instantiated

The Jazz server instantiates services, one instance of each, following these rules:

  * Services that are common ancestors (Service, Container, BaseAPI, Model) are not instantiated. Only their descendants are.
  * Core, Bebop and ModelsAPI via the BaseAPI interface use everything in jazz_elements the lower level of each other.

```
  Globals:    Used by:                     Uplifted:
  --------    --------                     ---------
  Channel     Core, Bebop, ModelsAPI, API  No
  Volatile    Core, Bebop, ModelsAPI, API  No
  Persisted   Core, Bebop, ModelsAPI, API  No
  Core        Bebop, ModelsAPI, API        No
  Bebop       ModelsAPI, API               Possibly
  ModelsAPI   API                          Possibly
  API         HttpServer                   Possibly
  HttpServer  -- the outside world --      No
```


## Execution: BaseAPI, OpCodes Core

```
Service ----------> OpCodes          [ONNX language]
   +-> Container -> BaseAPI          [Manages petitions to Containers]
                      +----> Core    [Manages sessions, runs code and serves]
Block ------------> Tuple -> Snippet [Code snippet, parent of Space]
```


### The namespace `jazz_core` has:

  * `BaseAPI`: A container that routes requests to other containers
  * `OpCodes`: The ONNX language definition. A Service to use configuration and log mechanisms.
  * `Snippet`: A tuple containing: obj (the onnx object), links (how data is possibly stored) and asm (a source in onnx opcodes).
  * `Core`: (as in a CPU-core) A BaseAPI that manages sessions to run snippets with an interface similar to the other containers.

`Core` is the only object instantiated by the server's instantiation mechanism.
`Core` implements the `exec()` method. It inherits from `BaseAPI` which provides control over the containers in `jazz_elements`.


### The BaseAPI class

`BaseAPI` handles everything that is neither http specific or requires code execution. It provides an interface that is on one side
http oriented:

  * header() Allows checking metadata without memory allocation. Similar to a http HEAD request.
  * get() Supports the entire querying language (which is a subset of Bop) and returns Tensors. Similar to a http GET request.
  * put() Writes a tensor inside a container. Similar to a http PUT request.
  * remove() Deletes a tensor inside a container. Similar to a http DELETE request.

And on the other side defines a subset of Bop that provides control over the containers.

The subset of Bop that handles queries is defined by the use of the `apply` property in an ApiQueryState structure. There are 23 codes
ranging from APPLY_NOTHING to APPLY_JAZZ_INFO. See `jazz_elements::channel.h`.

Code execution is done by the BaseAPI descendants (Core, Bebop and ModelsAPI).


## Compilation: Space, NameSpace, Bebop

```
Service
   +-> Container -> BaseAPI         [Manages petitions to Containers]
                      +----> Bebop  [Compiles, runs using a Core and serves]
Block -> Tuple -> Snippet -> Space  [A hierarchical code element, parent of Concept]
```

### The namespace `jazz_bebop` has:

  * `Space`: Extends Snippet with:
    - A parent defining a hierarchical structure
    - An address (a locator)
    - A kind
    - Casting mechanisms across kinds
    - operators: is (=), get (<-), key (.), inside ({..}), within ([..]), call ((..)) and after (|>)
    - properties: keys (a dictionary to children and settings), src (the source code)
  * `NameSpace` A cpp stdlib container-based to make it more efficient to the compiler.
  * `Bebop`: The compiler/runner with access to `Core` to run.


## Resolution: Concept, DataSpace, SemSpace, Model, ModelsAPI

```
Service ----------> Model                                 [Abstract class that defines models]
   |                  +----> MyModel                      [Models are always uplifted]
   +-> Container -> BaseAPI                               [Manages petitions to Containers]
                      +----> ModelsAPI                    [Serves, resolves, compiles and runs]
Block -> Tuple -> Snippet -> Space -> Concept             [A code element with resolution]
                               +   -> DataSpace           [A Space to organize data]
                                         +-----> SemSpace [A Space to organize Concepts]
```

### The namespace `jazz_models` has:


  * `Concept`: A `Space` with resolution capabilities. It extends `Space` with:
    - operators: resolve (<<-), clue (?) and under (|:)
    - properties: plain (the origin), image (the result of applying a lens), game (the tree searched by a model)
    - A mechanism to call virtual methods in models.
  * `DataSpace`: A `Space` to organize data. It extends `Space` with:
    - operators: within ([..]) and key (.) are redefined to provide access specific blocks of data.
    - properties: grid (the metadata to locate data in a Jazz cluster).
  * `SemSpace`: A `DataSpace` to organize concepts. It extends `DataSpace` with:
    - operators: resolve (<<-), clue (?) and under (|:) at SemSpace level and can be overridden in a Concept.
    - properties: self (a context accessible to the Model).
  * `Model`: An abstract class that defines a model. It is a Service the can have config, RAM allocation and logging. It can implement
virtual methods such a HNSW (Hierarchical Navigable Small World) or vector representations of Concepts, that become accessible to the
Concepts providing such things as lensing typically done using the under operator (an image under a lens).
  * `ModelsAPI`: A `BaseAPI` descendant that serves one or multiple `Model` descendants implemented in an uplift.


### The two flavors of Bebop

You can consider Bebop (Bop) a language with two "flavors": a **formal** one that can be compiled and is defined by everything in this
namespace and an **informal** natural language that is converted into compilable code by a `Model` in `jazz_models`.

At the level of `jazz_bebop`, we have a compiler that converts **formal** compilable Bebop code into **formal** object code. In this higher
level of abstraction (`jazz_models`) we convert **informal** natural language into **formal** compilable Bebop code. This requires a
`Model`.


## API as a BaseAPI descendant

```
Service -> Container -> BaseAPI -> API  [Single http entry point aware of all Containers]
```

  * [**IMPORTANT**] API Gives **unrestricted access** to **everything** to **anyone**.
  * [Highest level: **Uplifted API**]: Establishes access restrictions, credentials, tokens, etc.


### The API class

The `API` class is a `BaseAPI` aware of every other `BaseAPI` descendant. As a `BaseAPI` itself it manages: Channels, Volatile and
Persisted. It routes its http put() and delete() methods to its parent and its get() method to either its parent, Core, Bebop or ModelAPI.
`API` is called by the `http_request_callback()` callback function of the `HttpServer` class. Except for developing purposes it is
typically uplifted to provide security and access control. Note that without restrictions, the `API` can execute any code on the server
since it has access to the console via the `Chanel` container. The least harmful thing it can do is stop the server. This functionality
can also be disabled via configuration, but uplifting provides total control over the server, not just disabling features.


## jazz_main: The server itself

The `jazz_main` namespace, beyond the `API` class, includes the server instantiation, starting, stopping, etc. The mechanisms to customize
the server are: uplifting, configuration and providing a static website (html, js, css) that the server will serve by default. You will
typically not want to modify the server itself. In that case, the source code itself is the reference.
