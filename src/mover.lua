#!/usr/bin/env lua

--[[
-----------------------------------------------------------
-- Lua semantic version library -- 
-- (c) 2022 saturninus <vcsaturninus@protonmail.com> --
-----------------------------------------------------------

This library offers an implementation of semantic versioning as set out here: https://semver.org/.
The current implementation complies with semver version 2.

At a high level, this module lets users create a semver object. Various methods are offered that lets
users:
 * populate the object with various semver-compatible strings, as needed, in a blob fashion
 * pairwise-compare two semver objects
 * conveniently tag the object with various predefined tags (flavor, timestamp, etc)
 * increment numbers for major, minor, patch, prerelease (optional) and build (optional)

-- -- -- Contents -- -- -- 

 -- _Functions --
 * semver()                 -- create new semver instance/object
 * .get()                   -- return string representation of semver instance; same as tostring(<semver instance>)
 * .tag_with()              -- tag with arbitrary (but vaid) semver build metadata
 * .tag_with_flavor()       -- tag with build flavor string -- see _Constants_
 * .tag_with_prerel()       -- tag with prerelease stage string -- see _Constants_
 * .tag_with_timestamp()    -- tag with UNIX epoch timestamp
 * .tag_with_build_number() -- tag with build number 
 * .bump_major()            -- bump major number
 * .bump_minor()            -- bump minor number
 * .bump_patch()            -- bump patch number
 * .bump_prerel()           -- bump prerelease stage number (assume 0 if not set)
 * .bump_build_number()     -- bump build_number (assume 0 if not set)
 * .untag()                 -- remove prerelease tag and all build metadata; i.e. strip down to MAJOR.MINOR.PATCH
 -- Functions_ --
--

 -- _Constants --
 * .DEBUG     -- debug flavor
 * .TEST      -- test flavor
 * .DEV       -- development (dev) flavor
 * .RC        -- release candidate (rc) prerelease stage
 * .BETA      -- beta prerelease stage
 * .ALPHA     -- alpha prerelease stage
 -- Constants_ -- 

 -- _Requires -- 
 -- Requires_ --

-- -- -- Contents_ -- -- -- 
--]]

local M = {}

