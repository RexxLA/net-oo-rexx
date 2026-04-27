signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument(s) expected: [cache]"

cache = setupCache(.SysCArgs[1])

call "collect_bsf4oorexx850.rex"    ; if result \== 0 then exit result
call "collect_executor.rex"         ; if result \== 0 then exit result
call "collect_netrexx.rex"          ; if result \== 0 then exit result
call "collect_oorexx.rex"           ; if result \== 0 then exit result
call "collect_oorexxdebugger.rex"   ; if result \== 0 then exit result
call "collect_rexx-parser.rex"      ; if result \== 0 then exit result
call "collect_tutor.rex"            ; if result \== 0 then exit result

exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
