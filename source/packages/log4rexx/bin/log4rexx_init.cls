#!/usr/bin/rexx
/*
	program:          log4rexx_init.cls
	type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

	purpose:          Defines public global routines, default setup values,
                     the .LogLog, .log4rexx.Properties and .log4rexx.Timing classes.

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

	version:          1.1.1
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11
	author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
                     2009-10-29, ---rgf: adjust for new "::requires"-behaviour in ooRexx 4.0 (not
                                         reprocessing required files each time a requires is found
                                         anymore) and the missing, undocumented ".static_requires";
                                         also accounts for the ooRexx 4.0 and higher new way of
                                         defining public routines dynamically
                     2011-01-29, ---rgf: - fixed typo in tag
                                         - fixed escaping with non-standard entity (nbsp, hellip)
                                         - thanks to Wim De Paepe to report these!

	needs:	         the 'log4rexx' framework, directly requires 'log4rexx_init.cls' and
                     'log4rexx_appender.cls'

	usage:            ::REQUIRES log4rexx_init.cls

	returns:          ---
*/

PARSE SOURCE . . REQ_FILE

parse version "_" v "("    -- get version number, e.g. "4.0.0"
if v<4 then                -- only available prior to ooRexx 4.0.0 (language level < 6.02)
do
      /* the following statement makes sure that this module is loaded only once,
         no matter how many times it got required (but note: if CALLing this file,
         each call will work and re-setup everything) */
   .STATIC_REQUIRES~put(time("C"), REQ_FILE~translate)

      /* the following code will make all floating methods available as
         globally public routines, undocumented pre-ooRexx-4.0 behaviour */
   do PUB_RTN over .METHODS
      .PUBLIC_ROUTINES~put(.METHODS[PUB_RTN], PUB_RTN)
   end
end
else     -- in ooRexx 4.0 or higher we define the public methods differently
do
   thisPackage=.context~package
   do idx over .methods
      -- routine=.routine~new(idx, .methods[idx]~source)
      routine=.routine~new("DYNAMICALLY_CREATED_"idx, .methods[idx]~source)
      thisPackage~addPublicRoutine(idx, routine)
   end
end

/* If this module is required, due to using the "static_requires" feature,
   public classes are not put into .local, hence we need to do that
   ourselves (then, we could also store a reference in .local as well), if
   we want other programs that do not require this module to have access to them.
*/
.local~LogLog          =.LogLog           -- the LoLog class
-- .local~log4rexx.timing    =.log4rexx.timing     -- the log4rexx.timing class
.local~log4rexx.properties=.log4rexx.properties -- the log4rexx.properties class


.LogLog~debug("in" pp(req_file) "...")

if \.log4rexx~isInstanceOf(.directory) then  -- ".LOG4REXX" directory entry does not exist yet
   .local~log4rexx=.directory~new      -- create one

if \.log4r~isInstanceOf(.directory) then
   .local~log4r=.log4rexx           -- allow access to the directory via this shorter name


   /*
      define log levels and their numerical values (in case someone wants to add levels
      in between); could be that ".log4r" got created by the calling/requiring program
      to set debug and configfile name
   */
if \.log4rexx~hasentry("STARTUPDATETIME") then
do
   .LogLog~debug(pp(req_file) "- setting up '.log4r' log level entries...")

   .log4rexx~startupDateTime=date("S",,,"-") time("L")  -- save startup date and time

   .log4rexx~logLevel.lowest =   0; .log4rexx~lowest =   0; -- lowest possible logLevel
   .log4rexx~logLevel.all    =   0; .log4rexx~all    =   0; -- will log all
   .log4rexx~logLevel.trace  =1000; .log4rexx~trace  =1000; .log4rexx~1000 ="TRACE"
   .log4rexx~logLevel.debug  =2000; .log4rexx~debug  =2000; .log4rexx~2000 ="DEBUG"
   .log4rexx~logLevel.info   =3000; .log4rexx~info   =3000; .log4rexx~3000 ="INFO"
   .log4rexx~logLevel.warn   =4000; .log4rexx~warn   =4000; .log4rexx~4000 ="WARN"
   .log4rexx~logLevel.error  =5000; .log4rexx~error  =5000; .log4rexx~5000 ="ERROR"
   .log4rexx~logLevel.fatal  =6000; .log4rexx~fatal  =6000; .log4rexx~6000 ="FATAL"
   .log4rexx~logLevel.off    =7000; .log4rexx~off    =7000; -- will not log any
   .log4rexx~logLevel.none   =7000; .log4rexx~none   =7000; -- will not log any
   .log4rexx~logLevel.highest=7000; .log4rexx~highest=7000; -- highest possible logLevel

      -- determine names to use, if displaying logLevels with the values "0" and "7000"
   -- .log4rexx~   0 ="LOWEST"
   -- .log4rexx~7000 ="HIGHEST"
   -- .log4rexx~7000 ="NONE"
   .log4rexx~   0 ="ALL"
   .log4rexx~7000 ="OFF"
