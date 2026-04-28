call header "Release macOS"

signal on syntax name error

parse source . how .
cache = .nil; release = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, release=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [release]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
release = setupRelease(release, .SysCArgs[2])

bundle = "net-oo-rexx.macos.universal_64-portable-release-" || date("Standard")
bundle = .File~new(bundle, release)

-- mirrorDirC copies the directory contents (as opposed to mirrorDirD, which copies the directory itself)
call mirrorDirC cache"/oorexx-portable/macos.arm64.x86_64", bundle"/oorexx", /*recursive*/ .true, /*ignoreTopLevelDirectory*/ .true

call "deliver.rex" cache, bundle

call popd
call footer "Release done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
