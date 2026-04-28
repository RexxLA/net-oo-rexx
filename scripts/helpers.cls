
/*******************************************************************************
*
* Library of ooRexx procedures/functions
*
*******************************************************************************/

-- Global settings
.local~sayConditionStack = .true
call getEnvironmentBoolean "verbose"


/*
Error 40 - Incorrect call to routine.
Error 48 - Failure in system service.
Error 88 - Invalid argument.
Error 93 - Incorrect call to method.
Error 98 - Execution error.
*/


--------------------------------------------------------------------------------
::routine "getEnvironmentBoolean"
    -- Get varname boolean value from ENVIRONMENT (case sensitive), store it in .local[varname~upper]
    use strict arg varname, defaultValue=.false

    value = value(varname,, "ENVIRONMENT")
    if value == "" then value = defaultValue
    -- Can't use assert here, because can't be trapped properly when ::requires "helpers.cls"
    condition = (value == "0" | value == "1")
    call warning condition, 88.900, "The value of the environment variable '" || varname || "' is '" || value || "'. Expected 0 or 1, using 0"
    if \ condition then value = .false
    .local[varname~upper] = value


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
    settings~createDir  = "Create dir "
    settings~delivery   = "Delivery = "
    settings~download   = "Download   "
    settings~getHTML    = "Get HTML   "
    settings~localClone = "LocalClone="
    settings~mirrorDir  = "Mirror dir "     -- the first trailing space will be replaced by one letter: "C" or "D"
    settings~move       = "Move       "
    settings~renameDir  = "Rename dir "
    settings~release    = "Release =  "
    settings~unzip      = "Unzip      "

    return settings


--------------------------------------------------------------------------------
::routine "replaceFirstTrailingSpace" private
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
::routine "warning" public
    use strict arg value, errorCode, errorText

    if value == .true then return
    .traceOutput~say("Warning" errorCode errorText)


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
            "Unsupported path:" || .endOfLine || -
            quoted(path) || .endOfLine || -
            "Do not specify the drive letter'"pathDrive"'." || .endOfLine || -
            "Instead, make sure you are on the correct drive." || .endOfLine || -
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
        errorText ||= "." || .endOfLine
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
                    "The cache can't be inside a Git repository, found:" || .endOfLine || -
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
                    "The cache can't be inside an SVN working copy, found:" || .endOfLine || -
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
::routine "answerToQuestion" private
    use strict arg question

    -- On Windows, stdout may be piped through `findstr "^"` to have a well-aligned output.
    -- For the question to be visible, a newline must be displayed after the question because of `findstr`buffering.
    if isaTerminal("stdout") then do
        call charout , question -- best display; cursor on the same line
    end
    else do
        endOfLine = ""
        -- On Windows, `say` is not enough; an additional line break is required.
        if .RexxInfo~platform~caselessEquals("WINDOWSNT") then endOfLine = .endOfLine
        say question endOfLine -- cursor on the next line (empty)
    end
    parse linein answer
    return answer


--------------------------------------------------------------------------------
::routine "setupCache" public
    use strict arg cache, default, okToCreate=.true

    if cache~isNIL then cache = default
    if cache~isNIL then cache = "cache"
    cache = .File~new(cache)
    call assertSupportedPath cache

    .local~cacheParent = cache~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~cache quoted(cache))

    if okToCreate then do
        call gitPrerequisites cache
        call svnPrerequisites cache
    end

    if cache~exists then call assert cache~isDirectory, 48.900, cache "is not a directory"
    else do
        call assert okToCreate, 98.900, "The cache directory should exist. Did you run collect?"

        answer = answerToQuestion("Ok to create the cache directory? (Y/n) ")
        call assert ("YES"~caselessAbbrev(answer, 1) | answer == ""), 98.900, "Cancelled as requested"
        call createDirectory cache
    end

    return cache


