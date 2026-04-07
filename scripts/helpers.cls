
/*******************************************************************************
*
* Library of ooRexx procedures/functions
*
*******************************************************************************/

-- Global settings
.local~sayConditionStack = .true
.local~verboseAddress = .false
.local~verboseChangeDirectory = .false

-- Scoped to their functionality, these settings can be overridden by global
-- settings.
-- For example, even if verboseGitCollect is false, you can still see the
-- commands executed by gitCollect (and all other routines) by setting
-- verboseAddress to true.
-- Conversely, if you want to see only the commands executed by gitCollect,
-- set verboseGitCollect to true and keep verboseAddress set to false.
.local~verboseGitCollect = .false
.local~verboseGitSparseCollect = .false
.local~verbosePushdPopd = .false
.local~verboseRobocopy = .false
.local~verboseRsync = .false
.local~verboseSvnCollect = .false

/*
Error 40 - Incorrect call to routine.
Error 48 - Failure in system service.
Error 88 - Invalid argument.
Error 93 - Incorrect call to method.
Error 98 - Execution error.
*/

-- ::options trace i

--------------------------------------------------------------------------------
::routine "prettySettings" private
    -- Common settings for pretty print
    use strict arg -- none

    settings = .StringTable~new

    -- width is large enough to allow for good alignment of "to"
    -- when displaying "from path" "to path"
    settings~width = 75

    -- spacing: keep alignment
    settings~cache      = "Cache =    "
    settings~copyFile   = "Copy file  "
    settings~copyDir    = "Copy dir   "     -- the first trailing space will be replaced by one letter: "C" or "D"
    settings~createdDir = "Created dir"
    settings~delivery   = "Delivery = "
    settings~github     = "Github =   "
    settings~mirrorDir  = "Mirror dir "     -- the first trailing space will be replaced by one letter: "C" or "D"
    settings~renameDir  = "Rename dir "

    return settings


--------------------------------------------------------------------------------
::routine replaceFirstTrailingSpace private
    --     "Mirror dir " --> "Mirror dirC"
    --     "Copy dir   " --> "Copy dirC  "
    use strict arg string, character

    character = character~subchar(1)
    if character == "" then return string -- nothing to replace

    strippedString = string~strip("Trailing")
    replacePos = strippedString~length + 1
    if replacePos <= string~length then do
        string = string~replaceAt(character, replacePos)
    end
    return string


--------------------------------------------------------------------------------
::routine "header" public
    use strict arg string

    surround = "*"~copies(string~length + 4)
    .traceOutput~say
    .traceOutput~say(surround)
    .traceOutput~say("*" string "*")
    .traceOutput~say(surround)
    .traceOutput~say


--------------------------------------------------------------------------------
::routine "footer" public
    use strict arg string

    .traceOutput~say(string)


--------------------------------------------------------------------------------
::routine "quoted" public
    use strict arg string, quote='"'
    return quote || string || quote


--------------------------------------------------------------------------------
::routine "assert" public
    use strict arg value, errorCode, errorText

    if value == .true then return
    raise syntax (errorCode) array (errorText)


--------------------------------------------------------------------------------
::routine "assertSupportedPath" public
    -- The .File class does not handle these paths well, when combining
    -- several paths. Reject any such paths:
    -- d:\dir\file when d: is different from the default drive
    -- \\server\share\dir\file
    -- \\?\d:\dir\file
    -- \\.\nul
    use strict arg path -- relative or absolute

    separator = .File~separator
    if separator == "\" then do -- same test as .File implementation
        path = .File~new(path)~absolutePath
        pathDrive = filespec("drive", path)
        currentDrive = filespec("drive", directory())
        call assert pathDrive == currentDrive, 88.900, -
            "Unsupported path:" || .RexxInfo~endofline || -
            quoted(path) || .RexxInfo~endofline || -
            "Do not specify the drive letter'"pathDrive"'." || .RexxInfo~endofline || -
            "Instead, make sure you are on the correct drive." || .RexxInfo~endofline || -
            "The current drive is '"currentDrive"'."
        call assert \ path~startsWith("\\"), 88.900, "Windows UNC paths starting with \\ are not supported"
    end