end

   -- static fields "LINE_SEP" and "LINE_SEP_LEN" in "org.apache.log4j.Layout"
   -- instead storing it as "LINE.SEP" and "LINE.SEP.LEN" in .log4r
if \.log4rexx~hasindex("LINE.SEP") then   -- instead of defininig it as class attributes in Local
do
   opsys=SysVersion()~translate        -- get the operating system version information
   -- CR="0d"x                         -- used to be the case for the old Mac OS, but not on Darwin anymore

   if wordpos(opsys~left(2), "WI OS DO") then -- WIndows, OS/2, DOs
   do
      .log4rexx~line.sep="0d0a"x          -- CRLF
      .log4rexx~file.sep="\"
      .log4rexx~path.sep=";"
      .log4rexx~opsys.kind="WINDOWS"      -- indicate kind of operating system
   end
   else                                -- assume Unix-based opsys
   do
      .log4rexx~line.sep="0a"x            -- LF only
      .log4rexx~file.sep="/"
      .log4rexx~path.sep=":"
      .log4rexx~opsys.kind="UNIX"         -- indicate kind of operating system
   end

   .log4rexx~line.sep.len=.log4rexx~line.sep~length   -- set length
end


if \.log4rexx~hasentry("markup.from") then   -- SGML entities to be replaced not yet defined
do
      -- escapeMarkup
   .log4rexx~markup.from=.array~of("&"    , "<"   , ">"   , '"'     , "'"     )
   -- .log4rexx~markup.to  =.array~of("&amp;", "&lt;", "&gt;", '&quot;', "&apos;")
   -- uses hexadecimal value for "apos" as MSIE would not show an apostrophe in HTML mode
   .log4rexx~markup.to  =.array~of("&amp;", "&lt;", "&gt;", '&quot;', "&#x0027;")
end

if \.log4rexx~hasentry("TIMING.OBJ") then    -- no timing object as of yet, create it!
   .log4rexx~timing.obj=.log4rexx.Timing~new



.LogLog~debug(pp(req_file) "- setting up default 'log4r' values in .local...")

width=40
leadIn="   "
   -- determines whether Log's 'log' method executes asynchroneously
tmpName="log4rexx.config.asyncMode"
if \.local~hasentry(tmpName) then   -- log4rexx: inherent feature
   .local~setentry(tmpName, .false) -- execute asynchroneously Log's 'log' method?
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))

   -- path2 properties filename
tmpName="log4rexx.config.configFile"
if \.local~hasentry(tmpName) then   -- cf. "log4j.properties"
   .local~setentry(tmpName, .nil)   -- indicate that not set
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))
   -- if not set, searched for "log4rexx.properties" in

   -- determines interval in secs to check whether configuration file has changed
tmpName="log4rexx.config.configFileWatchInterval"  -- set to 0 to not check property file for changes
if \.local~hasentry(tmpName) then   -- cf. "org.apache.commons.logging.helpers.FileWatchdog"
   .local~setentry(tmpName, 0)      -- by default: do not check for changes

.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))

   -- global disabling of logging at a certain level or lower
   -- global setting affecting all loggers: disables logs of this level or lower
tmpName="log4rexx.config.disable"
if \.local~hasentry(tmpName)  then  -- cf. "log4j.disable"
   .local~setentry(tmpName, .log4rexx~LOWEST)  -- LOWEST, TRACE, DEBUG, INFO, WARN, ERROR, FATAL, HIGHEST