--------------------------------------------------------------------------------
::routine "setupDelivery" public
    use strict arg delivery, default

    if delivery~isNIL then delivery = default
    if delivery~isNIL then delivery = "delivery"
    delivery = .File~new(delivery)
    call assertSupportedPath delivery

    .local~deliveryParent = delivery~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~delivery quoted(delivery))

    if delivery~exists then call assert delivery~isDirectory, 48.900, delivery "is not a directory"
    else do
        answer = answerToQuestion("Ok to create the delivery directory? (Y/n) ")
        call assert ("YES"~caselessAbbrev(answer, 1) | answer == ""), 98.900, "Cancelled as requested"
        call createDirectory delivery
    end

    return delivery


--------------------------------------------------------------------------------
::routine "setupRelease" public
    use strict arg release, default

    if release~isNIL then release = default
    if release~isNIL then release = "release"
    release = .File~new(release)
    call assertSupportedPath release

    .local~releaseParent = release~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~release quoted(release))

    if release~exists then call assert release~isDirectory, 48.900, release "is not a directory"
    else do
        answer = answerToQuestion("Ok to create the release directory? (Y/n) ")
        call assert ("YES"~caselessAbbrev(answer, 1) | answer == ""), 98.900, "Cancelled as requested"
        call createDirectory release
    end

    return release


--------------------------------------------------------------------------------
::routine "setupLocalClone" public
    use strict arg -- none

    parse source . . thisPath
    scripts = .File~new(thisPath)~parentFile
    localClone = scripts~parentFile

    .local~localCloneParent = localClone~parentFile -- see relativePath
    settings = prettySettings()
    .traceOutput~say(settings~localClone quoted(localClone))

    return localClone


--------------------------------------------------------------------------------
::class "NullOutput"

-- nothing displayed
::method charOut class
::method flush class
::method lineOut class
::method say class


--------------------------------------------------------------------------------
::routine "trySystem" public
    use strict arg command, verbose=.false
    verbose |= .verbose

    if verbose then .traceOutput~say("Try address system" command)
    .error~destination(.NullOutput)
    address system (command) with error stem error.
    .error~destination -- restore

    if verbose then do
        do i = 1 to error.0
            .error~say(error.i)
        end
    end

    return RC


--------------------------------------------------------------------------------
::routine "system" public
    use strict arg command, verbose=.false
    verbose |= .verbose

    if verbose then .traceOutput~say("address system" command)
    address system (command)
    call assert RC == 0, -
                98.900, -
                command || .endOfLine || -
                "RC should be 0; got" RC


--------------------------------------------------------------------------------
::routine "systemOutput" public
    use strict arg command, verbose=.false
    verbose |= .verbose

    if verbose then .traceOutput~say("address system" command)
    output = .array~new
    address system (command) with output using (output)
    call assert RC == 0, -
                98.900, -
                command || .endOfLine || -
                "RC should be 0; got" RC

    return output


--------------------------------------------------------------------------------
::routine "gitCollect" public
    use strict arg URL, cache, localRepo, verbose=.false
    verbose |= .verbose

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
    verbose |= .verbose

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
    verbose |= .verbose

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
::routine "downloadURL" private
    -- Downloaded only if the local file does not exist.
    -- Always return the downloaded file as an instance of .file.
    -- Uses curl.
    -- I abandonned Powershell Invoke-WebRequest because it doesn't support SourceForge.
    -- Anyway, curl is available in Windows 10/11.
    use strict arg URL, cache, verbose=.false
    verbose |= .verbose

    downloads = .File~new("downloads", cache)
    call createDirectory downloads
    call changeDirectory downloads, verbose

    -- If SourceForge URL, remove trailing "/download" if present
    URL = URL~strip
    if URL~startsWith("https://sourceforge.net/projects/") then do
        if URL~endsWith("/download") then URL = URL~left(URL~length - "/download"~length)
    end

    settings = prettySettings()
    .traceOutput~say(settings~download quoted(URL))

    filename = .File~new(URL)~name
    filename = .File~new(filename, downloads)
    if filename~exists then do
        .traceOutput~say("No download needed; already available")
        return filename
    end

    command = 'curl' '--noproxy "*" --insecure -L --output' quoted(filename) quoted(URL)
    call system command, verbose

    return filename