--------------------------------------------------------------------------------
::routine "assertRelativePathWithoutDrive" public
   -- A path is relative if it doesn't start with "/" or "\".
   -- A path starting with a drive letter is not accepted, even if the drive
   -- is not followed by a \.
    use arg path

    if path~class \== .File then path = .File~new(path)
    path = path~path -- the original path after normalization

    -- On Windows, "/" is normalized "\".
    -- On Unix, "\" is NOT normalized "/", it remains "\".
    -- On Unix, it would be wrong to test if the path starts with "\",
    -- so testing only .File~separator is the right thing to do.
    check = 0
    if path~startsWith(.File~separator) then check = 1 -- absolute path
    if .File~separator == "\", path~matchChar(2, ":") then check = 2 -- Windows drive letter

    if check \== 0 then do
        errorText = "Expected a relative path"
        if check == 2 then errorText ||= " without a drive letter"
        errorText ||= "." || .RexxInfo~endofline
        errorText ||= "Got" quoted(path)
        call assert check == 0, 88.900, errorText
    end


--------------------------------------------------------------------------------
::routine "assert_not_inside_a_git_repository" public
    use strict arg cache

/*
    cache = .File~new(cache)
    longestPath = directoryLongestExistingPath(cache)
    if longestPath == "" then return -- There are no existing directories in the cache path

    call pushd longestPath
    address system "git status" with output stem output. error stem error.
    call assert RC \== 0, 98.900, "The cache can't be inside a Git repository"
    call popd
*/

    path = directoryLongestExistingPath(cache)
    do while path \== "" & .NIL \== path
        dot_git = .File~new(".git", path)
        call assert \ dot_git~exists, 98.900, -
                    "The cache can't be inside a Git repository, found:" || .RexxInfo~endofline || -
                    dot_git
        path = .File~new(path)~parent
    end


--------------------------------------------------------------------------------
::routine "assert_not_inside_a_svn_working_copy" public
    use strict arg cache

    path = directoryLongestExistingPath(cache)
    do while path \== "" & .NIL \== path
        dot_svn = .File~new(".svn", path)
        call assert \ dot_svn~exists, 98.900, -
                    "The cache can't be inside an SVN working copy, found:" || .RexxInfo~endofline || -
                    dot_svn
        path = .File~new(path)~parent
    end


--------------------------------------------------------------------------------
::routine "gitVersion" public
    use strict arg -- none

    address system "git --version" with output stem output.
    call assert RC == 0, 48.900, "git --version failed; RC =" RC
    return output.1


--------------------------------------------------------------------------------
::routine "svnVersion" public
    use strict arg -- none

    address system "svn --version --quiet" with output stem output.
    call assert RC == 0, 48.900, "svn --version failed; RC =" RC
    return output.1


--------------------------------------------------------------------------------
::routine "gitPrerequisites" public
    use strict arg directory

    .traceOutput~say("Using" gitVersion())
    call assert_not_inside_a_git_repository directory


--------------------------------------------------------------------------------
::routine "svnPrerequisites" public
    use strict arg directory

    .traceOutput~say("Using svn" svnVersion())
    call assert_not_inside_a_svn_working_copy directory


--------------------------------------------------------------------------------
::routine "setupCache" public
    use strict arg cache, okToCreate=.true

    if cache~isNIL then cache = "cache"
    cache = .File~new(cache)
    call assertSupportedPath cache

    .local~cacheParent = cache~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~cache quoted(cache))

    call gitPrerequisites cache
    call svnPrerequisites cache

    if cache~exists then call assert cache~isDirectory, 48.900, cache "is not a directory"
    else do
        call assert okToCreate, 98.900, "The cache directory should exist. Did you run collect?"
        call charout , "Ok to create the cache directory? (Y/n) "
        parse linein answer
        call assert ("YES"~caselessAbbrev(answer, 1) | answer == ""), 98.900, "Cancelled as requested"
        call createDirectory cache
    end

    return cache


