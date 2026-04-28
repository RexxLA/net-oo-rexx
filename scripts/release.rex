call header "Release"

signal on syntax name error

parse source . how .
cache = .nil; release = .nil
if how \== "COMMAND" then use strict arg cache=.NIL, release=.NIL
call assert .SysCArgs~items <= 2, 93.900, "0..2 argument(s) expected: [cache [release]]"

call pushd
cache = setupCache(cache, .SysCArgs[1], /*okToCreate:*/.false)
release = setupRelease(release, .SysCArgs[2])

call "release_macos.rex" cache, release    ; if result \== 0 then exit result
call "release_ubuntu.rex" cache, release   ; if result \== 0 then exit result
call "release_windows.rex" cache, release  ; if result \== 0 then exit result

call popd
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