--------------------------------------------------------------------------------
::routine "unzipFile" private
    -- Unzip only if the local directory does not exist, or is older
    -- If needed, the older directory is moved to trash
    use strict arg zipFile, cache, localRepo, verbose=.false
    verbose |= .verbose

    call assertRelativePathWithoutDrive localRepo
    localRepo = .File~new(localRepo, cache)

    settings = prettySettings()
    prettyZipFile = quoted(relativePath(zipFile))~left(settings~width)
    prettyLocalRepo = quoted(relativePath(localRepo))
    .traceOutput~say(settings~unzip prettyZipFile "to" prettyLocalRepo)

    if localRepo~exists then do
        zipFileDateTime = zipFile~lastModified
        localRepoDateTime = localRepo~lastModified
        if .NIL \== zipFileDateTime, .NIL \== localRepoDateTime, zipFileDateTime <= localRepoDateTime then do
            .traceOutput~say("No need to unzip; directory already available")
            return .false
        end
        call moveToTrash localRepo, cache
    end

    redirectErrorsToNull = "2>/dev/null"
    if .RexxInfo~platform~caselessEquals("WINDOWSNT") then redirectErrorsToNull = "2>nul"
    if verbose then redirectErrorsToNull = ""

    tryUnzip = .true
    tryPwsh = .true
    tryPowershell = .true

    RC = -1
    if tryUnzip then do
        -- Pffff... Ubuntu's unzip requires the destination directory to already exist
        -- checkdir:  cannot create extraction directory
        -- macOS's unzip creates the directory!!!!
        call createDirectory localRepo
        command = 'unzip -q' quoted(zipFile) '-d' quoted(localRepo) redirectErrorsToNull
        RC = trySystem(command, verbose)
        RC_unzip = RC
    end
    if RC \== 0, tryPwsh then do
        command = 'pwsh -Command "Expand-Archive -Path' quoted(zipFile, "'") '-DestinationPath' quoted(localRepo) '-Force | Out-Null"' redirectErrorsToNull
        RC = trySystem(command, verbose)
        RC_pwsh = RC
    end
    if RC \== 0, tryPowershell then do
        command = 'powershell -Command "Expand-Archive -Path' quoted(zipFile, "'") '-DestinationPath' quoted(localRepo) '-Force | Out-Null"' redirectErrorsToNull
        RC = trySystem(command, verbose)
        RC_powershell = RC
    end

    if RC \== 0 then do
        call moveToTrash localRepo, cache -- If the folder was created, delete it because it is invalid.
        if RC == -1 then errorText = "No unzipper is active, fix the 'unzipFile' routine"
        else do
            errorText = ""
            if tryUnzip      then errorText ||= endOfLine() || "Tried unzip, RC =" RC_unzip
            if tryPwsh       then errorText ||= endOfLine() || "Tried pwsh Expand-Archive, RC =" RC_pwsh
            if tryPowershell then errorText ||= endOfLine() || "Tried powershell Expand-Archive, RC =" RC_powershell
        end
        call assert RC == 0, -
                    48.900, -
                    "An error occured while unzipping" || .endOfLine || -
                    quoted(zipFile) || .endOfLine || -
                    errorText
    end

    return .true

    endOfLine:
        -- Insert an endOfLine if errorText not empty
        if errorText == "" then return ""
        return .endOfLine


--------------------------------------------------------------------------------
::routine "zipCollect" public
    -- Return true if cache updated.
    -- Return false if download and unzip not needed.
    use strict arg URL, cache, localRepo, verbose=.false
    verbose |= .verbose

    call downloadURL URL, cache, verbose
    call unzipFile result, cache, localRepo, verbose
    return result


--------------------------------------------------------------------------------
::routine "getHTML" private
    -- Downloads an HTML page; returns an array of strings.
    -- Uses curl.
    use strict arg URL, verbose=.false
    verbose |= .verbose

    settings = prettySettings()
    .traceOutput~say(settings~getHTML quoted(URL))

    command = 'curl' '--noproxy "*" --insecure -L -s' quoted(URL)
    call systemOutput command, verbose

    return result