--------------------------------------------------------------------------------
::routine "setupDelivery" public
    use strict arg delivery

    if delivery~isNIL then delivery = "delivery"
    delivery = .File~new(delivery)
    call assertSupportedPath delivery

    .local~deliveryParent = delivery~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~delivery quoted(delivery))

    if delivery~exists then call assert delivery~isDirectory, 48.900, delivery "is not a directory"
    else do
        call charout , "Ok to create the delivery directory? (Y/n) "
        parse linein answer
        call assert ("YES"~caselessAbbrev(answer, 1) | answer == ""), 98.900, "Cancelled as requested"
        call createDirectory delivery
    end

    return delivery


--------------------------------------------------------------------------------
::routine "setupGithub" public
    use strict arg -- none

    parse source . . thisPath
    scripts = .File~new(thisPath)~parentFile
    github = scripts~parentFile

    .local~githubParent = github~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~github quoted(github))

    return github


--------------------------------------------------------------------------------
::routine "system" public
    use strict arg command, verbose=.false
    verbose |= .verboseAddress

    if verbose then .traceOutput~say("address system" command)
    address system (command)
    call assert RC == 0, -
                98.900, -
                command || .RexxInfo~endofline || -
                "RC should be 0; got" RC


--------------------------------------------------------------------------------
::routine "gitCollect" public
    use strict arg URL, cache, localRepo, verbose=.false
    verbose |= .verboseGitCollect

    call assertRelativePathWithoutDrive localRepo
    localRepo = .File~new(localRepo, cache)

    dot_git = .File~new(".git", localRepo)
    if dot_git~exists then do
        -- git clone already done, a simple git pull is all that's needed
        call assert dot_git~isDirectory, 98.900, dot_git "exists but is not a directory"
        call changeDirectory localRepo,                     verbose
        call system "git pull",                             verbose
        call system "git log -1 --format="quoted("%h %ci"), verbose
    end
    else do
        call changeDirectory cache,                         verbose
        call system "git clone --depth 1" quoted(URL),      verbose
        call changeDirectory localRepo,                     verbose
        call system "git log -1 --format="quoted("%h %ci"), verbose
    end


--------------------------------------------------------------------------------
::routine "gitSparseCollect" public
    -- This routine takes one additional argument compared to gitCollect:
    -- an array of components to sparse-checkout.
    use strict arg URL, cache, localRepo, components, verbose=.false
    verbose |= .verboseGitSparseCollect

    call assertRelativePathWithoutDrive localRepo
    localRepo = .File~new(localRepo, cache)

    dot_git = .File~new(".git", localRepo)
    if dot_git~exists then do
        -- git clone already done, a simple git pull is all that's needed
        call assert dot_git~isDirectory, 98.900, dot_git "exists but is not a directory"
        call changeDirectory localRepo,                                                 verbose
        call system "git pull",                                                         verbose
        call system "git log -1 --format="quoted("%h %ci"),                             verbose
    end
    else do
        call changeDirectory cache,                                                     verbose
        call system "git clone --depth 1 --filter=blob:none --no-checkout" quoted(URL), verbose
        call changeDirectory localRepo,                                                 verbose
        call system "git sparse-checkout init --cone",                                  verbose
        do counter i component over components
            if i == 1 then command = "set"
                      else command = "add"
            call system "git sparse-checkout" command quoted(component),                verbose
        end
        call system "git checkout",                                                     verbose
        call system "git log -1 --format="quoted("%h %ci"),                             verbose
    end


