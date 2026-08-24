# xWalk Firmware C++ Documentation Guidelines

## Scope and authority

Apply this standard to every C++ source and header in the complete `MyPiCarX`
workspace. It supplements `CODING_GUIDELINES.md`; both documents are mandatory.

- Project: xWalk Firmware
- Author: Joxy John
- Language: C++
- Domain: embedded systems and hardware abstraction
- Style: MISRA C++-oriented
- Documentation syntax: Doxygen-compatible

Documentation must remain technically accurate. Never claim formal MISRA
compliance unless a formal analysis has established it.

## Markdown documentation

Keep cross-module documentation in `devloper-note/xwalk-rpi5-note` and module-specific behavior
in the owning module README. Use this documentation layout:

```text
devloper-note/xwalk-rpi5-note/
    Doc/
        note/                Markdown documentation pages
        image/               Referenced hardware and project images
```

Keep Gerrit administration and CI documentation in `devloper-note/gerrit-note`.
The complete developer-note wiki is configured by `devloper-note/mkdocs.yml` and operated through
`xWalk-rpi5-tool/doc-tool/wiki.sh`. Keep generated Python environments and rendered HTML under the ignored
`build-devloper-note-wiki` directory. Do not commit generated site output. The local profile must bind to
loopback. The college-server profile may bind publicly only on an authorized host. The GitHub profile may build
a Pages artifact but must not push; publication follows the approved Gerrit integration synchronization flow.
During staging, convert links from developer-note pages to tracked files outside `devloper-note` into GitHub
source links for the deployed integration revision. Preserve checkout-relative links in the source Markdown.
Gerrit and GitHub CI must run `xWalk-rpi5-tool/doc-tool/wiki.sh verify` to validate wiki-owned and repository-owned
links, strictly build the generated Pages artifact, and inspect it before publication.

Documentation must:

- keep mirrored Markdown in `devloper-note/xwalk-rpi5-note/Doc/note` and copied images in
  `devloper-note/xwalk-rpi5-note/Doc/image`;
- omit CMake files, make files, generated build directories, binaries, and
  rendered output from `devloper-note/xwalk-rpi5-note/Doc`;
- maintain `devloper-note/xwalk-rpi5-note/index.md` as the C++ architecture and module reference index;
- name Markdown files under `devloper-note/xwalk-rpi5-note/Doc/note` with readable title-case words
  separated by spaces;
  preserve established uppercase acronyms such as `API`, `GPIO`, `I2C`, `MCU`, `PWM`, and `TTS`;
- provide one `.md` page for every upstream documentation-source `.rst` page;
- discard language-specific installation, imports, scripts, and API examples;
- copy reusable hardware and project images into `devloper-note/xwalk-rpi5-note/Doc/image` and
  reference them from the corresponding Markdown page;
- omit installation, application, and language-specific screenshots, replacing
  each one with a descriptive heading and a `TODO:` placeholder;

- use GitHub-flavored Markdown without Sphinx or reStructuredText directives;
- keep every physical line at or below 115 characters except complete shell commands in fenced code blocks;
- link to module READMEs instead of duplicating complete public contracts;
- describe current C++ behavior directly and retain only relevant hardware concepts;
- state hardware revision, units, ranges, ownership, and safety constraints;
- in `.md` files only, keep each fenced shell command on one physical line
  without continuation backslashes, allowing the complete command to exceed
  115 characters when necessary;
- use `ctest -N -L hardware` for ordinary hardware-test discovery;
- keep page content synchronized with current C++ headers and module READMEs;
- preserve upstream source and license attribution for adapted documentation.

Do not copy generated HTML, Sphinx templates, translation catalogs, community
advertising blocks, or unresolved substitution tokens into `devloper-note/xwalk-rpi5-note/Doc`.

## File headers

Every `.cpp`, `.hpp`, and `.h` file starts with this header. Use the real file
name, a responsibility-focused brief and details, the owning module name, and
the date on which the file is created or receives its first project header.

Generated sources under an `auto-gen` tree retain the generator's identifying
header and are exempt from the handwritten project-header and Doxygen rules.
Never edit generated output merely to make it resemble handwritten project
code; update its source schema or generator instead.