val=.local~entry(tmpName)
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(val) "("pp(.log4rexx~entry(val))")" )

   -- if ".true" then 'log4rexx.config.disable' is not honored (it is ignored)
tmpName="log4rexx.config.disableOverride"
if \.local~hasentry(tmpName) then   -- cf. "log4j.disableOverride"
   .local~setentry(tmpName, .false)
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))



   -- determines Log class name to use for creating Log instances, should never change
tmpName="log4rexx.config.LoggerFactoryClassName"
if \.local~hasentry(tmpName) then   -- cf. "log4j.factory"
   .local~setentry(tmpName, "NoOpLog")      -- indicate that not set

.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))


   -- show debug statements for the log4rexx framework itself? (LogLog will honor it)
tmpName="log4rexx.config.LogLog.debug"        -- .LogLog will honor this
if \.local~hasentry(tmpName) then   -- cf. "log4j.debug"
   .local~setentry(tmpName, .false)
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))


tmpName="log4rexx.config.LogLog.quietMode"    -- .LogLog will honor this
if \.local~hasentry(tmpName) then   -- cf. "log4j.debug"
   .local~setentry(tmpName, .false)
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))

   -- version of the 'log4r' framework in the form "abb.yyyymmdd"
tmpName="log4rexx.config.version"
if \.local~hasentry(tmpName) then   -- 'log4r'
   .local~setentry(tmpName, 101.20070423)
.LogLog~debug(leadin left("'."tmpName"'", width, ".") pp(.local~entry(tmpName)))




-- =====================================================================
-- =====================================================================
-- =====================================================================
/* The following floating methods are used to incorporate them as globally
   visible routines upon initialization of this module.
*/


-- =====================================================================
-- if argument will be returned, prepended with "an " or "a ", depending
-- whether argument starts with a vowel (AEIOU) or not
::method a_or_an
  parse arg val .
  if pos(val~left(1)~translate, "AEIOU")>0 then
     return "an" val
  else
     return "a" val


-- =====================================================================
-- accepts either logLevel symbol/string or number, returns number
::method getLogLevelAsNumber
  parse upper arg tmpVal .

  if datatype(tmpVal, "W") then
  do
     numVal=tmpVal
     strVal=.log4rexx~entry(numVal)          -- get index
     if .nil=strVal then
        return .nil
     if .log4rexx~entry(strVal)=numVal then  -- same numeric value?
        return numVal
  end
  else
  do
     strVal=tmpVal
     numVal=.log4rexx~entry(tmpVal)          -- get index
     if .nil=numVal then
        return .nil

     strVal2=.log4rexx~entry(numVal)         -- get index
     if strVal2~isInstanceOf(.String) then
     do
        if strVal=strVal2 then            -- o.k. same value
           return numVal

        -- maybe received string is a synonym? (e.g. ALL/LOWEST)
        if .log4rexx~entry(strVal2)=numVal then
           return numVal
     end
  end
  return .nil


-- =====================================================================
-- accepts either logLevel symbol/string or number, returns string (name of logLevel)
::method getLogLevelAsString
  parse upper arg tmpVal .

  if datatype(tmpVal, "W") then
  do
     numVal=tmpVal
     strVal=.log4rexx~entry(numVal)          -- get index
     if .nil=strVal then
        return .nil
     if .log4rexx~entry(strVal)=numVal then  -- same numeric value?
        return strVal
  end
  else
  do
     strVal=tmpVal
     numVal=.log4rexx~entry(tmpVal)          -- get index
     if .nil=numVal then
        return .nil

     strVal2=.log4rexx~entry(numVal)         -- get index
     if strVal2~isInstanceOf(.String) then
     do
        if strVal=strVal2 then            -- o.k. same value
           return strVal

        -- maybe received string is a synonym? (e.g. ALL/LOWEST)
        if .log4rexx~entry(strVal2)=numVal then
           return strVal
     end
  end
  return .nil


-- =====================================================================
-- returns .true, .false or .nil, if not a logical value
::method getLogicalValue
  parse upper arg val .

  if datatype(val, "O") then     -- a logical value in hand already, return it
     return val

  wpos=wordpos(val, "TRUE .TRUE FALSE .FALSE")

  if wpos=0 then return .nil     -- return .nil to indicate that we received no logical value

  return wpos<3                  -- retuns .true or .false, accordingly