--------------------------------------------------------------------------------
::routine "getLatestOORexxPortableZIPs" public
    -- With an URL like "https://sourceforge.net/projects/oorexx/files/oorexx/5.3.0beta/portable",
    -- returns a table of the most recent ZIP files indexed by platform.
    use strict arg URL, verbose=.false
    verbose |= .verbose

    call getHTML URL, verbose

    lines = result
    /*
    Expected format:
        <th scope="row" headers="files_name_h"><a href="https://sourceforge.net/projects/oorexx/files/oorexx/5.3.0beta/portable/oorexx-5.3.0-13163.fedora43.x86_64-portable-release.zip/download"
        <th scope="row" headers="files_name_h"><a href="https://sourceforge.net/projects/oorexx/files/oorexx/5.3.0beta/portable/oorexx-5.3.0-13163.linuxmint22.x86_64-portable-release.zip/download"
        <th scope="row" headers="files_name_h"><a href="https://sourceforge.net/projects/oorexx/files/oorexx/5.3.0beta/portable/oorexx-5.3.0-13163.raspberrypios32.armv7l-portable-release.zip/download"
        etc...
    sorted from newest to oldest
    */
    portableZIPs = .stringTable~new
    counter = 1
    do line over lines
        line = line~strip
        if line~startsWith("<th ") & line~endsWith('-portable-release.zip/download"') then do
            parse var line . '<a href="' ZIP_URL '"' .
            call assert ZIP_URL \== "", 98.900, 'Missing <a href="..." in line' || .endOfLine || quoted(line)
            ZIP_URL = ZIP_URL~left(ZIP_URL~length - "/download"~length) -- remove trailing "/download"
            filename = .File~new(ZIP_URL)~name
            -- oorexx-5.3.0-13163.fedora43.x86_64-portable-release.zip
            parse var filename "oorexx-" version "-" revision "." platform "-portable-release.zip"
            expectedFormat = "Expected format: oorexx-<version>-<revision>.<platform>-portable-release.zip"
            call assert version \== "", 98.900, "Version not found in filename" quoted(filename) || .endOfLine || expectedFormat
            call assert revision \== "", 98.900, "Revision not found in filename" quoted(filename) || .endOfLine || expectedFormat
            call assert platform \== "", 98.900, "Platform not found in filename" quoted(filename) || .endOfLine || expectedFormat
            if \ portableZIPs~hasIndex(platform) then portableZIPs[platform] = ZIP_URL -- store the newest
        end
    end

    return portableZIPs


--------------------------------------------------------------------------------
::routine "getOORexxPortableZIP" public
    use strict arg portableZIPs, platform

    portableZIP = portableZIPs[platform]
    call assert .NIL \== portableZIP, 98.900, "No portable ZIP for platform" quoted(platform)

    return portableZIP


--------------------------------------------------------------------------------
::routine "relativePath" public
    -- Absolute paths can be too long when displayed though traceOutput.
    -- This helper transforms an absolute path into a relative path by removing
    -- the cache, delivery, release and net-oo-rexx prefixes, when applicable.
    -- Example:
    --     "/usr/tmp/cache/executor/aFile"          --> "cache/executor/aFile"
    --     "/usr/tmp/delivery/executor/aFile"       --> "delivery/executor/aFile"
    --     "/usr/tmp/release/aRelease/aFile"        --> "release/aRelease/aFile"
    --     "/local/rexx/net-oo-rexx/packages/regex" --> "net-oo-rexx/packages/regex"
    use strict arg path

    -- .File to .String
    path = path~string
    cacheParent = .cacheParent~string -- can be .NIL or ".CACHEPARENT"
    deliveryParent = .deliveryParent~string -- can be .NIL or ".DELIVERYPARENT"
    releaseParent = .releaseParent~string -- can be .NIL or ".DELIVERYPARENT"
    localCloneParent = .localCloneParent~string -- can be .NIL or ".LOCALCLONEPARENT"

    if path~startsWith(cacheParent) then return path~substr(cacheParent~length + 2)
    if path~startsWith(deliveryParent) then return path~substr(deliveryParent~length + 2)
    if path~startsWith(releaseParent) then return path~substr(releaseParent~length + 2)
    if path~startsWith(localCloneParent) then return path~substr(localCloneParent~length + 2)
    return path


