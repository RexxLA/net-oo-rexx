call header "Collect The Rexx Parser"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(.SysCArgs[1])

call gitCollect -
    "https://github.com/JosepMariaBlasco/rexx-parser.git", -
    cache, -
    "rexx-parser"

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
