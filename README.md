# mover -- semantic versioning support in Lua

Lua library for semantic versioning (see  https://semver.org/)

## TL;DR

Semantic versioning is a system of rules for giving meaning to
versions: of much interest in this context would be for example, 
firmware image names. Semantic versioning splits up the version string
into components - some optional, others mandatory - that each have
particular significance. See the official website linked above FMI on
this.

In short, a semver string would look something along these lines:
`MAJOR.MINOR.PATCH-PREREL+BUILD_MD`, where MAJOR, MINOR, and PATCH
must be numeric and are mandatory, and PREREL and BUILD_MD are both
optional.

This repository provides a Lua library implementation that offers
semantic versioning support: the user can instantiate/create a semver
object, and optionally configure it in various ways (e.g. increment
any of the various incrementable fields, tag it with certain build
metadata or prerelease tags etc.)

## Interface / Usage

A description of the functions is provided in `./src/mover.lua`; each
function is also documented there to a substantial degree. With that
in mind, what follows is an overview of how the module may be used
from a user's perspective.

#### Require and Instantiation
```
    -- require this module
    local mover = require("mover")

    -- instantiate semver object; the prerelease and build metadata
    -- params are optional
    local semver = mover.semver(3,2,173, mover.RC, mover.DEV)

    -- otherwise, instantiate semver object from string
    local semver = mover.semver("3.2.173-rc.1+dev")

    -- otherwise, instantiate and initialize afterward from string
    local semver = mover.semver()
    semver:fromstring("3.2.173-alpha+debug.87")

    -- get a string representation of a semver object
    -- this is the same as 'tostring(semver)'
    local verstr = semver:get() -- '3.2.173-alpha+debug.87'
```

#### Pairwise comparison

Semantic versioning strings are pairwise comparable. You can compare
two semver objects:
```
    local a, b = semver.mover("1.1.10-alpha"), semver("1.1.10-beta")
    print(a > b)  -- false
    print(a == b) -- false
    print(b > a)  -- true
```
**NOTE** : build metadata (everything after '+') does _not_ feature in
comparisons.

#### Prerelease tags and Build Metadata

As shown above, there are various different ways of instantiating a
semver object. The user is free to provide build metadata in a string
or as an argument when instantiating a semver object. However,  this
is not recommended as it's less flexible than using the predefined
tagging methods offered.

The following points bear keeping in mind:
 * build metadata provided by the user at instantiation time will have
   any subsequent tags _concatenated with it_.
   For example:
```
    local semver = mover.semver(1,2,3,mover.RC, "some_build_metadata")
    semver:tag_with_build_number(31)
    print(semver) -- => '1.2.3-rc+some_build_metadata.31'
```
 * prerelease tags are replaced when the user provides a new one; i.e.
   you can't have more than one prerelease tag. However, a pre-release
   tag can be arbitrary (as long as it's valid), and can also contain 
   an arbitrary associated number that can be incremented.
   For example:
```
`   local semver = mover.semver(1,2,3, "random_prerelease_tag") 
    print(semver)                         -- => '1.2.3-random_prerelease_tag'
    semver:bump_prerel()                  -- => '1.2.3-random_prerelease_tag.1'
    semver:tag_with_prerel(mover.ALPHA)   -- => '1.2.3-alpha'
    semver:bump_prerel(11)                -- => '1.2.3-alpha.11'
```

Various methods are provided that tag the semver object with various
predefined strings. The user is highly encouraged to use these rather
than initiate/configure the object with random arbitrary strings.
Specifically, when the user instantiates from a (arbitrary) string
representing prelease or build metadata, the semver object will _not_
split/parse the input into e.g. timestamp, build number, prerelease number,
flavor, and so on. On the other hand, using the available methods for
tagging makes the semver object aware of these and this approach is
therefore more flexible.

The available methods are:
 * `tag_with_prerel(prerel_str)`   -- best use one of the available constants
 * `tag_with_flavor(flavor_str)`   -- ditto
 * `tag_with_timestamp()`          -- tags with UNIX epoch timestamp
 * `tag_with_build_number(n)`      -- uses n as a build number
 * `tag_with()`                    -- used for arbitrary build metadata

For `tag_with_prerel()`, it's recommended  the user make use of one of
the available constants: .RC, .ALPHA, .BETA.
Similarly, for `tag_with_flavour` the user should use one of the
following: .DEBUG, .TEST, .DEV.

`untag(build_meta_only)` can be used to _discard_ the existing
prerelease and build metadata tags. If `build_meta_only` is true,
_only_ the build metadata is dropped.

Aside from `tag_with_prerel()`, which creates a _prerelease_ tag, all
other functions create **build metadata** tags. This means anything
added by these will show up _after_ '+'.

#### Incrementing numbers

The major, minor, and patch components can all be incremented.
Whenever one of these components is incremented, all other components
to the right are set to 0. 
**NOTE** : If an argument is specified to any of the `bump` functions,
the current version is incremented by the amount specified via the
argument. Otherwise, 1 is implied.
```
    local s = mover.semver("3.2.17")
    s:bump_major()                   -- => '4.0.0'
    s:bump_major(3)                  -- => '7.0.0'
    s:bump_patch(17)                 -- => '7.0.17'
    s:bump_minor()                   -- => '7.1.0'
```

Additionally, there are two other components a user can employ:
 * prerelease number (added and incremented via `bump_prerel()`);
   NOTE: a prerelease tag must exist -- a prerelease tag 'number'
   cannot exist by itself without it.
 * build number (added and incremented via `bump_build_number()`)

These also observe the remark made earlier: if any component to the left
is incremented, everything to the right is set to 0.
```
    local s = mover.semver("3.2.17")
    s:tag_with_prerel(mover.RC)     -- => '3.2.17-rc'
    s:bump_prerel(3)                -- => '3.2.17-rc.3'
    s:bump_build_number(11)         -- => '3.2.17-rc.3+11'
    s:bump_prerel()                 -- => '3.2.17-rc.4'  -- a build number of 0 is not shown
    s:bump_build_number(11)         -- => '3.2.17-rc.4+11'
    s:bump_minor()                  -- => '3.3.17-rc'    -- a prerelease number of 0 is not shown either
```

## Tests

The tests are stored in `./tests` and can be run with `make tests`.

## License

This software is MIT-licensed; see `LICENSE` or run `make license`.