-- =====================================================================
-- reads the log4rexx settings from .local and returns it as a log4rexx.properties object
::method getLog4rSettingsFromEnvironment

  props=.log4rexx.properties~new
  entries=.list~of("log4rexx.config.asyncMode"                    , -
                   "log4rexx.config.configFile"                   , -
                   "log4rexx.config.configFileWatchInterval"      , -
                   "log4rexx.config.disable"                      , -
                   "log4rexx.config.disableOverride"              , -
                   "log4rexx.config.LoggerFactoryClassName"       , -
                   "log4rexx.config.LogLog.debug"                 , -
                   "log4rexx.config.LogLog.quietMode"             , -
                   "log4rexx.config.version"                      )

  do idx over entries
     props~setentry(idx, .local~entry(idx))
  end
  return props



-- =====================================================================
-- ::routine pp
::method pp
  return "[" || arg(1)~string || "]"


-- =====================================================================
/* return hashvalue of object, or if .nil, the string "[.nil]" */
-- ::routine ppObj public
::method ppObj
  use arg o
  if .nil=o then return "[.nil]"~left(10)
  return pp(o~'=='~c2x)


-- =====================================================================
   /* escape XML/HTML meta-chars using SGML entities  */
::method escapeMarkupChars
-- ::routine escapeMarkupChars   public
  parse arg str

  from=.log4rexx~markup.from
  to  =.log4rexx~markup.to

  do i=1 to from~items
     str=str~changestr(from[i], to[i])
  end
  return str


-- =====================================================================
   /* escape XML/HTML meta-chars using SGML entities  */
-- ::routine "toNBSP" public
::method "toNBSP"
  parse arg str

  return str~changestr(" ", "&#xa0;")


-- =====================================================================
   /* wrap string as CDATA section, not checking whether string contains "]]>";
      it is the responsiblity of the programmer to not supply that end-of-CDATA-section
      string in "message" or "additional"
   */
::method wrapAsCDATA
-- ::routine wrapAs_CDATA     public
  return "<![CDATA[" || arg(1)~string || "]]>"



-- =====================================================================
::method formatDirectoryObject

