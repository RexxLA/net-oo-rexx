call header "Collect ooRexx"

signal on syntax name error

parse source . how .
cache = .nil
if how \== "COMMAND" then use strict arg cache=.NIL
call assert .SysCArgs~items <= 1, 93.900, "0..1 argument expected: [cache]"

call pushd
cache = setupCache(cache, .SysCArgs[1])

call svnCollect -
    "https://svn.code.sf.net/p/oorexx/code-0/incubator/regex", -
    cache, -
    "oorexx/incubator/regex"

call svnCollect -
    "https://svn.code.sf.net/p/oorexx/code-0/test/trunk", -
    cache, -
    "oorexx/test/trunk"

portableZIPs = getLatestOORexxPortableZIPs("https://sourceforge.net/projects/oorexx/files/oorexx/5.3.0beta/portable")
do platform over -
        "macos.arm64.x86_64", -
        "ubuntu2404.x86_64", -
        "windows.x86_64"
    call zipCollect -
        getOORexxPortableZIP(portableZIPs, platform), -
        cache, -
        "oorexx-portable/"platform

    -- These files are redundant, already available in net-oo-rexx/source
    directory = cache"/oorexx-portable/"platform
    subdirectory = getUniqueSubdirectory(directory) -- the ZIP file has a root directory impossible to guess
    call moveToTrash directory"/"subdirectory"/readme.txt", cache
    call moveToTrash directory"/"subdirectory"/setupoorexx.cmd", cache
    call moveToTrash directory"/"subdirectory"/setupoorexx.rex", cache
    call moveToTrash directory"/"subdirectory"/setupoorexx.sh", cache
    call moveToTrash directory"/"subdirectory"/testoorexx.rex", cache
end

call popd
call footer "Collect done."
exit 0

error:
call sayCondition(condition("Object"))
exit 1

::requires "helpers.cls"