```cpp
/******************************************************************************
 * @file        <file_name>
 * @brief       <short description>
 *
 * @details
 * <detailed description of the file responsibility>
 *
 * @project     xWalk Firmware
 * @module      <module name>
 *
 * @author      Joxy John
 * @date        <YYYY-MM-DD>
 * @version     1.0.0
 *
 * @copyright
 * Copyright (c) 2026 Joxy John.
 * All rights reserved.
 *
 * @note
 * Developed using MISRA C++ coding guidelines.
 ******************************************************************************/
```

Do not overwrite an existing copyright or license. Preserve it and integrate
the Doxygen header around it when necessary. Do not change the header date for
routine edits after the documentation header has been established.

## File sections

Separate meaningful file regions with this form:

```cpp
/******************************************************************************
 * Includes
 ******************************************************************************/
```

Do not add empty sections. Header-file sections use this preferred order when
present:

1. Includes
2. Forward declarations
3. Namespace declarations
4. Constants
5. Type definitions
6. Enumeration declarations
7. Structure declarations
8. Class declarations
9. Inline function definitions

Source-file sections use this preferred order when present:

1. Includes
2. Anonymous namespace
3. Global constants
4. Static global variables
5. Global pointer variables
6. Private function declarations
7. Private function definitions
8. Namespace definitions
9. Constructor definitions
10. Destructor definitions
11. Public member function definitions
12. Protected member function definitions
13. Private member function definitions

Test-specific section names such as `Test function definitions` and necessary
C++ sections such as `Global function definitions` are permitted when they
describe the code more accurately.

## Namespace documentation

Document every named namespace before its declaration:

```cpp
/**
 * @namespace xwalk::hal
 * @brief Contains hardware abstraction components for the xWalk firmware.
 */
namespace xwalk::hal
{
```

Document anonymous namespaces without inventing a name:

```cpp
/**
 * @brief Contains declarations and definitions private to this translation unit.
 */
namespace
{
```

Use explicit closing comments:

```cpp
} /* namespace xwalk::hal */
} /* namespace */
```

## Classes and class sections

Every class has a responsibility-focused Doxygen block. Explain what it owns,
what it observes, which hardware abstraction it provides, and important lifetime
or concurrency behavior. Do not merely restate its name.

Inside each class, add only the sections that contain declarations:

```cpp
/**************************************************************************
 * Public constructors and destructor
 **************************************************************************/

/**************************************************************************
 * Public member functions
 **************************************************************************/

/**************************************************************************
 * Protected member functions
 **************************************************************************/

/**************************************************************************
 * Private data members
 **************************************************************************/
```

Additional accurate groups such as `Public special member functions` are
allowed. Place every non-public member function in a protected section and use
private sections only for data members. Never retain or create an empty access
or documentation section.

## Functions

Fully document public APIs in headers. Document every non-trivial function,
constructor, destructor, static function, free function, callback, and member
function. Every member-function definition in a `.cpp` file must also have a
complete Doxygen contract. Keep its parameters, directions, units, ranges,
returns, exceptions, preconditions, postconditions, ownership, and side effects
consistent with the declaration. Add implementation-specific details only when
they explain behavior that is not evident from the public contract.

Use only fields that add information:

```cpp
/**
 * @brief <short responsibility>
 *
 * @details
 * <optional non-obvious behavior>
 *
 * @param[in] inputName
 * <meaning, unit, and valid range>
 *
 * @param[out] outputName
 * <meaning after the call>
 *
 * @param[in,out] stateName
 * <input expectation and resulting mutation>
 *
 * @return
 * <meaning of every return value>
 *
 * @pre
 * <enforced or required precondition>
 *
 * @post
 * <observable postcondition>
 *
 * @note
 * <important implementation or compatibility information>
 *
 * @warning
 * <hardware, lifetime, or safety risk>
 */
```

- Use `@param[in]`, `@param[out]`, or `@param[in,out]` for every parameter.
- State units such as Hertz, bytes, timer counts, volts, milliseconds, or
  percent.
- State valid ranges when the implementation defines or checks them.
- Describe all return outcomes; never add `@return` to a `void` function.
- Document constructor inputs and actual initialization effects.
- Describe only real destructor behavior. Do not invent resource release.
- Do not add empty `@details`, `@pre`, `@post`, `@note`, or `@warning` fields.
- Keep declarations and definitions consistent after every behavior change.
- Do not replace a `.cpp` member-function contract with a brief-only reference
  to its header declaration.

## Types, structures, enumerations, and aliases

Document the responsibility of every enumeration and structure. Document
enumerators and structure members when their value or unit matters. Document
every type alias and function-pointer alias.