/* Sorts the keys in ascending order, and then creates and returns a text (default),
   HTML ("h") or XML ("x") encoded string.
*/
-- ::routine formatDirectoryObject public      /* dump condition object */
   use arg co, kind, bIsCondition   -- co ... condition object, kind ... T(ext=default), H(tml), X(ml)

   kidx=kind~left(1)~translate
   if pos(kidx, "THX")=0 then       -- default to returning plain text
      kidx="T"

   bIsCondition=(bIsCondition=.true)   -- is this a condition directory object ?

   -- stem.=sortIndices(co)
   stem.=sortByIndex(co)            -- sort by index
   len=length(stem.0)
   indent1=12
   sumIndent=len+indent1+2

   blanks=copies(" ", sumIndent) "--> "
   res=.mutableBuffer~new
   NL=.log4rexx~line.sep
   TAB1="09"x
   TAB2=TAB1~copies(2)
   TAB3=TAB1~copies(3)
   TAB4=TAB1~copies(4)

   if kidx="H" then
   do
      if bIsCondition then    -- a condition object?
         res~~append(TAB2) ~~append(TAB1) ~~append('<table class="coll condition">  <!-- COLLECTION OBJECT ! -->') ~~append(NL)
      else
         res~~append(TAB2) ~~append(TAB1) ~~append('<table class="coll">            <!-- COLLECTION OBJECT ! -->') ~~append(NL)
   end
   else if kidx="X" then
   do
      if bIsCondition then    -- a condition object?
         res~~append(TAB2) ~~append(TAB1) ~~append('<log4rexx:CollectionObject type="condition">  <!-- COLLECTION OBJECT ! -->') ~~append(NL)
      else
         res~~append(TAB2) ~~append(TAB1) ~~append('<log4rexx:CollectionObject>                   <!-- COLLECTION OBJECT ! -->') ~~append(NL)
   end

   do i=1 to stem.0
      o=co~entry(stem.i)
      if o~hasmethod('ITEMS') then items=o~items
                              else items=""

      tmpString=.MutableBuffer~new

      if kidx="T" then        -- plain text rendering
      do
         -- would show sequence number of (sorted) entry
         -- tmpString~~append(TAB3) ~~append((i~right(len))"." (stem.i~left(indent1,"."))) ~~append(pp(o))
         tmpString~~append(TAB3) ~~append(stem.i~left(indent1,".")) ~~append(pp(o))
         if items<>"" then tmpString~~append(" containing ") ~~append(items) ~~append(" item(s)")
      end
      else if kidx="H" then   -- HTML rendering
      do
         tmpString~~append(TAB2) ~~append(TAB2) ~~append('<tr class="coll">')        ~~append(NL)
         -- would show sequence number of (sorted) entry
         -- tmpString~~append(TAB3) ~~append('<td class="coll entryNr">')~~append(i) ~~append(NL)
         tmpString~~append(TAB2) ~~append(TAB3) ~~append('<td class="coll index">')  ~~append(stem.i) ~~append(NL)
         tmpString~~append(TAB2) ~~append(TAB3) ~~append('<td class="coll item">')   ~~append(escapeMarkupChars(pp(o)))

         if items<>""  then tmpString~~append(" containing ")~~append(items)~~append(" item(s)")
         tmpString~~append(NL)
      end
      else if kidx="X" then   -- XML rendering
      do
         tmpString~~append(TAB2) ~~append(TAB2) ~~append('<log4rexx:entry nr="'i'">')   ~~append(NL)
         /*
         -- would show sequence number of (sorted) entry
         tmpString~~append(TAB3) ~~append('<log4rexx:entryNr nr="'i'">') ~~append(i)      -
                                 ~~append('</log4rexx:entryNr>')~~append(NL)
         */
         tmpString~~append(TAB2) ~~append(TAB3) ~~append('<log4rexx:index nr="'i'">')   ~~append(stem.i) -
                                 ~~append('</log4rexx:index>')  ~~append(NL)
         tmpString~~append(TAB2) ~~append(TAB3) ~~append('<log4rexx:item nr="'i'">')   ~~append(escapeMarkupChars(pp(o)))
         if items<>""  then tmpString~~append(" containing ")~~append(items)~~append(" item(s)")
      end

      if res~length=0 then    -- first value to assign
      do
         res~~append(tmpString~string)
      end
      else                    -- value already available
      do
         res~~append(NL) ~~append(tmpString~string)
      end

      if items<>"" then       -- a collection object in hand?
      do
         if kidx="H" then
         do
            if items>0 then
               res ~~append(TAB2) ~~append(TAB4) ~~append('<span class="subitem">')~~append(NL)
         end
         nr=0
         do item over o       -- list items
            nr=nr+1
            if kidx="T" then
            do
               res~~append(NL) ~~append(TAB3) ~~append(blanks) ~~append(pp(item))
            end
            else if kidx="H" then
            do
               -- res ~~append(TAB2) ~~append(TAB4) ~~append("<br>") ~~append("&hellip; ") - -- ~~append("&nbsp;&nbsp;&nbsp;") -
               -- res ~~append(TAB2) ~~append(TAB4) ~~append("   <br>") ~~append("&nbsp;&nbsp;&nbsp;") - -- ~~append("&nbsp;&nbsp;&nbsp;") -
               --     ~~append(escapeMarkupChars(pp(item))~changestr(" ", "&nbsp;")) ~~append(NL)
               res ~~append(TAB2) ~~append(TAB4) ~~append("   <br>") ~~append("&#xa0;&#xa0;&#xa0;") -
                   ~~append(escapeMarkupChars(pp(item))~changestr(" ", "&#xa0;")) ~~append(NL)
            end
            else if kidx="X" then
            do
               if nr=1 then
                  res~~append(NL)

               res~~append(TAB2)  ~~append(TAB4) ~~append('<log4rexx:subitem nr="'nr'">')  -
                                  ~~append(escapeMarkupChars(pp(item))~changestr(" ", "&#xa0;"))  -
                                  ~~append("</log4rexx:subitem>") ~~append(NL)
               -- if nr=items then res ~~append(TAB3)
            end
         end

         if kidx="H" then
         do
            if items>0 then
               res ~~append(TAB2) ~~append(TAB4) ~~append('</span>')~~append(NL)
         end
         if kidx<>"H" then res ~~append(TAB3)
      end

      if kidx="H" then
      do
         res~~append(TAB2) ~~append(TAB2) ~~append('</tr>') ~~append(NL)
      end
      else if kidx="X" then
      do
         res~~append(TAB2) ~~append('</log4rexx:item>') ~~append(NL)
         res~~append(TAB2)  ~~append(TAB2) ~~append('</log4rexx:entry>')  ~~append(NL)
      end

   end

   if kidx="H" then
   do
      res~~append(TAB2) ~~append(TAB1) ~~append('</table>                  <!-- COLLECTION OBJECT ! -->') ~~append(NL)
   end
   else if kidx="X" then
   do
      res~~append(TAB2) ~~append(TAB1) ~~append('</log4rexx:CollectionObject> <!-- COLLECTION OBJECT ! -->') ~~append(NL)
   end

   return res~string