--------------------------------------------------------------------------------
::routine "svnCollect" public
    use strict arg URL, cache, localRepo, verbose=.false
    verbose |= .verboseSvnCollect

    call assertRelativePathWithoutDrive localRepo
    localRepo = .File~new(localRepo, cache)

    dot_svn = .File~new(".svn", localRepo)
    if dot_svn~exists then do
        -- svn checkout already done, a simple svn update is all that's needed
        call assert dot_svn~isDirectory, 98.900, dot_svn "exists but is not a directory"
        call changeDirectory localRepo,                             verbose
        call system "svn update" quoted(localRepo),                 verbose
    end
    else do
        call changeDirectory cache,                                 verbose
        call system "svn checkout" quoted(URL) quoted(localRepo),   verbose
    end


--------------------------------------------------------------------------------
::routine "relativePath" public
    -- Absolute paths can be too long when displayed though traceOutput.
    -- This helper transforms an absolute path into a relative path by removing
    -- the cache, delivery and net-oo-rexx prefixes, when applicable.
    -- Example:
    --     "/usr/tmp/cache/executor/aFile"          --> "cache/executor/aFile"
    --     "/usr/tmp/delivery/executor/aFile"       --> "delivery/executor/aFile"
    --     "/local/rexx/net-oo-rexx/packages/regex" --> "net-oo-rexx/packages/regex"
    use strict arg path

    -- .File to .String
    path = path~string
    cacheParent = .cacheParent~string -- can be .NIL or ".CACHEPARENT"
    deliveryParent = .deliveryParent~string -- can be .NIL or ".DELIVERYPARENT"
    githubParent = .githubParent~string -- can be .NIL or ".GITHUBPARENT"

    if path~startsWith(cacheParent) then return path~substr(cacheParent~length + 2)
    if path~startsWith(deliveryParent) then return path~substr(deliveryParent~length + 2)
    if path~startsWith(githubParent) then return path~substr(githubParent~length + 2)
    return path


--------------------------------------------------------------------------------
::routine "copyFile" public
    use strict arg sourceFile, destDir

    sourceFile = .File~new(sourceFile)
    destDir = .File~new(destDir)
    destFile = .File~new(sourceFile~name, destDir)

    settings = prettySettings()
    prettySourceFile = quoted(relativePath(sourceFile))~left(settings~width)
    prettyDestDir = quoted(relativePath(destDir))
    .traceOutput~say(settings~copyFile prettySourceFile "to" prettyDestDir)

    call createDirectory destDir
    call SysFileCopy sourceFile, destFile
    call assert result == 0, -
                48.900, -
                "An error occured while copying the file" || .RexxInfo~endofline || -
                quoted(sourceFile) || .RexxInfo~endofline || -
                "to" || .RexxInfo~endofline || -
                quoted(destFile)