M._VERSION = 2
M._DESCRIPTION = "Lua library implementation for semantic versioning."
M._LICENSE = [[
Copyright (c) 2022 saturninus <vcsaturninus@protonmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
-- flavors
M.DEBUG = 'debug'
M.TEST = 'test'
M.DEV = 'dev'

-- prerelease stage
M.RC = 'rc'
M.BETA = 'beta'
M.ALPHA = 'alpha'

--[[
    Print message to standard output; 
    ... must be one or more arguments as would be passed directly to string.format().
    The final message formatted by string.format() will be newline terminated if
    not already.
--]]
function M._say(...)
    io.output = stdout
    local msg = string.format(...)
    if msg:sub(#msg, #msg) ~= "\n" then
        msg = msg .. "\n"
    end
    io.write(msg)
end

--[[
    Same as _say() but the message is ONLY printed if either .DEBUG_MODE 
    or the DEBUG_MODE evironment variables are set.
--]]
function M._complain(...)
    if M.DEBUG_MODE or os.getenv("DEBUG_MODE") then
        M._say(...)
    end
end

--[[
    Same as _complain(). Simply an alias to it to avoid the negative connotation.
--]]
function M._inform(...)
    M._complain(...)
end

--[[
    Split str on sep. Used here to split the prerelease substring
    and the build metadata into dot-separated substrings.

<-- return
    table of str substrings split on '.'
--]]
function M.split(str, sep)
    local res = {}
    if not str then return res end

    for k in string.gmatch(str, string.format("[^%s]+", sep)) do
        table.insert(res, k)
    end

    return res
end

--[[
    Compare two semver objects : a and b.

<-- returnA
    The return value is the same as libc's strcmp().
    -1 if a<b
    0 if a==b
    1 if a>b
--]]
function M.compare(a,b)
    if a < b then return -1 end
    if a == b then return 0 end
    if a > b then return 1 end
end

--[[
    Parse and validate release stage and build metadata substrings.

    If either the prerelease substring or the build metadata are invalid
    both of them are invalidated and false is returned. True is returned if
    BOTH are valid.

    A valid prerelease substring:
    - must start with '-'
    - must have one or more '.' separated fields; each field may have multiple
    '-' separated subfields.
    - must NOT have empty fields or subfields 

    A valid build metadata is the same as a valid prerelease substring, but it
    must start with '+', and this character must ONLY feature ONCE.

    All other characters in both the build metadata and the prerelease must 
    be alphanumerics.

<-- return
    A 2-tuple of (<prerelease>, <build metadata>) if BOTH are valid.
    A 2-tuple of (nil,nil) if EITHER is invalid.
--]]
local function parse_extra(ext)
    local prerel, build_meta
    -- ext can only start with one of two possible characters:
    -- a) '-' for the release stage
    -- b) '+' for build metadata (meaning the optional prerelease stage has been ommitted)
    if ext and (ext:sub(1,1) == '-' or ext:sub(1,1) == '+') then
        prerel = ext:match("^%-([%d%a%-%.]+)")
        build_meta = ext:match("%+([%d%a%-%.]+)$")
    else  -- invalid string; invalidaate both release stage and build metadata
        if ext then 
            M._complain("! '%s' must start with one of '+' or '-'.", ext)
        end
        return nil, nil
    end

    -- 1) there must only be one single '+' anywhere: used to separate the build metadata
    -- off from the rest of the version string
    if ext and select(2, ext:gsub("%+", '')) > 1 then
        return nil, nil  -- possibly valid rel, invalid meta; invalidate both
    end

    -- if string ends in a '-', '.'  or '+', invalidate
    local last = ext:sub(#ext, #ext)
    if last == '.' or last == '-' or last == '+' then
        M._complain("! last character in '%s' is '%s', which is invalid.", ext, last)
        return nil,nil
    end
    last = nil

    -- it's illegal to have any of +, -, and . following each other
    if ext:match("%.%-") or
        ext:match("%.%+") or
        ext:match("%+%-") or
        ext:match("%+%.") or
        ext:match("%-%+") or
        ext:match("%-%.") then
            M._complain("! separators do not separate anything: '%s' is invalid.", ext)
            return nil,nil
        end

    -- likewise if one of them is duplicated with both instances immediately after each other
    if ext:match("%.%.") or
        ext:match("%+%+") or
        ext:match("%-%-") then
            M._complain("! repeated separator(s) in '%s' : invalid.", ext)
            return nil,nil
    end

    return prerel, build_meta
end

--[[
    Validate and parse semver string VERSTR.

<-- return
    a 2-tuple of (BOOL, TAB) where:
     - BOOL is false if verstr is invalid, else true.
     - TAB is a table with major, minor, patch, prerel, build_meta 
     fields. If BOOL is false, nil is returned instead of TAB.

    NOTE:
    major, minor, and patch are returned as NUMBERS. prerel and build_meta
    otoh are strings. Additionally, the latter two are always optional while
    the former 3 are mandatory in any valid semver string.
--]]
function M._validate(verstr)
    local is_valid = true

    if not verstr then 
        M._complain(verstr, "\nmissing semantic version string\n") 
        return false 
    end

    local major, minor, patch, ext, prerel, build_meta

    major, minor, patch, ext = verstr:match("(%d+)%.(%d+)%.(%d+)(.*)")
    if ext == "" then ext=nil end

    if not major or not minor or not patch then  -- mandatory
        M._complain("\ninvalid semantic version string: " .. verstr .. "\n")
        return false
    end

    prerel, build_meta = parse_extra(ext)
    if ext and (not prerel and not build_meta) then
        is_valid = false -- release stage tag and/or build metadata invalid
    end

    return is_valid, {
                  major=tonumber(major),          -- major number
                  minor=tonumber(minor),          -- minor number
                  patch=tonumber(patch),          -- patch number
                  prerel=prerel,                  -- [optional] release stage: alpha, beta, release-candiate (rc) etc
                  build_meta=build_meta           -- [optional] build metadata: timestamp, build number etc
              }
end

-- semver class
local semver = {}
semver.__index = semver

-- used to make semver CALLABLE (see __mt:__call())
local __mt = {}
setmetatable(semver, __mt)
    
--[[
    Create new semver object instance.
    __call will make semver callable which in turn makes instance-creation 
    more fluid.
    
--> PARAMS
    1)
    major, minor, and patch must be numbers and are always mandatory in any
    valid semver string. However, all params can be left unspecified (see 2) ).
    prerel and build_meta are both optional and they must start with '-' and
    '+', respectively. prerel and build_meta both can contain alphanumberics
    but are subject to certain rules for the semver string to be valid: see
    parse_extra().

    2)
    IF major if a string, it's instead assumed to be a complete semver string:
    all other parameters are ignored and major is parsed as a semver string and the 
    semver instance is initialized from it. This is equivalent to calling semver()
    WITHOUT any arguments and  then initializing it from a semver string with
    :from_string().