pp: procedure
   use arg a
   if .nil=a then return "[.nil]"
   return "[" || a~string || "]"


-- sortIndices: procedure
::method sortByIndex -- running 'test5ConsoleAppender.rex'
  use arg co

  stem.="0"          -- define default value
  i=0                -- get all indices first, sort them into ascending order
  do idx over co
    i=i+1
    stem.i=idx       -- save index
  end
  stem.0=i

  call sysStemSort "stem.", "A", "I"  -- ascending, ignore case
  return stem.



-- sortIndices: procedure
-- bug in 3.1.2-RC1 with condition object, hence commented for the time being
::method sortByIndex_Supplier_Not_Accepted4ConditionObject -- running 'test5ConsoleAppender.rex'
  use arg co

  stem.="0"          -- define default value
  i=0                -- get all indices first, sort them into ascending order
  s=co~supplier      -- get the supplier object
  do while s~available
    i=i+1
    stem.i=s~index   -- save index
    s~next
  end
  stem.0=i

  call sysStemSort "stem.", "A", "I"  -- ascending, ignore case
  return stem.

::method sortByItem
  use arg co

  stem.="0"          -- define default value
  i=0                -- get all indices first, sort them into ascending order
  s=co~supplier      -- get the supplier object
  do while s~available
    i=i+1
    stem.i=s~item    -- save item
    s~next
  end
  stem.0=i

  call sysStemSort "stem.", "A", "I"  -- ascending, ignore case
  return stem.


-- =====================================================================
   /* formats elapsed time in the form of "s.mmmmmm" */
-- ::routine formatElapsedSeconds   public
::method formatElapsedSeconds
  parse arg startBaseDays startSecs secsPerDay nowBaseDays nowSecs

  numeric digits 20     -- in case we have very long running timings

  if nowSecs<startSecs then      -- day rolled over?
  do
     nowSecs=nowSecs+secsPerDay
     nowBaseDays=nowBaseDays-1
  end

  if nowBaseDays=startBaseDays then
     return nowSecs-startSecs

  return (nowBaseDays-startBaseDays)*secsPerDay+(nowSecs-startSecs)

-- =====================================================================
-- ::routine formatElapsedWithDays  public
::method formatElapsedWithDays
  parse arg startBaseDays startSecs secsPerDay nowBaseDays nowSecs

  numeric digits 20     -- in case we have very long running timings
  if nowSecs<startSecs then      -- day rolled over?
  do
     nowSecs=nowSecs+secsPerDay
     nowBaseDays=nowBaseDays-1
  end

  parse value (nowSecs-startSecs) with secs "." -0 msecs
  return nowBaseDays-startBaseDays time("N", secs, "S") || msecs








-- =====================================================================
-- =====================================================================
/* Do *NOT* move the next class ("LogLog"), it must be initialized first,
   in order for LogLog being operational in log4r-framework code!

   The 'LogLog' class allows the 'log4r' framework classes to use 'debug',
   'warn' and 'error' log messages:

   - .log4rexx.config.LogLog.debug     - if .true, 'debug' messages are displayed
   - .log4rexx.config.LogLog.quietMode - if .true, no messages are displayed not even
                                     'warn' and 'error' messages

*/

/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
/* cf. <org.apache.log4j.helpers.LogLog> */
::class "LogLog"  public         -- logger for log4rexx classes/modules, which cannot use log4rexx itself