--------------------------------------------------------------------------------
::routine "copyOrMirrorDirectory" private
    -- How: "C" to copy, "M" to mirror
    -- What: "C" for contents, "D" for directory itself
    use strict arg how, what, sourceDir, destDir, verbose=.false

    sourceDir = .File~new(sourceDir)
    destDir = .File~new(destDir)

    settings = prettySettings()
    prettySourceDir = quoted(relativePath(sourceDir))~left(settings~width)
    prettyDestDir = quoted(relativePath(destDir))
    action = settings~copyDir
    if how == "M" then action = settings~mirrorDir
    action = replaceFirstTrailingSpace(action, what)

    .traceOutput~say(action prettySourceDir "to" prettyDestDir)

    platform = .RexxInfo~platform
    select case platform~upper
        when "WINDOWSNT" then do
            -- robocopy RC values between 0 and 7 are considered success codes
            successCodeMax = 7

            mirror = ""
            if how == "M" then mirror = "/MIR"

            if what == "D" then do
                sourceDirName = sourceDir~name
                destDir = .File~new(sourceDirName, destDir)
            end

            -- use quite = "" if you want to see all the details
            quiet = "/NFL /NDL /NJH /NJS"
            exclude = "/XD .git /XF .gitattributes .gitignore .DS_Store *.zip"

            command = "robocopy" quoted(sourceDir) quoted(destDir) mirror quiet exclude "/R:0 /W:0"
            if verbose | .verboseRobocopy | .verboseAddress then .traceOutput~say("address system" command)
            address system (command)
            end

        when "LINUX", "DARWIN" then do
            successCodeMax = 0

            delete = "--delete" -- sometimes warning "<directory> not empty, cannot delete"
            delete = "--delete-after --delete-excluded" -- An AI said it's better with these options
            if how == "C" then delete = ""

            if what == "C" then sourceDir ||= "/" -- the trailing slash changes semantics: copy contents

            exclude = "--exclude='.git' --exclude='.gitattributes' --exclude='.gitignore' --exclude='.DS_Store' --exclude='*.zip'"

            command = "rsync -a" delete exclude quoted(sourceDir) quoted(destDir)
            if verbose | .verboseRsync | .verboseAddress then .traceOutput~say("address system" command)
            address system (command)
            end

        otherwise do
            raise syntax 48.900 array ("The" quoted(platform) "platform is not supported by copyOrMirrorDirectory")
            end
    end

    call assert RC >= 0 & RC <= successCodeMax, -
                48.900, -
                "RC =" RC || .RexxInfo~endofline || -
                "An error occured while copying the directory" || .RexxInfo~endofline || -
                quoted(sourceDir) || .RexxInfo~endofline || -
                "to" || .RexxInfo~endofline || -
                quoted(destDir)


--------------------------------------------------------------------------------
::routine "copyDirD" public
    -- copyDirD copies the directory itself (as opposed to copyDirC, which copies its contents)
    use strict arg sourceDir, destDir

    -- C D: Copy Directory
    call copyOrMirrorDirectory "C", "D", sourceDir, destDir


--------------------------------------------------------------------------------
::routine "copyDirC" public
    -- copyDirC copies the directory contents (as opposed to copyDirD, which copies the directory itself)
    use strict arg sourceDir, destDir

    -- C C: Copy Contents
    call copyOrMirrorDirectory "C", "C", sourceDir, destDir


--------------------------------------------------------------------------------
::routine "mirrorDirD" public
    -- mirrorDirD mirrors the directory itself (as opposed to mirrorDirC, which mirrors its contents)
    use strict arg sourceDir, destDir

    -- M D: Mirror Directory
    call copyOrMirrorDirectory "M", "D", sourceDir, destDir


--------------------------------------------------------------------------------
::routine "mirrorDirC" public
    -- mirrorDirC mirrors the directory contents (as opposed to mirrorDirD, which mirrors the directory itself)
    use strict arg sourceDir, destDir

    -- M C: Mirror Contents
    call copyOrMirrorDirectory "M", "C", sourceDir, destDir


--------------------------------------------------------------------------------
::routine "tryRenameDirectory" public
    -- Do not raise error in case of failure
    use strict arg currentName, newName

    currentName = .File~new(currentName)
    newName = .File~new(newName)

    renamed = currentName~renameTo(newName)

    if renamed then do
        settings = prettySettings()
        prettyCurrentName = quoted(relativePath(currentName))~left(settings~width)
        prettyNewName = quoted(relativePath(newName))
        .traceOutput~say(settings~renameDir prettyCurrentName "to" prettyNewName)
    end

    return renamed


--------------------------------------------------------------------------------
::routine "renameDirectory" public
    use strict arg currentName, newName

    currentName = .File~new(currentName)
    newName = .File~new(newName)

    settings = prettySettings()
    prettyCurrentName = quoted(relativePath(currentName))~left(settings~width)
    prettyNewName = quoted(relativePath(newName))
    .traceOutput~say(settings~renameDir prettyCurrentName "to" prettyNewName)

    call assert currentName~isDirectory, 48.900, currentName "is not a directory"
    call assert currentName~renameTo(newName), -
                48.900, -
                "An error occured while renaming the directory" || .RexxInfo~endofline || -
                quoted(currentName) || .RexxInfo~endofline || -
                "to" || .RexxInfo~endofline || -
                quoted(newName)


