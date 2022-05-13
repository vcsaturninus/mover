#!/usr/bin/lua5.3

local mover = require("mover")

local total_run = 0     -- total number of tests run
local total_failed = 0  -- total number of tests failed

function test_valid(verstr, valid, expected)
    assert(verstr, "missing 'verstr' argument to 'test_valid()'")
    mover._say(string.format("[ ] validating '%s'", tostring(verstr)))
 
    total_run = total_run + 1

    local res, t = mover._validate(verstr)
    local complaint = string.format("\t\t--> FAILED ('%s').\n\t\t\t|Parsed (%s):   major='%s', minor='%s', patch='%s', prerel='%s', build_meta='%s'",
            tostring(verstr),
            res and "valid" or "invalid",
            tostring(t.major),
            tostring(t.minor),
            tostring(t.patch),
            tostring(t.prerel),
            tostring(t.build_meta)
            )

    local comparand = string.format("\t\t\t|Expected (%s): major='%s', minor='%s', patch='%s', prerel='%s', build_meta='%s'",
            valid and "valid" or "invalid",
            tostring(expected.major),
            tostring(expected.minor),
            tostring(expected.patch),
            tostring(expected.prerel),
            tostring(expected.build_meta)
            )
    if valid ~= res then
        mover._say(complaint)
        mover._say(comparand)
        total_failed = total_failed+1
        return false
    end

    if expected.major ~= t.major or
        expected.minor ~= t.minor or
        expected.patch ~= t.patch or
        expected.prerel ~= t.prerel or
        expected.build_meta ~= t.build_meta then

        mover._say(complaint)
        mover._say(comparand)
        total_failed =  total_failed+1
        return false
    end

    mover._say("\t\t--> OK (%s)", valid and 'valid' or 'invalid')
end

function test_compare(a, b, expected)
    mover._say(string.format("[ ] Comparing '%s' and '%s'", tostring(a), tostring(b)))
    
    total_run =  total_run + 1

    local res = mover.compare(a,b)
    if res == expected then
        mover._say("\t\t--> OK (%s)", expected)
    else
        mover._say("\t\t\t|Expected %s, got %s", expected, res)
        total_failed =  total_failed+1
    end

end

-- b must be a semver string NOT semver instance
function test_equal(a, b, expected)
    mover._say(string.format("[ ] Checking for equality: '%s' and '%s'", tostring(a), tostring(b)))
 
    total_run =  total_run + 1

    local res = tostring(a) == b
    if res == expected then
        mover._say("\t\t--> OK (%s)", expected)
    else
        mover._say("\t\t\t|Expected %s, got %s", expected, res)
        total_failed =  total_failed+1
    end

end



--========================================================================================
-- Test that semantic version strings are recognized as valid or invalid, as appropriate
--========================================================================================
--
print("-- -- -- Testing valid and invalid strings ... \n")

-- all components, including optional ones
test_valid("3.2.56-rc.1+34892948-2f-1.1.10", true, {major=3, minor=2, patch=56, prerel='rc.1', build_meta='34892948-2f-1.1.10'})

-- no release stage
test_valid("3.2.56+34892948-2f-1.1.10", true, {major=3, minor=2, patch=56, build_meta='34892948-2f-1.1.10'})

-- no build metadata
test_valid("3.2.56-rc.1", true, {major=3, minor=2, patch=56, prerel='rc.1'})

-- no build metadata and no release stage
test_valid("3.2.56", true, {major=3, minor=2, patch=56})