::method init           class

   -- entry in .local which controls whether .LogLog should display 'debug' messages
  key="log4rexx.CONFIG.LogLog.debug"
  val=.false                     -- default value, if missing
  if \.local~hasentry(key) then
     .local~setEntry(key,val)

   -- entry in .local which controls whether .LogLog should display 'warn' or 'error' messages
  key="log4rexx.CONFIG.LogLog.quietMode"
  val=.false                  -- default value, if missing: show 'warn' and 'error' messages
  if \.local~hasentry(key) then
     .local~setEntry(key,val)

  if .log4rexx.config.LogLog.debug then
  do
     self~debug("LogLog.INIT(): '.log4rexx.config.LogLog.debug'=".log4rexx.config.LogLog.debug","    -
                               "'.log4rexx.config.LogLog.quietMode'=".log4rexx.config.LogLog.quietMode)
  end


::method debug          class       -- goes to .output
  if \.log4rexx.config.LogLog.Debug then return     -- only show, if log4rexx.config.LogLogDebug is enabled
  if .log4rexx.config.LogLog.QuietMode then return  -- if quietMode explicitly set, then do not show log

  use arg msg, co
  .output~~charout("log4rexx.DEBUG: ")~~say(msg)
  if arg(2,"E") then                -- condition object or additional object supplied?
     self~additional_output(.output, co)


::method error          class       -- goes to .error; will be shown independent of 'debugEnabled'
  if .log4rexx.config.LogLog.QuietMode then return  -- if quietMode explicitly set, then do not show log

  use arg msg, co
  .error~~charout("log4rexx.ERROR: ")~~say(msg)
  if arg(2,"E") then                -- condition object or additional object supplied?
     self~additional_output(.error, co)


::method warn           class       -- goes to .error; will be shown independent of 'debugEnabled'
  if .log4rexx.config.LogLog.QuietMode then return  -- if quietMode explicitly set, then do not show log

  use arg msg, co
  .error~~charout("log4rexx.WARN:  ")~~say(msg)
  if arg(2,"E") then                -- condition object or additional object supplied?
     self~additional_output(.error, co)


::method additional_output   class private -- output supplied conditional or additional object
  use arg stream, co                -- use supplied stream for outpt

  if arg(2)~isInstanceOf(.directory) then -- condition object or additional string?
     stream~~charout("09"x)~~say(formatDirectoryObject(co))
  else
     stream~~charout("09"x)~~say(co~string)


/* ------------------------------------------------------------------------------ */
   /* Class to allow taking individual timings. */
::class "Log4rexx.Timing"  public

::method init           -- constructor
  expose secsPerDay
  secsPerDay=86400      -- 24*60*60
  self~reset            -- set to this day and moment in day

::method startBaseDays  attribute
::method startSecs      attribute


::method startDate      -- return sorted date, optionally delimited with optional character
  expose startBaseDays
  parse arg char

  if arg(1,"Omitted") then char="-" -- default to "-", if argument not given
  return date("S", startBaseDays, "B", char) /* return as "YYYY[char]MM[char]DD"  */


::method startTime      -- return time formatted in military format
  expose startSecs

  parse var startSecs secs "." -0 msecs
  return time("N", secs, "S") || msecs       /* return as "HH:MM:SS.mmmmmm"      */


::method reset          -- reset to actual date and time
  expose startBaseDays startSecs

  parse value date("B") time('S') time('L') with baseDays secs . '.' -0 msecs
  startBaseDays=baseDays
  startSecs    =secs||msecs


::method elapsedSeconds -- return elapsed seconds in the form: "secs.mmmmmm"
  expose startBaseDays startSecs secsPerDay

  numeric digits 20     -- in case we have very long running timings
  parse value date("B") time('S') time('L') with nowBaseDays secs . '.' -0 msecs
  nowSecs=secs||msecs

  if nowSecs<startSecs then      -- day rolled over?
  do
     nowSecs=nowSecs+secsPerDay
     nowBaseDays=nowBaseDays-1
  end

  if nowBaseDays=startBaseDays then
     return nowSecs-startSecs

  return (nowBaseDays-startBaseDays)*secsPerDay+(nowSecs-startSecs)