--------------------------------------------------------------------------------
::routine "directoryLongestExistingPath" public
    -- Given a path "/a/b/c/d", where "/a/b/c" is an existing directory and "d"
    -- does not exist, returns "a/b/c".
    use strict arg path

    if path~isNIL then return ""
    if path~string == "" then return ""
    file = .File~new(path)
    if file~isDirectory then return path~string
    if file~isFile then return ""

    parent = file~parentFile
    return directoryLongestExistingPath(parent)


--------------------------------------------------------------------------------
::routine "createDirectorySilent" public
    -- Under Windows, mkdir for multiple directories is not working on network drive.
    -- Creates the specified directory.
    -- Returns 0 if the directory already exists.
    -- Returns 1 if the directory has been created.
    -- Returns -1 if the creation failed because a file (not a directory) with the same name already exists.
    -- Returns -2 if the creation failed for any other reason.
    use strict arg path

    if path~isNIL then return 0
    if path~string == "" then return 0
    file = .File~new(path)
    if file~isDirectory then return 0
    if file~isFile then return -1

    parent = file~parentFile
    parentStatus = createDirectorySilent(parent)
    if parentStatus < 0 then return parentStatus

    if SysMkDir(path) <> 0 then return -2

    return 1


--------------------------------------------------------------------------------
::routine "createDirectory" public
    -- Creates the specified directory.
    -- Returns 0 if the directory already exists.
    -- Returns 1 if the directory has been created.
    use strict arg path

    status = createDirectorySilent(path)
    select case status
        when 1 then do
            settings = prettySettings()
            .traceOutput~say(settings~createdDir quoted(relativePath(path)))
            end
        when -1 then do
            raise syntax 48.900 array ( -
                "An error occured while creating the directory" || .RexxInfo~endofline || -
                quoted(path) || .RexxInfo~endofline || -
                "A file with same name already exists" -
                )
            end
        when -2 then do
            raise syntax 48.900 array ( -
                "An error occured while creating the directory" || .RexxInfo~endofline || -
                quoted(path) -
                )
            end
        otherwise nop
    end
    return status


--------------------------------------------------------------------------------
::routine "changeDirectory" public
    use strict arg path, verbose=.false
    verbose |= .verboseChangeDirectory

    path = .File~new(path)
    if verbose then .traceOutput~say("Change directory to" quoted(path)) -- don't use relativePath, I get "" when testing from script
    newDirectory = directory(path)
    call assert directory() == path, -
                48.900, -
                "directory() should be" || .RexxInfo~endofline || -
                quoted(path) || .RexxInfo~endofline || -
                "got" || .RexxInfo~endofline || -
                quoted(directory())
    call assert newDirectory == path, -
                48.900, -
                "newDirectory should be" || .RexxInfo~endofline || -
                quoted(path) || .RexxInfo~endofline || -
                "got" || .RexxInfo~endofline || -
                quoted(newDirectory)
    return newDirectory


--------------------------------------------------------------------------------
::routine "pushd" public
    use strict arg directory=(directory()), verbose=.false
    verbose |= .verbosePushdPopd

    if \ .directoryStack~isa(.Queue) then .local~directoryStack = .Queue~new
    .directoryStack~push(directory())
    call changeDirectory directory, verbose


--------------------------------------------------------------------------------
::routine "popd" public
    use strict arg verbose=.false
    verbose |= .verbosePushdPopd

    call assert .directoryStack~isa(.Queue), 98.900, "Internal error: popd was called before pushd"
    directory = .directoryStack~pull
    call assert .NIL \== .directory, 98.900, "Internal error: popd was called too many times (empty stack)"
    call changeDirectory directory, verbose


