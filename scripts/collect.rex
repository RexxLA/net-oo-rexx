call header "Collect"

signal on syntax name error

parse source . how .
cache = .nil
if how \== "COMMAND" then use strict arg cache=.NIL
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

cache = setupCache(cache, .SysCArgs[1])

call "collect_bsf4oorexx850.rex" cache    ; if result \== 0 then exit result
call "collect_executor.rex" cache         ; if result \== 0 then exit result
call "collect_netrexx.rex" cache          ; if result \== 0 then exit result
call "collect_oorexx.rex" cache           ; if result \== 0 then exit result
call "collect_oorexxdebugger.rex" cache   ; if result \== 0 then exit result
call "collect_rexx-parser.rex" cache      ; if result \== 0 then exit result
call "collect_tutor.rex" cache            ; if result \== 0 then exit result

exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