--]]
function __mt:__call(major, minor, patch, prerel, build_meta)
    local new = {}
    setmetatable(new, semver)

    -- mandatory
    new.major, new.minor, new.patch = nil, nil, nil

    -- optional 
    new.prerel, new.build_meta = nil, nil

    -- extra, part of build_meta
    new.flavor =  nil
    new.build_number = nil
    new.timestamp = nil

    -- initialize from separate params
    if type(major) == "number"  then
        new.major = tonumber(major) or 0
        new.minor = tonumber(minor) or 0
        new.patch = tonumber(patch) or 0
        
        new.prerel = prerel
        new.build_meta = build_meta

    -- initialize from string; major must be a valid semver string
    elseif type(major) == "string" then
        local verstr = major -- first param is actually a semver string
        local ok, res =  M._validate(verstr)
        assert(ok, string.format("! Failed to initialize from string. Invalid: '%s'", verstr))
        new.major, new.minor, new.patch, new.prerel, new.build_meta = res.major, res.minor, res.patch, res.prerel, res.build_meta
    end

    return new
end

--[[
    Provide string representation of semver instance, as used by print() and
    tostring(). Also see :get().

    The string representation of a semver string returned by this module is
    MAJOR.MINOR.PATCH-PREREL+TIMESTAMP-FLAVOR.BUILD_NUMBER, where
     - MAJOR.MINOR.PATCH are the core of the semver string and are all mandatory
     - PREREL is an alphanumeric sequence of characters. Multiple fields can be part
       of this and must be '.' separated (and subfields must be '-' separated) if they
       exist.
     - Everything after '+' represents build metadata. The format here is the same as in
       in the prerelease substring. Unlike the prerelease substring, build metadata is NOT
       USED in pairwise comparison.

    The fields shown in the build metadata above represent this module's more opinionated approach:
    multiple methods are offered for including certain predefined 'tags' such as timestamp,
    build number, flavor, and so on (of course, a user is free to provide an arbitrary 
    string instead and initialize a semver instance from it).
    Additionally, the prerelease stage tag can also have an associated number that can be 
    'bumped'. See the overview at the top of the file or search for 'bump' and 'tag_with'
    for relevant methods in this file.

    It's HIGHLY recommended the user make use of the methods provided to employ predefined
    tags: these are then easily modified and operated on. Converesely, if the 
    user instead initialized a semver instance from an arbitrary string, the module will make
    no effort to parse e.g. the build metadata into separate fields such as timestamp, build 
    number, flavor, and so on. Instead, any subsequent tag will simply be appended to it !
--]]
function semver.__tostring(self)
    local repr = string.format("%s.%s.%s", self.major, self.minor, self.patch)

    local build_meta = self.build_meta

    if self.timestamp then 
        build_meta = string.format("%s%s%s", 
                                   build_meta or '', 
                                   build_meta and '.' or '',
                                   self.timestamp) 
    end

    if self.flavor then
        build_meta = string.format("%s%s%s", 
                                    build_meta or '',
                                    build_meta and '-' or '',
                                    self.flavor) 
    end

    if self.build_number then
        build_meta = string.format("%s%s%s",
                                   build_meta or '',
                                   build_meta and '.' or '',
                                   self.build_number)
    end

    if self.prerel then repr = repr .. "-" .. self.prerel end
    if build_meta then repr = repr .. "+" .. build_meta end
    return repr