::method elapsedWithDays-- return elapsed time in the format: "days hh:mm:ss.nnnnnn"
  expose startBaseDays startSecs secsPerDay

  parse value date("B") time('S') time('L') with nowBaseDays secs . '.' -0 msecs
  nowSecs=secs||msecs

  if nowSecs<startSecs then      -- day rolled over?
  do
     nowSecs=nowSecs+secsPerDay
     nowBaseDays=nowBaseDays-1
  end

  parse value (nowSecs-startSecs) with secs "." -0 msecs
  return nowBaseDays-startBaseDays time("N", secs, "S") || msecs


::method elapsed                 -- meant to get the data needed for the formatting routines
  expose startBaseDays startSecs secsPerDay
  parse value date("B") time('S') time('L') with nowBaseDays secs . '.' -0 msecs
  nowSecs=secs||msecs

  return startBaseDays startSecs secsPerDay nowBaseDays nowSecs




-- =====================================================================
   /* Return the value of an entry named "key" from the property directory,
      if not available, return supplied "defaultValue" for it (defaults to .nil).
   */

::class "Log4rexx.Properties"    subclass directory public

::method getPropertyValue     -- retrieve a value, optionally supplying a default value
  use arg key, defaultValue

  if self~hasentry(key) then  -- entry available, return value
     return self~entry(key)

  if arg(2, "Omitted") then   -- no default value supplied
     return .nil

  return defaultValue         -- return default value

   /* return true, if both directories have the same amount of entries, and each
      key has the same value in both collections */
::method "equal"              -- comparison operator (equality)
  use arg otherDir
  -- .LogLog~debug(self~string": running method 'equal', self:" ppObj(self) "otherDir:" ppObj(otherDir))

  if self~items<>otherDir~items then   -- cannot be equal
     return .false

  do key over propDir
     if otherDir[key]\=self[key] then
        return .false
  end
  return .true                -- equal

   /* return true, if both directories have the same amount of entries, and each
      key has the same value in both collections */
::method "same"               -- comparison operator (identity)
  use arg otherDir

  -- .LogLog~debug(pp("log4rexx.properties")", method 'same', self:" ppObj(self) "otherDir:" ppObj(otherDir))
  if .nil=otherDir then return .false

  if self~items<>otherDir~items then   -- cannot be equal, hence not identical
     return .false

  do key over propDir
     if otherDir[key]\==self[key] then
        return .false
  end
  return .true                -- identical



   /* Read the content of a property file in the form of "key=value", where
      "key" and "value" are strings. Empty lines or lines starting with
      a hash ("#") or a semi-colon (";") are ignored.
      Returns a directory object representing the properties file.
   */
::method readPropertyFile class
  parse arg fileName

  dir=.log4rexx.properties~new      -- create an instance
  if fileName="" then            -- no filename given, return empty property
     return dir

  if stream(fileName, "C", "QUERY EXISTS")="" then -- file does not exist
     return dir                  -- return empty directory

  signal on notready
  s=.stream~new(fileName)~~open("READ")
  do forever
     line=s~linein
     if line="" then iterate        -- empty line, ignore it
     parse var line key . "=" value -- removes spaces around "key", if any
     if pos(key~left(1), "#;!")>0 then iterate  -- a comment, ignore it
     if key~left(2)="--" then iterate           -- a line comment, ignore it

     -- dir~setentry(key, value)    -- save key in uppercase, do not touch value
     tmpVal=value~strip~translate
     pos=wordpos(tmpVal, ".TRUE TRUE 1 .FALSE FALSE 0")
     if pos>0 then
     do
        if pos>3 then dir~setentry(key, 0)      -- .false
                 else dir~setentry(key, 1)      -- .true
     end
     else
        dir~setentry(key, value)    -- save key in uppercase, do *not* strip value
  end

notready:
  s~close
  return dir                     -- return directory


/*

Choice of:

------------------------ Apache Version 2.0 license -------------------------
   Copyright 2007 Rony G. Flatscher

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-----------------------------------------------------------------------------

or:

------------------------ Common Public License 1.0 --------------------------
   Copyright 2007 Rony G. Flatscher

   This program and the accompanying materials are made available under the
   terms of the Common Public License v1.0 which accompanies this distribution.

   It may also be viewed at: http://www.opensource.org/licenses/cpl1.0.php
-----------------------------------------------------------------------------

See also accompanying license files for full text.

*/