For C++ protocol-mirrored enums and payload structures, give every enumerator
and data member a preceding multi-line Doxygen block matching the
function-contract form. Include `@brief` and add non-empty `@details` when
ranges, wire types, presence, ownership, units, or value semantics need
explanation. Do not use a trailing `/**< ... */` comment or single-line
`/** @brief ... */` comment for these C++ protocol declarations.

For Protocol Buffer schemas, keep a multi-line Doxygen block immediately above
every message, enum, and service declaration. Include a concise `@brief` and
use `@details` for useful protocol behavior or known C++ relationships. Put the
documentation for every message field, enum value, and RPC declaration after
its semicolon as a same-line `//@@` comment. Do not use a Doxygen block for
those schema members.

Callback alias documentation states parameter direction, context ownership and
lifetime, valid ranges, side effects, and return-value meaning. A `void*`
context is non-owning unless implementation evidence proves otherwise.

## Constants and macros

Place project constants in a `Constants` section and explain their purpose,
unit, valid range, and hardware relationship where applicable. Place
function-like macros in a clearly named section and document side effects and
unsafe preconditions, especially context casts.

Prefer translation-unit constants in an anonymous namespace. Do not change
linkage or behavior solely for documentation. Never add a comment that merely
expands the identifier into words.

## Global state and pointers

Place translation-unit state in `Static global variables` and prefer an
anonymous namespace over file-scope `static` for new code. For each variable,
document:

- purpose and valid range;
- lifetime and mutation behavior;
- thread, task, and interrupt-safety considerations.

Place global pointers in `Global pointer variables`. Document:

- pointee and ownership;
- whether null is permitted;
- expected lifetime and initializer;
- whether the pointer can change;
- volatile hardware-register behavior and validation requirements.

Do not use vague labels such as "pointer variable."

## Class data and pointer ownership

Document members whenever purpose, ownership, unit, range, synchronization, or
state meaning is not self-evident. Every pointer and reference member explicitly
states whether it is owning or non-owning, whether null is allowed, and which
object must outlive which. Use accurate terms such as owning pointer,
non-owning pointer, nullable pointer, observer pointer, or hardware-register
pointer. Never infer ownership without implementation evidence.

Project-class dependencies are accepted as constructor references and stored as
non-owning pointers. Document that these pointers are non-null after successful
construction, are never released by the consumer, and must remain valid for the
consumer's lifetime. Document the composition root that creates dependencies
before consumers whenever the file contains that wiring.

## Local comments

Use local comments for reasons and constraints: hardware protocol behavior,
safety decisions, formulas, compatibility requirements, workarounds, byte
order, and non-obvious logic. Do not narrate an obvious statement, branch, or
increment. Keep comments synchronized with code changes.

## MISRA C++-oriented documentation rules

Documentation work must not:

- change functional behavior;
- remove an existing `static_cast` or introduce a C-style cast;
- introduce dynamic allocation or a raw owning pointer;
- add unused declarations or empty sections;
- suppress a compiler or analysis warning;
- rename an existing identifier unless explicitly requested;
- claim formal MISRA compliance without a formal analysis;
- replace `nullptr` with `NULL` or integer zero.

Continue using existing fixed-width project types backed by `<cstdint>`.
Preserve formatting conventions unless they conflict with this standard.

## Review checklist

Before completing any C++ change, verify all of the following:

1. Every new `.cpp`, `.hpp`, and `.h` file has the project header.
2. The author is exactly `Joxy John`.
3. File and class sections are relevant and non-empty.
4. Named and anonymous namespaces are documented and closed with comments.
5. Public API declarations carry complete, consistent Doxygen documentation.
6. Every `.cpp` member-function definition has a complete Doxygen contract that
   agrees with its declaration.
7. Parameter direction, units, ranges, returns, exceptions, side effects, and
   hardware dependencies are accurate where applicable.
8. Every pointer or reference comment states ownership and lifetime without
   guessing.
9. Aliases, callbacks, structures, enumerations, constants, and meaningful data
   members are documented.
10. No empty Doxygen fields, contradictory explanations, or code-narrating comments
   remain.
11. Comments still match the implementation after tests and build checks.
12. The handoff identifies conservative documentation choices, unsafe global
    state or pointers, and observed MISRA-oriented concerns.
13. The handoff confirms whether functional behavior was intentionally changed.