-- invalid: extra dot-separated sequence before release stage / build metadata; should fail parsing release stage
test_valid("3.2.56.81-whatever", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- invalid: extra dot-separated sequence before release stage / build metadata;
-- should fail parsing both release stage and build metadata
test_valid("3.2.56.81-whatever+82334", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- invalid build metadata, containing multiple +s, valid release stage string
test_valid("3.2.56-whatever+82334+first+second.1.1+third", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- no string after '-' : invalid
test_valid("3.2.56-", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- no string after '+' : invalid
test_valid("3.2.56-rc.1+", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- no string after either '-' or '+'
test_valid("3.2.56-+", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- '-' followed by + means empty release stage tag
test_valid("3.2.56-+34892948", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})

-- '-' followed by '.'
test_valid("3.2.56-.+34892948-2f-1.1.10", false, {major=3, minor=2, patch=56, prerel=nil, build_meta=nil})


--========================================================================================
-- Test that comparison between semver objects works as expected
--========================================================================================
--
print("\n -- -- -- Testing semver pairwise comparison ... \n")
test_compare(mover.semver("3.1.5"), mover.semver("3.1.5"), 0)
test_compare(mover.semver("3.1.4"), mover.semver("3.1.5"), -1)
test_compare(mover.semver("3.1.6"), mover.semver("3.1.5"), 1)
test_compare(mover.semver("3.11.1"), mover.semver("3.7.100"), 1)
test_compare(mover.semver("0.1.1"), mover.semver("0.0.1"), 1)
test_compare(mover.semver("11.11.11"), mover.semver("11.11.11-rc"), 1)
test_compare(mover.semver("0.1.312-rc.1-debug.2"), mover.semver("0.1.312-rc.1-debug.2"), 0)
test_compare(mover.semver("0.1.312-rc.1-debug.2"), mover.semver("0.1.312-rc.1-debug"), 1)
test_compare(mover.semver("0.1.312-rc.1-debug.2"), mover.semver("0.1.312-rc.1-debug.2.2"), -1)
test_compare(mover.semver("0.1.312-rc.1-debug.2"), mover.semver("0.1.312-rc.1-debug.2.3"), -1)
test_compare(mover.semver("0.1.312-rc.1-debug.2"), mover.semver("0.1.312-rc.1-debug.3"), -1)
test_compare(mover.semver("4.1.75-dev"), mover.semver("4.1.75"), -1)
test_compare(mover.semver("4.1.75-dev"), mover.semver("4.1.75-debug"), 1)
test_compare(mover.semver("4.1.75-rc.111"), mover.semver("4.1.75-rc.beta"), -1)  -- numbers < alpha chars
test_compare(mover.semver("4.1.77"), mover.semver("4.1.77+metadata"), 0)  -- build metadata should be discounted


--========================================================================================
-- Test that semver objects can be built up as expected
--========================================================================================
--
print("\n -- -- -- Testing semver object creation and configuration ... \n")
local instance = mover.semver("4.1.1")
test_compare(instance, mover.semver("4.1.1"), 0)

instance:tag_with_prerel("alpha")
test_compare(instance, mover.semver("4.1.1-alpha"), 0)

instance:bump_prerel()
test_compare(instance, mover.semver("4.1.1-alpha.1"), 0)

instance:bump_prerel()
test_compare(instance, mover.semver("4.1.1-alpha.2"), 0)

instance:bump_prerel(173)
test_compare(instance, mover.semver("4.1.1-alpha.175"), 0)

instance:tag_with_prerel("rc")
test_compare(instance, mover.semver("4.1.1-rc"), 0)

instance:bump_prerel(7)
test_compare(instance, mover.semver("4.1.1-rc.7"), 0)

instance:tag_with_flavor(mover.DEV)
-- build meta tags do not figure in the comparison
test_compare(instance, mover.semver("4.1.1-rc.7"), 0)


instance:bump_build_number(711)
instance:bump_build_number(4)
instance:bump_major(3)
instance:bump_minor(2)
instance:bump_patch(33)
test_compare(instance, mover.semver("7.2.33-rc+not.compared"), 0)

instance:untag()
test_compare(instance, mover.semver("7.2.33"), 0)

--==============================================================================
-- factor in build metadata as well: test that the whole
-- stringified semver object matches what's expected
--==============================================================================
local instance = mover.semver(3,7,363,'beta','test')
test_equal(instance, "3.7.363-beta+test", true)

instance:bump_minor()
test_equal(instance, "3.8.0-beta+test", true)

instance:bump_patch(1)
instance:bump_patch(3)
instance:bump_patch(90)
instance:bump_patch(1)
test_equal(instance, "3.8.95-beta+test", true)

instance:bump_major()
test_equal(instance, "4.0.0-beta+test", true)

instance:bump_major(11)
test_equal(instance, "15.0.0-beta+test", true)

instance:tag_with_flavor(mover.DEV)
test_equal(instance, "15.0.0-beta+test-dev", true)

instance:untag(true)
instance:tag_with_flavor(mover.DEV)
test_equal(instance, "15.0.0-beta+dev", true)

instance:bump_build_number(17)
instance:bump_build_number(2)
instance:bump_prerel(3)
test_equal(instance, "15.0.0-beta.3+dev", true)

instance:tag_with("random_build_metadata.1.2-random")
instance:tag_with_flavor(mover.TEST)
instance:tag_with_prerel(mover.ALPHA)
instance:bump_build_number(1)
instance:bump_prerel(3)
instance:bump_major()
instance:bump_minor(3)
test_equal(instance, "16.3.0-alpha+random_build_metadata.1.2-random-test", true)

instance:bump_prerel(7)
instance:bump_build_number(17)
test_equal(instance, "16.3.0-alpha.7+random_build_metadata.1.2-random-test.17", true)

instance:untag(true)
test_equal(instance, "16.3.0-alpha.7", true)

instance:untag()
test_equal(instance, "16.3.0", true)

--------- test invalid combinations
instance = mover.semver(1, 2, 2, 'rc.2', 'development')
test_equal(instance, "1.2.2-rc.2+development", true)

instance:bump_prerel()
test_equal(instance, "1.2.2-rc.2.1+development", true)

instance:bump_patch()
test_equal(instance, "1.2.3-rc.2+development", true)

print(string.format(
[[========================================
:::: FAILED: %s of %s
==========================================]], total_failed, total_run))
if total_failed > 1 then os.exit(11) end  -- exit with error code
