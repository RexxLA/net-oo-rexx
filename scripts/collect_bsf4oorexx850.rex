call header "Collect BSF4ooRexx850"

signal on syntax name error

use arg not_used -- only .SysCArgs is used
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(.SysCArgs[1])

call zipCollect -
    "https://sourceforge.net/projects/bsf4oorexx/files/GA/BSF4ooRexx-850.20240304-GA/BSF4ooRexx_install_v850-20260326-refresh.zip/download", -
    cache, -
    "BSF4ooRexx850"
cacheUpdated = result

if cacheUpdated then do
    -- To simplify delivery, remove some files and directories
    call moveToTrash cache"/BSF4ooRexx850/bsf4oorexx/utilities/OOo/addLinks2OOoSnippets.rxo", cache
    call moveToTrash cache"/BSF4ooRexx850/bsf4oorexx/utilities/ooRexxTry-rgf.rxj", cache
    call moveToTrash cache"/BSF4ooRexx850/bsf4oorexx/utilities/ooRexxTry-v1.rxj", cache
    call moveToTrash cache"/BSF4ooRexx850/bsf4oorexx/utilities/ooRexxTryFX", cache
end

call svnCollect -
    "https://svn.code.sf.net/p/bsf4oorexx/code/branches/850/bsf4oorexx.dev/source_cc", -
    cache, -
    "BSF4ooRexx850/bsf4oorexx.dev/source_cc"

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