end

--[[
    True if self == b, else false. 
    Note: build meta does NOT figure in comparisons.

    This function simply employs calls to the __lt metamethod instead, 
    which does the heavy lifting.
--]]
function semver.__eq(self, b)
    if self < b or self > b then
        return false
    end

    return true
end

--[[
    Pairwise compare self and b, two semver instances.
    Return true if self < b else false.

    Notes on semver comparisons:
    * major, minor, and patch are always compared as integers
    * build metadata is discounted in comparisons
    * prerelease strings are split into separate fields based on '.'.
      Fields containing only numeric characters are compared as ints, 
      fields containing alphanumerics are compared as strings.
    * tag-less semver strings > semver strings with prerelease tag
    * numeric chars < alphabetic chars
    * all else being equal, strings with a longer prerelease tag (more fields)
      > strings with a shorter prerelease tag.
    * all else being equal, a longer allphanumeric prerelease field > a shorter
      such field.
    
    FMI see the official semver website linked at the top of this file.
--]]
function semver.__lt(self, b)
    if self.major < b.major then
        return true
    elseif self.major > b.major then
        return false
    end

    if self.minor < b.minor then
        return true
    elseif self.minor > b.minor then
        return false
    end

    if self.patch < b.patch then
        return true
    elseif self.patch > b.patch then
        return false
    end
    
    -- parse prerelease tag
    -- string with prerelease tag < string without 
    if self.prerel and not b.prerel then
        return true
    elseif not self.prerel and b.prerel then
        return false
    end

    local a_tokens = M.split(self.prerel, "%.") 
    local b_tokens = M.split(b.prerel, "%.")

    for idx,tkn in pairs(a_tokens) do
        -- if b has run out of tokens, it means everything up to here
        -- has been equal; after that whichever string has fewer tokens (in this case
        -- b) is the smaller of the two
        if tkn and not b_tokens[idx] then
            return false
        end

        local a_tkn = tonumber(tkn) or tkn
        local b_tkn = tonumber(b_tokens[idx]) or b_tokens[idx]
        
        M._inform("comparing '%s' and '%s'", a_tkn, b_tkn)

        -- numbers < alphabetic chars
        if type(a_tkn) == "number" and type(b_tkn) == "string" then
            return true
        elseif type(b_tkn) == "number" and type(a_tkn) == "string" then
            return false
        end

        -- else, both strings or both numbers
        -- LUA correctly compares numeric chars as < alphabetic chars i.e.
        -- '3' < 'a'
        if a_tkn < b_tkn then 
            return true
        elseif b_tkn < a_tkn then
            return false
        end
    end

    -- if we've reached here, then all tokens have been equal
    -- fall back  to comparing the number of tokens
    -- strings with MORE tokens/fields are > than strings with fewer tokens/fields
    if #a_tokens > #b_tokens then
        M._inform("'%s' != '%s' - different number of tokens in prerelease tag (%s and %s, respectively)", self, b, #a_tokens, #b_tokens)
        return false -- one semver string has more fields in its prerelease tag
    elseif #a_tokens < #b_tokens then
        return true
    end

    return false -- probably equal (else we would've returned false higher up this function)
end

--[[
    Return string representation of self semver instance. 
    Same as tostring() (this function simply proxies the call to it.)
--]]
function semver.get(self)
    return tostring(self)
end

--[[
    Initialize from string. If self is an already-initialized semver instance,
    any fields are OVERWRITTEN, i.e. the instance is RE-initialized.
    FMI, see __mt:__call()
--]]
function semver.fromstring(self, verstr)
    local res,t = M._validate(verstr)
    if not res then M._complain("! Failed to initialize from string : '%s' (invalid)", verstr) end
    assert(t.major, "invalid semver string without major version") -- validate returns nil if invalid
    
    self:untag() -- drop all tags if any exist, and reinitialize
    self.major = t.major
    self.minor = t.minor
    self.patch = t.patch
    self.prerel = t.prerel
    self.build_meta = t.build_meta
end

--[[
    Bump major number up by 1, or by how_many if specified.
    This resets minor and patch both to 0.
--]]
function semver.bump_major(self, how_many)
    self.major = self.major + (how_many and how_many or 1)
    self.minor = 0
    self.patch = 0
end

--[[
    Bump minor number up by 1, or by how_many if specified.
    This resets patch to 0.
--]]
function semver.bump_minor(self, how_many)
    self.minor = self.minor + (how_many and how_many or 1)
    self.patch = 0
end

--[[
    Bump patch number up by 1, or by how_many if specified.
--]]
function semver.bump_patch(self, how_many)
    self.patch = self.patch + (how_many and how_many or 1)
end

--[[
    Bump prerel number up by 1, or by how_many if specified.
    NOTE: if prerel does NOT have an associated number, 0 is assumed
    and a new '.' separated field is added.
    I.e. given 3.1.7-rc, :bump_prerel(7) will generate 3.1.7-rc.7.

    The semver instance MUST HAVE a prerelease tag already set!
--]]
function semver.bump_prerel(self, how_many)
    local prerel = self.prerel
    assert(prerel, "Cannot bump unset release-stage tag")
    local num = tonumber(prerel:match(".(%d+)"))
    prerel = self.prerel:match("(%a+)")
    
    local how_many = how_many and how_many or 1
    self.prerel = string.format("%s.%s", prerel, num and num+how_many or how_many)
end

--[[
    Bump build number up by 1, or by how_many if specified.
    NOTE: if self does NOT already have a build number, 0 is assumed
    and a new '.' separated field is added.
    I.e. given 3.1.7, :bump_build_number(7) will generate 3.1.7+7 and
         given 3.1.7+debug, :bump_build_number(7) will generate 3.1.7+debug.7
--]]
function semver.bump_build_number(self, how_many)
    self.build_number = tonumber(self.build_number) or 0 + (how_many or 1)
end

--[[
    Create a UNIX epoch timestamp tag as part of the build metadata.

    NOTE: this overwrites any previous timestamp tag!
--]]
function semver.tag_with_timestamp(self)
    self.timestamp = os.time()
end

--[[
    Add tag as a prerelease tag. See parse_extra() fmi on the expected format
    for a valid semver string.
    It's recommended the caller use one of .RC, .BETA, .ALPHA (see _Constants
    at the top of this file).

    NOTE: this overwrites any previous prerelease tag!
--]]
function semver.tag_with_prerel(self, tag)
    self.prerel = tag:match("^[%d%a%.%-]+$")
    if not M._validate(tostring(self)) then
        error("invalid prerelease tag '%s'", tag)
    end
end

--[[
    Add flavor as a build metadata tag. 
    It's recommended the caller use one of .DEBUG, .DEV, .TEST (see _Constants
    at the top of this file).

    NOTE: this overwrites any previous flavor tag!
--]]
function semver.tag_with_flavor(self, flavor)
    local flav = flavor:match("^[%a]+$")
    assert(flav, string.format("invalid flavor tag : '%s'", flavor))
    self.flavor = flav
end

--[[
    Add number as a build number (part of the build metadata). 

    NOTE: this overwrites any previous build_number tag!
--]]
function semver.tag_with_build_number(self, number)
    if not number or type(number) ~= "number" then
        error("invalid argument to tag_with_build_number() : '%s' - must be a number", number)
    end
    self.build_number = number
end

--[[
    Add arbitrary (but valid) build metadata. 

    NOTE: this overwrites any previous 'bulk' metadata i.e.
    self.build_meta (self.timestamp, self.flavor etc are PRESERVED:
    if those need to be discarded, call self:untag() first).
--]]
function semver.tag_with(self, build_metadata)
    self.build_meta = build_metadata
    if not M._validate(tostring(self)) then
        error("invalid build metadata tag '%s'", tag)
    end
end

--[[
    Remove all tags such that we're only left with major, minor, and patch.
    If build_meta_only is true, then ONLY the build metadata fields are unset:
    i.e. the prerelease string is left intact.
--]]
function semver.untag(self, build_meta_only)
    self.build_meta = nil
    self.timestamp = nil
    self.flavor = nil
    self.build_number = nil
    
    if not build_meta_only then
        self.prerel = nil
    end
end


M.semver = semver
return M