--------------------------------------------------------------------------------
::routine "getUniqueSubdirectory" public
    -- Given a directory hiearchy like:
    --    path/
    --        directory/
    --            ...
    -- returns directory as a string.
    -- This is needed to work with ZIP files containing a top-level directory
    -- that must be ignored when copying the hierarchy.
    -- An error is raised if path has no directory, or several directories.
    use strict arg path

    path = .File~new(path)
    files = path~listFiles
    call assert .NIL \== files, 98.900, quoted(path) || .endOfLine || "is not a directory"
    call assert files~items == 1, 98.900, quoted(path) || .endOfLine || "expected 1 subdirectory, found" files~items
    subdirectory = files[1]
    call assert subdirectory~isDirectory, 98.900, quoted(subdirectory) || .endOfLine || "is not a directory"

    return subdirectory~name


--------------------------------------------------------------------------------
::routine "copyFile" public
    use strict arg sourceFile, destDir, destFile=""

    sourceFile = .File~new(sourceFile)
    destDir = .File~new(destDir)
    if destFile == "" then destFile = sourceFile~name
    destFile = .File~new(destFile, destDir)

    settings = prettySettings()
    prettySourceFile = quoted(relativePath(sourceFile))~left(settings~width)
    prettyDestDir = quoted(relativePath(destDir))
    .traceOutput~say(settings~copyFile prettySourceFile "to" prettyDestDir)

    call createDirectory destDir
    call SysFileCopy sourceFile, destFile
    call assert result == 0, -
                48.900, -
                "An error occured while copying the file" || .endOfLine || -
                quoted(sourceFile) || .endOfLine || -
                "to" || .endOfLine || -
                quoted(destFile)


--------------------------------------------------------------------------------
::routine "copyOrMirrorDirectory" private
    -- How: "C" to copy, "M" to mirror
    -- What: "C" for contents, "D" for directory itself
    use strict arg how, what, sourceDir, destDir, recursive=.true, ignoreTopLevelDirectory=.false, verbose=.false
    verbose |= .verbose

    sourceDir = .File~new(sourceDir)
    destDir = .File~new(destDir)

    if ignoreTopLevelDirectory then do
        subdirectory = getUniqueSubdirectory(sourceDir)
        sourceDir = .File~new(subdirectory, sourceDir)
    end

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

            copySubdirectories = ""
            if recursive then copySubdirectories = "/E"

            purge = ""
            if how == "M" then purge = "/PURGE"

            if what == "D" then do
                sourceDirName = sourceDir~name
                destDir = .File~new(sourceDirName, destDir)
            end

            -- use quiet = "" if you want to see all the details
            quiet = "/NFL /NDL /NJH /NJS"
            exclude = "/XD .git .svn /XF .gitattributes .gitignore .DS_Store *.zip"

            command = "robocopy" quoted(sourceDir) quoted(destDir) copySubdirectories purge quiet exclude "/R:0 /W:0"
            if verbose then .traceOutput~say("address system" command)
            address system (command)
            end

        when "LINUX", "DARWIN" then do
            successCodeMax = 0

            -- Archive mode (preserves permissions/timestamps).
            -- Similar to -a (shorthand for -Dgloprt), but without "r".
            archive = "-Dglopt"

            -- Depending on the options, I may need to add the wildcard character "*" to sourceDir.
            -- Wildcards are not expanded if enclosed in quotes.
            -- That's why I enclose in quotes now, before appending "*"
            quotedSourceDir = quoted(sourceDir)
            if recursive then do
                copySubtree = "--recursive"
                if what == "C" then quotedSourceDir ||= "/" -- the trailing slash changes semantics: copy contents
            end
            else do
                copySubtree = ""
                if what == "D" then do
                    sourceDirName = sourceDir~name
                    destDir = .File~new(sourceDirName, destDir)
                end
                quotedSourceDir ||= "/*"
            end

            -- Ubuntu's rsync: --delete does not work without --recursive (-r) or --dirs (-d).
            -- macOS's rsync (an old BSD version 2.6.9) is more lenient about this.
            -- but Ubuntu's rsync refuses --delete when not recursive
            delete = ""
            if how == "M" & recursive then delete = "--delete-after --delete-excluded" -- An AI said it's better with these options

            exclude = "--exclude='.git' --exclude='.svn' --exclude='.gitattributes' --exclude='.gitignore' --exclude='.DS_Store' --exclude='*.zip'"

            -- Pfff... Ubuntu's rsync doesn't create directories by default????
            -- Must use --mkpath
            extra = ""
            if platform == "LINUX" then extra = "--mkpath"

            command = "rsync" archive copySubtree delete exclude extra quotedSourceDir quoted(destDir)
            if verbose then .traceOutput~say("address system" command)
            address system (command)
            end

        otherwise do
            raise syntax 48.900 array ("The" quoted(platform) "platform is not supported by copyOrMirrorDirectory")
            end
    end

    call assert RC >= 0 & RC <= successCodeMax, -
                48.900, -
                "RC =" RC || .endOfLine || -
                "An error occured while copying the directory" || .endOfLine || -
                quoted(sourceDir) || .endOfLine || -
                "to" || .endOfLine || -
                quoted(destDir)