--------------------------------------------------------------------------------
::routine "sayCondition" public
    use strict arg condition

    if .sayConditionStack then do
        .error~say
        stackFrames = condition~stackFrames
        do stackFrame over stackFrames
            .error~say("Line" stackFrame~line~left(4) stackFrame~name)
        end
    end

    -- If the error was raised by ASSERT then show the caller's info
    --
    -- What?
    -- .context~stackFrames returns an array, with first index == 1
    -- condition~stackFrames returns a list, with first index == 0 (really? 0?)
    stackFrames = condition~stackFrames
    line = stackFrames[0]~line
    name = stackFrames[0]~name
    if stackFrames[0]~name == "ASSERT" then do
        line = stackFrames[1]~line
        name = stackFrames[1]~name
    end

    .error~say
    .error~say("ERROR:" condition~code)
    .error~say("Line :" line)
    .error~say("Name :" name)
    .error~say
    .error~say(condition~message)
    .error~say


--------------------------------------------------------------------------------
-- robocopy
--------------------------------------------------------------------------------

/*
      Usage :: ROBOCOPY source destination [file [file]...] [options]

             source :: Source Directory (drive:\path or \\server\share\path).
        destination :: Destination Dir  (drive:\path or \\server\share\path).
               file :: File(s) to copy  (names/wildcards: default is "*.*").
                 /E :: copy subdirectories, including Empty ones.
               /MIR :: MIRror a directory tree (equivalent to /E plus /PURGE)
             /PURGE :: delete dest files/dirs that no longer exist in source.
          /R:0 /W:0 :: fail fast instead of retrying locked files
                 /V :: produce Verbose output, showing skipped files.
 /XF file [file]... :: eXclude Files matching given names/paths/wildcards.
 /XD dirs [dirs]... :: eXclude Directories matching given names/paths.

Rule of thumb with robocopy
    Source (robocopy <src> <dst>) → always copies contents
    Destination path → determines whether a parent folder is recreated

    There is no flag to toggle “copy directory vs contents” (unlike rsync
    trailing slash behavior). You control it entirely via the destination path.
Examples
    robocopy c:\source\my-dir c:\new-dir /MIR
    --> c:\new-dir\<files from my-dir>

    robocopy c:\source\my-dir c:\new-dir\my-dir /MIR
    --> c:\new-dir\my-dir\<files>

Robocopy is verbose by default unlike rsync.
Add /NFL /NDL /NJH /NJS to suppress the noisy output if you want quieter
operation like rsync.
    /NFL    No File List — don't log individual file names
    /NDL    No Directory List — don't log directory names
    /NJH    No Job Header
    /NJS    No Job Summary

    Don't use this one! /XX was suggested by an AI to not have the EXTRA Dir and
    EXTRA File in the output. But that disables the deletion of extra dirs and
    files. And I have an error when renaming.
    /XX :: eXclude eXtra files and directories.


One semantic difference to be aware of:
rsync's --delete-excluded explicitly removes previously synced files that are
now excluded, while robocopy's /MIR simply mirrors the source as-is — excluded
files already in the destination are left in place, not deleted.
If you need excluded files to also be purged from the destination, robocopy has
no direct equivalent and you'd need a separate cleanup step.

The return code from Robocopy is a bitmap where the value is the sum of specific
bit flags, meaning a single number can indicate multiple conditions simultaneously.
    0: No files were copied; the source and destination are completely synchronized.
    1: One or more files were copied successfully.
    2: Extra files or directories were detected in the destination that do not
       exist in the source.
    4: Mismatched files or directories were detected; housekeeping may be required.
    8: Copy failure; some files could not be copied because the retry limit was
       exceeded.
    16: Serious error; Robocopy did not copy any files due to usage errors or
        insufficient access privileges.
Values between 0 and 7 are considered success codes, while any value 8 or
greater indicates that at least one failure occurred during the operation.
Combined codes (e.g., 11 = 8+2+1) indicate that multiple conditions (failed
copies, extra files, and successful copies) happened in the same run.

*/


--------------------------------------------------------------------------------
-- rsync
--------------------------------------------------------------------------------

