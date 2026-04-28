call header "Collect NetRexx"

signal on syntax name error

parse source . how .
cache = .nil
if how \== "COMMAND" then use strict arg cache=.NIL
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(cache, .SysCArgs[1])

call zipCollect -
    "https://www.netrexx.org/files/NetRexx-5.10-GA.zip", -
    cache, -
    "netrexx"

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