--------------------------------------------------------------------------------
::routine "copyDirD" public
    -- copyDirD copies the directory itself (as opposed to copyDirC, which copies its contents)
    use strict arg sourceDir, destDir, recursive=.true, ignoreTopLevelDirectory=.false, verbose=.false

    -- C D: Copy Directory
    call copyOrMirrorDirectory "C", "D", sourceDir, destDir, recursive, ignoreTopLevelDirectory, verbose


--------------------------------------------------------------------------------
::routine "copyDirC" public
    -- copyDirC copies the directory contents (as opposed to copyDirD, which copies the directory itself)
    use strict arg sourceDir, destDir, recursive=.true, ignoreTopLevelDirectory=.false, verbose=.false

    -- C C: Copy Contents
    call copyOrMirrorDirectory "C", "C", sourceDir, destDir, recursive, ignoreTopLevelDirectory, verbose


--------------------------------------------------------------------------------
::routine "mirrorDirD" public
    -- mirrorDirD mirrors the directory itself (as opposed to mirrorDirC, which mirrors its contents)
    use strict arg sourceDir, destDir, recursive=.true, ignoreTopLevelDirectory=.false, verbose=.false

    -- M D: Mirror Directory
    call copyOrMirrorDirectory "M", "D", sourceDir, destDir, recursive, ignoreTopLevelDirectory, verbose


--------------------------------------------------------------------------------
::routine "mirrorDirC" public
    -- mirrorDirC mirrors the directory contents (as opposed to mirrorDirD, which mirrors the directory itself)
    use strict arg sourceDir, destDir, recursive=.true, ignoreTopLevelDirectory=.false, verbose=.false

    -- M C: Mirror Contents
    call copyOrMirrorDirectory "M", "C", sourceDir, destDir, recursive, ignoreTopLevelDirectory, verbose


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
                "An error occured while renaming the directory" || .endOfLine || -
                quoted(currentName) || .endOfLine || -
                "to" || .endOfLine || -
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
            .traceOutput~say(settings~createDir quoted(relativePath(path)))
            end
        when -1 then do
            raise syntax 48.900 array ( -
                "An error occured while creating the directory" || .endOfLine || -
                quoted(path) || .endOfLine || -
                "A file with same name already exists" -
                )
            end
        when -2 then do
            raise syntax 48.900 array ( -
                "An error occured while creating the directory" || .endOfLine || -
                quoted(path) -
                )
            end
        otherwise nop
    end
    return status


--------------------------------------------------------------------------------
::routine "changeDirectory" public
    use strict arg path, verbose=.false
    verbose |= .verbose

    path = .File~new(path)
    if verbose then .traceOutput~say("Change directory to" quoted(path)) -- don't use relativePath, I get "" when testing from script
    newDirectory = directory(path)
    call assert directory() == path, -
                48.900, -
                "directory() should be" || .endOfLine || -
                quoted(path) || .endOfLine || -
                "got" || .endOfLine || -
                quoted(directory())
    call assert newDirectory == path, -
                48.900, -
                "newDirectory should be" || .endOfLine || -
                quoted(path) || .endOfLine || -
                "got" || .endOfLine || -
                quoted(newDirectory)
    return newDirectory