/*
-a, --archive
    Archive mode (preserves permissions/timestamps).
    Shorthand for -Dgloprt.

--del, --delete
    Removes files from the destination not present in the source
    (equivalent to Robocopy's /MIR). Only applicable with -r.

-n, --dry-run
   Do not actually modify the destination.
   Mainly useful in combination with -v.

--info option to control output:
    NOT SUPPORTED on macOS :-(((
    --info=NAME: Shows the name of each file as it is transferred.
    --info=DEL: Shows files deleted if using --delete.
    --info=FLIST0: Suppresses the file list statistics (the summary you want to hide).

    Example
        rsync -a --info=NAME,DEL,FLIST0 /source/ /destination/

-r, --recursive
    If source designates a directory, synchronise the directory and
    the entire subtree connected at that point.
    If source ends with a slash, only the subtree is synchronised,
    not the source directory itself.
    If source is a file, this has no effect.

    With a trailing slash (dir/): Rsync copies only the contents of
    the directory into the destination.
        rsync -r dir/ new-dir
        → Creates new-dir/file1, new-dir/file2, etc.
    Without a trailing slash (dir): Rsync copies the directory
    itself into the destination.
        rsync -r dir new-dir
        → Creates new-dir/dir/file1, new-dir/dir/file2, etc.

-v, --verbose
    Verbose output. Specify once for files being transferred, twice for specific
    status, thrice for per-file transfer information, and four times for
    per-file breakdowns


<Pffff...>
Apple replaced the standard rsync with openrsync in macOS Sequoia primarily due
to licensing conflicts with the GNU General Public License version 3 (GPLv3).

The official rsync project updated to GPLv3 in version 3.x, a license Apple
determined it could not comply with for inclusion in its operating system, as it
imposes stricter restrictions on proprietary software integration compared to
the older GPLv2.  Consequently, Apple switched to openrsync, a variant licensed
under the permissive ISC license (a BSD-style license), which allows Apple to
distribute, modify, and update the tool without legal complications

While openrsync is compatible with standard rsync for most basic tasks, users
should note that it supports only a subset of the original command-line
arguments and features.  This means some advanced functionalities or scripts
relying on specific rsync flags may fail or behave differently on macOS Sequoia
compared to previous versions or other Unix systems.

https://github.com/RsyncProject

</Pffff...>


With the --delete option , I have these warnings:
    rsync(83257): warning: /Users/Shared/local/rexx/net-oo-rexx/delivery/packages/testsuite/./bin/docs: not empty, cannot delete
    rsync(83257): warning: /Users/Shared/local/rexx/net-oo-rexx/delivery/packages/testsuite/./bin: not empty, cannot delete
Because of that, I have an error:
    An error occured while renaming the directory
    "/Users/Shared/local/rexx/net-oo-rexx/delivery/packages/testsuite/framework"
    to
    "/Users/Shared/local/rexx/net-oo-rexx/delivery/packages/testsuite/bin".
AI feedback:
    Those warnings are classic rsync --delete edge cases.
    They don’t mean failure
    they mean rsync tried to delete a directory before it was empty.

    What’s actually happening
        - Scans destination
        - Starts deleting things that shouldn’t be there
        - Encounters a directory (docs, bin)
        - Tries to remove it before all its contents are deleted
        - Fails → “not empty, cannot delete”
        - Continues, later removes contents, but doesn’t retry the parent dir
    So you end up with harmless warnings.

    Proper fix: use --delete-after
        rsync -a --delete-after ...
    Why this works
        Deletes happen after the transfer phase
        By then, all child files/dirs are already removed
        So parent directories can be cleanly deleted

    If .DS_Store or similar files are excluded, they can block directory deletion:
    Example:
        --exclude .DS_Store --delete
    If .DS_Store exists in destination but is excluded from transfer:
        rsync won’t touch it
        directory never becomes empty
        deletion fails
    Fix:
        --delete-excluded

*/