--------------------------------------------------------------------------------
::routine "moveToTrash" public
    -- It's not the system trash, but the idea is the same.
    -- Don't delete permanently, move the source to cache/trash with a unique
    -- name. The unicity is implemented with a counter.
    -- source is a file or directory.
    use strict arg source, cache

    source = .File~new(source)
    if \ source~exists then return -- nothing to move

    trash = .File~new("trash", cache)
    call createDirectory trash

    sourceName = source~name
    -- search for an unused target name
    do i = 1
        target = .File~new(sourceName"-"i, trash)
        if \ target~exists then leave
    end

    settings = prettySettings()
    prettySource = quoted(relativePath(source))~left(settings~width)
    prettyTarget = quoted(relativePath(target))
    .traceOutput~say(settings~move prettySource "to" prettyTarget)

    call SysFileMove source, target
    call assert result == 0, -
                48.900, -
                "An error occured while moving the file" || .endOfLine || -
                quoted(source) || .endOfLine || -
                "to" || .endOfLine || -
                quoted(target)


--------------------------------------------------------------------------------
::routine "pushd" public
    use strict arg directory=(directory()), verbose=.false
    verbose |= .verbose

    if \ .directoryStack~isa(.Queue) then .local~directoryStack = .Queue~new
    .directoryStack~push(directory())
    call changeDirectory directory, verbose


--------------------------------------------------------------------------------
::routine "popd" public
    use strict arg verbose=.false
    verbose |= .verbose

    call assert .directoryStack~isa(.Queue), 98.900, "Internal error: popd was called before pushd"
    directory = .directoryStack~pull
    call assert .NIL \== .directory, 98.900, "Internal error: popd was called too many times (empty stack)"
    call changeDirectory directory, verbose


--------------------------------------------------------------------------------
::routine "isaTerminal" private
    -- Return .true if the specified stream is a terminal (no redirection, no pipe).
    -- streamName is "stdin", "stdout" or "stderr".
    -- if unknown platform or unknown stream, return .false.
    use strict arg streamName

    select case .RexxInfo~platform~upper
        when "WINDOWSNT" then do
            select case streamName
                when "stdin"  then "timeout 0 1>nul 2>nul" -- keep it, faster than powershell
                when "stdout" then 'powershell -NoProfile -Command "exit [int][Console]::IsOutputRedirected"'
                when "stderr" then 'powershell -NoProfile -Command "exit [int][Console]::IsErrorRedirected"'
                otherwise RC = 1 -- unknown stream
            end
        end
        when "LINUX", "DARWIN" then do
            select case streamName
                when "stdin"  then "[ -t 0 ]"
                when "stdout" then "[ -t 1 ]"
                when "stderr" then "[ -t 2 ]"
                otherwise RC = 1 -- unknown stream
            end
        end
        otherwise RC = 1 -- unknown platform
    end

    return (RC == 0)


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

-D
    Also transfer device and special files.  Shorthand for --devices --specials.

--del, --delete
    Removes files from the destination not present in the source
    (equivalent to Robocopy's /MIR). Only applicable with -r.

-g, --group
    Set the group name to match the source.
    For example, group "kristaps" with ID 1000 on a remote server is matched to
    group "kristaps" on the local machine with ID 2000.
    If --numeric-ids is also given or if the remote group name is unknown on the
    local machine, set the numeric group ID to match the source instead.

--info option to control output:
    NOT SUPPORTED on macOS :-(((
    --info=NAME: Shows the name of each file as it is transferred.
    --info=DEL: Shows files deleted if using --delete.
    --info=FLIST0: Suppresses the file list statistics (the summary you want to hide).

    Example
        rsync -a --info=NAME,DEL,FLIST0 /source/ /destination/

-l, --links
    Also transfer symbolic links.
    The link is transferred as a standalone file: if the destination does not
    exist, it will be broken.

-n, --dry-run
   Do not actually modify the destination.
   Mainly useful in combination with -v.

-o, --owner
    Set the user name to match the source, with similar matching logic as for -g.
    If --numeric-ids is also given or if the remote user name is unknown on the
    local machine, set the numeric user ID to match the source instead.
    Only works if run as root.

-p, --perms
    Set destination file or directory permissions to match the source when it is
    updated.

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

-t, --times
    Set destination file and directory modification time to match the source
    when it is updated or created.

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
