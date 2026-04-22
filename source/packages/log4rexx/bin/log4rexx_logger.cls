#!/usr/bin/rexx
/*
	program:          log4rexx_logger.cls
	type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

	purpose:          Defines the logger classes .Log, .SimpleLog and .NoOpLog.

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

	version:          1.1.0
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11
	author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
                     2009-10-29, ---rgf: adjust for new "::requires"-behaviour in ooRexx 4.0 (not
                                         reprocessing required files each time a requires is found
                                         anymore) and the missing, undocumented ".static_requires"

	needs:	         the 'log4rexx' framework, directly requires 'log4rexx_init.cls' and
                     'log4rexx_appender.cls'

	usage:            ::REQUIRES log4rexx_logger.cls

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
end

.LogLog~debug("in" pp(req_file) "...")


::requires "log4rexx_init.cls"         -- initialize the log4rexx environment, create LogLog class
::requires "log4rexx_appender.cls"     -- get access to appenders



/* ------------------------------------------------------------------------------ */
/* This is the standard implementation of "Log".

   Simple Log class that outputs log messages to .error (stderr). Class attributes
   "showDateTime", "showLogName", "showShortName", "currentLogLevel" can be used
   to control the formatting options and log level (to retrieve the numeric log
   level value send one of the messages "trace", "debug", "info", "warn",
   "error", "fatal" to ".log4r" and set "currentLogLevel" to it; to not  show
   any log messages set the log level to ".log4rexx~OFF"), default: ".log4rexx~warn".
*/
::class "Log"  public

::method init
  expose logLevel additivity name shortName timer appenderQueue logQueue parent logNr
  parse arg name                 -- get name, if any

     -- logQueue which helps keep correct sequence in asynchroneous handling of log messages
  logQueue=.queue~new
  parent=.nil                    -- if additivity=1, then points to "parent" logger
  logNr=0                        -- initialize logNr value

  if name<>"" then               -- if name explicitly given, use it
  do
     self~name=name              -- set "name" value
     pos=lastpos(".", name)      -- get last position of "."
     if pos>0 then shortName=substr(name, pos+1)
              else shortName=name
  end
  else   -- create a default log name, using the class ID value
  do
     shortName=self~class~id
     name="fallback."shortName || ".created_at_" || date("S") || "_" || (time()~changestr(":",""))
  end

  timer=.log4rexx~timing.obj        -- set default timer: use global timing object
  logLevel  =.log4rexx~debug        -- set default value: ignore logs at trace logLevel
  appenderQueue=.queue~new       -- queue of appenders to log to altogether (contains inherited appenders)

  additivity=.false              -- set value to force setup in next assignment

  if name~translate<>"ROOTLOGGER" then
     self~additivity=.true

   .LogLog~debug(pp("Log")", *** 'init' for" pp(a_or_an(self~class~id)":" name))


::method unknown
  expose name
  use arg msgName, args

  strArgs=""
  if .nil<>args then
  do
     strArgs="with" args~items "supplied argument(s)"
     if args~items>0 then
     do
        strArgs=strArgs": "
        bComma=.false
        do item over args
           if bComma then
              strArgs=strArgs", "
           else
              bComma=.true
           strArgs=strArgs || pp(item)
        end
     end
  end

  if name="" then
     tmpStr=self~string
  else
     tmpStr=a_or_an(self~class~id)":" name

  tmpStr=pp(self~class~id) "UNKNOWN message" pp(msgName) strArgs "received for" pp(tmpStr) "!"
  .LogLog~error(tmpStr)


::method additivity              -- getter, forward to appenders in "parent loggers" ?
  expose additivity
  return additivity


::method "additivity="           -- setter
  expose additivity name parent
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("Log")", 'additivity=' for" pp(a_or_an(self~class~id)":" name)": argument not logical, received:" newValue)
     return
  end

  if additivity=logicalValue then    -- nothing has changed, leave everything in place
     return

  if name~translate="ROOTLOGGER" then  -- do not change additivity value of "rootLogger"
     return

  additivity=logicalValue

  if additivity then             -- "inherit" appenders
     self~setUpParent
  else                           -- no "parent" logger, whose appenders we need to serve
     parent=.nil


::method appenderQueue  attribute


::method addAppender
  expose appenderQueue name
  use arg app
  if app~isInstanceOf(.Appender) then
     appenderQueue~queue(app)    -- add an appender to the queue
  else
     .LogLog~error(pp("Log")", 'addAppender' for" pp(a_or_an(self~class~id)":" name)", argument not an appender, received:" pp(app))


::method clearAppenderQueue
  expose appenderQueue
  appenderQueue=.queue~new


::method configure                     -- configure this instance of a Log-Logger
  expose name additivity appenderQueue
  use arg properties                   -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  val=properties~getPropertyValue("LOG4REXX.LOGGER."name".ADDITIVITY", additivity)
  val=val~strip
  if additivity<>val then
     self~additivity=val

  val=properties~entry("LOG4REXX.LOGGER."name)
  if .nil<>val then                    -- appenders to configure?
  do
     parse var val tmpLogLevel . "," appenderList
     self~logLevel=tmpLogLevel

     tmpQueue=.queue~new
     do while appenderList<>""         -- create queue with appenders we need for this logger
        parse var appenderList app . "," appenderList
        tmpQueue~queue(app)
     end

     bReset=(appenderQueue~items<>tmpQueue~items)  -- different amount of appenders

      -- do we have the same appender names in the same sequence?
     do i=1 to appenderQueue~items while \bReset
        bReset=(appenderQueue[i]~name<>tmpQueue[i])
     end

     if bReset then                    -- we need to reset the appenderQueue
     do
        .LogLog~debug(pp("Log")", 'configure' for" pp(a_or_an(self~class~id)":" name)": appender queue changed, resetting it")
        oldAppenderQueue=appenderQueue
        self~clearAppenderQueue        -- clear present queue
        appDir=.LogManager~appenderDir

        bError=.false
        do tmpAppName over tmpQueue    -- iterate over appender names this logger must use
           if appDir~hasentry(tmpAppName) then           -- does appender exist?
              self~addAppender(appDir~entry(tmpAppName))
           else
           do
              bError=.true
              .LogLog~error(pp("Log")", 'configure' for" pp(a_or_an(self~class~id)":" name)": appender" pp(tmpAppName) "does not exist!")
           end
        end

        if bError then              -- leave old in place
        do
           appenderQueue=oldAppenderQueue
           .LogLog~debug(pp("Log")", 'configure' for" pp(a_or_an(self~class~id)":" name)": new appender queue in error, reset to previous queue!")
        end
     end
  end


   -- attribute method instead of "setLevel" and "getLevel" !
::method logLevel                      -- getter
  expose logLevel
  return logLevel

::method "logLevel="                   -- setter
  expose logLevel name

  tmpVal=getLogLevelAsNumber(arg(1))
  if .nil=tmpVal then
  do
     .LogLog~error(pp("Log")", 'logLevel=' for" pp(a_or_an(self~class~id)":" name)": illegal argument, received:" pp(arg(1)))
     return
  end
  logLevel=tmpVal                  -- assign new logLevel value



::method name              attribute
::method shortName         attribute
::method timer             attribute   -- timer object of type .log4r.timing


/* Create a logDir object and returns it. Adds the entries "LOGLEVEL", "MESSAGE",
   "ADDITIONAL" and "CONDITIONOBJECT".
*/
::method makeLogDir
  expose timer logNr name
  use arg loglevel, argArr -- retrieve the logLevel and arguments passed to it originally

  dir=.directory~new             -- create log event directory
      -- create date/time of this log, save it with directory
  parse value date("S") time("L") with d t
  dir~date=d
  dir~time=t
      -- save other log-related information
  dir~logLevel=logLevel          -- add logLevel
  dir~message=argArr~at(1)       -- add message
  dir~elapsed=timer~elapsed      -- add elapsed time information
  dir~category=name              -- save logger's full name

  logNr=logNr+1                  -- increase log number
  dir~logNr=logNr                -- add it to the log directory

   -- if condition or additional object supplied, add it to the directory
  if argArr~hasindex(2) then     -- either a "conditionObject" or "additional" in hand ?
  do
     arg2=argArr~at(2)
     if arg2~isInstanceOf(.directory) then
     do
         -- a condition object ?
        if arg2~hasindex("TRACEBACK") & arg2~hasindex("CONDITION") then
        do
           dir~conditionObject=arg2    -- save it in directory
           if argArr~hasindex(3) then  -- does a third argument exist, if so it is an "additional" object/value
              dir~additional=argArr~at(3)
        end
        else   -- not a condition directory object, so store it as an "ADDTIONAL" entry
           dir~additional=arg2
     end
     else   -- an additional argument
     do
        dir~additional=arg2
     end
  end
  return dir


::method parent                  -- getter
  expose parent
  return parent


::method setUpParent
  expose additivity parent name

  if \additivity then            -- no additivity, hence do nothing
     return

  loggerDir=.LogManager~loggerDir   -- get directory of loggers

  tmpName=name
  lPos=tmpName~lastPos(".")
  do while lPos>1
     tmpName=substr(tmpName , 1, lpos-1)
     if loggerDir~hasEntry(tmpName) then  -- if a "parent" logger found, use it
     do
        parent=loggerDir~entry(tmpName)   -- found a logger whose appenders we need to service as well
        return
     end
     lPos=tmpName~lastPos(".")
  end
  parent=loggerDir~entry("rootLogger") -- stem logger, point to "rootLogger"




::method trace                   -- logLevel=1000 (= .log4rexx~trace)
  expose logLevel
  thisLevel=.log4rexx~trace         -- fetch the numeric value for this logLevel
  if .log4r.config.disableOverride<>.true then  -- global disable for all loggers active?
  do
     if .log4r.config.disable>=thisLevel then return
  end

  if logLevel<=thisLevel then    -- a loggable event
  do
     logDir=self~makeLogdir(thisLevel, arg(1,"A")) -- create a logDir
     self~log(logDir)            -- let "LOG" proceed with the work
  end


::method debug
  expose logLevel
  thisLevel=.log4rexx~debug         -- fetch the numeric value for this logLevel
  if .log4r.config.disableOverride<>.true then  -- global disable for all loggers active?
  do
     if .log4r.config.disable>=thisLevel then return
  end

  if logLevel<=thisLevel then    -- a loggable event
  do
     logDir=self~makeLogdir(thisLevel, arg(1,"A")) -- create a logDir
     self~log(logDir)            -- let "LOG" proceed with the work
  end


::method info
  expose logLevel
  thisLevel=.log4rexx~info          -- fetch the numeric value for this logLevel
  if .log4r.config.disableOverride<>.true then  -- global disable for all loggers active?
  do
     if .log4r.config.disable>=thisLevel then return
  end

  if logLevel<=thisLevel then    -- a loggable event
  do
     logDir=self~makeLogdir(thisLevel, arg(1,"A")) -- create a logDir
     self~log(logDir)            -- let "LOG" proceed with the work
  end


::method warn
  expose logLevel
  thisLevel=.log4rexx~warn          -- fetch the numeric value for this logLevel
  if .log4r.config.disableOverride<>.true then  -- global disable for all loggers active?
  do
     if .log4r.config.disable>=thisLevel then return
  end

  if logLevel<=thisLevel then    -- a loggable event
  do
     logDir=self~makeLogdir(thisLevel, arg(1,"A")) -- create a logDir
     self~log(logDir)            -- let "LOG" proceed with the work
  end


::method error
  expose logLevel
  thisLevel=.log4rexx~error         -- fetch the numeric value for this logLevel
  if .log4r.config.disableOverride<>.true then  -- global disable for all loggers active?
  do
     if .log4r.config.disable>=thisLevel then return
  end

  if logLevel<=thisLevel then    -- a loggable event
  do
     logDir=self~makeLogdir(thisLevel, arg(1,"A")) -- create a logDir
     self~log(logDir)            -- let "LOG" proceed with the work
  end


::method fatal
  expose logLevel
  thisLevel=.log4rexx~fatal         -- fetch the numeric value for this logLevel
  if .log4r.config.disableOverride<>.true then  -- global disable for all loggers active?
  do
     if .log4r.config.disable>=thisLevel then return
  end

  if logLevel<=thisLevel then    -- a loggable event
  do
     logDir=self~makeLogdir(thisLevel, arg(1,"A")) -- create a logDir
     self~log(logDir)            -- let "LOG" proceed with the work
  end


   -- method which dispatches the log messages
::method log                  private unguarded
  expose name shortName appenderQueue logQueue additivity parent
  -- use arg logDir

  guard on
  logQueue~queue(arg(1))      -- queue logDir, ensures sequence even in async mode
  guard off

  if .log4r.config.asyncMode=.true then   -- async mode ?
     reply

  do while logQueue~items>0
     guard on
     logDir=logQueue~pull
     guard off
     if .nil=logDir then leave   -- has another thread emptied the queue in between 'items' and 'pull'?

         -- now process logDir (could be time-consuming)
     if additivity | appenderQueue~items>0 then          -- use appenders in list
     do
        tmpLogger=self           -- start out with this logger
         -- let all appenders process the log event
        do until .nil=tmpLogger
           do appender over tmpLogger~appenderQueue
              appender~doAppend(logDir)
           end
           tmpLogger=tmpLogger~parent     -- now work with "parent", if any
        end
     end
     else         -- a default, rather simple log output
     do
        mb=.mutableBuffer~new ~~append(.log4rexx~entry(logDir~loglevel)~left(5))
        mb ~~append(" - ") ~~append(date('S', , , '-'))~~append(" ")~~append(time('L'))
        mb ~~append(" ") ~~append("[") ~~append(self~name) ~~append("]")
            -- add message
        mb ~~ append(" - ") ~~ append(logDir~message)
        if logDir~hasindex("CONDITIONOBJECT") then
        do
           mb~~append(" !!! received a CONDITION OBJECT !!! ") ~~append(.log4rexx~line.sep)
           mb~~append(formatDirectoryObject(logDir~conditionObject))
        end
        .error~say(mb~string)    -- show log message on stderr:
     end
  end



::method isTraceEnabled
  expose logLevel
  return logLevel <= .log4rexx~trace

::method isDebugEnabled
  expose logLevel
  return logLevel <= .log4rexx~debug

::method isInfoEnabled
  expose logLevel
  return logLevel <= .log4rexx~info

::method isWarnEnabled
  expose logLevel
  return logLevel <= .log4rexx~warn

::method isErrorEnabled
  expose logLevel
  return logLevel <= .log4rexx~error

::method isFatalEnabled
  expose logLevel
  return logLevel <= .log4rexx~fatal



::method string            -- create default string value
  expose name shortName logLevel appenderQueue additivity parent

  tmpStr="appenderQueue={"
  bAddComma=.false
  do a over appenderQueue
     if bAddComma then
        tmpStr=tmpStr || "," pp(a_or_an(a~class~id)": name="a~name)
     else
     do
        tmpStr=tmpStr || pp(a_or_an(a~class~id)": name="a~name)
        bAddComma=.true
     end
  end
  tmpStr=tmpStr"}"

  return a_or_an(self~class~id)": name="name", shortName="shortName || -
         ", logLevel="getLogLevelAsString(logLevel) || -
         ","  tmpStr                                || -
         ", additivity="additivity                  || -
         ", parent="pp(parent)



/* ------------------------------------------------------------------------------ */
/* Simple Log class that outputs log messages to .error (stderr).

   to control the formatting options and log level (to retrieve the numeric log
   level value send one of the messages "trace", "debug", "info", "warn",
   "error", "fatal" to ".log4r" and set "currentLogLevel" to it; to not  show
   any log messages set the log level to ".log4rexx~off"), default: ".log4rexx~warn".
*/
::class "SimpleLog"  subclass Log public

::method init        class
  expose showDateTime showLoggerName showShortName defaultLogLevel
  defaultLogLevel = "INFO"
  showDate        = .false
  showLoggerName  = .false
  showShortName   = .false

::method defaultLogLevel      class  -- logLevel default
  expose defaultLogLevel
  return defaultLogLevel

::method "defaultLogLevel="                   -- setter
  expose defaultLogLevel name

  tmpVal=getdefaultLogLevelAsNumber(arg(1))
  if .nil=tmpVal then
  do
     .LogLog~error(pp(self)", 'defaultLogLevel=': illegal argument, received:" pp(arg(1)))
     return
  end
  defaultLogLevel=tmpVal                  -- assign new defaultLogLevel value



::method showDateTime         class -- show dateTime in log message?
  expose showDateTime
  return showDateTime

::method "showDateTime="      class -- setter
  expose showDateTime
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)

  if .nil=logicalValue then         -- we did not receive a logical value!
  do
     .LogLog~error(pp(self)", 'showDateTime=': argument not logical, received:" newValue)
     return
  end
  showDateTime=logicalValue



::method showLoggerName       class -- getter: show log name in log message?
  expose showLoggerName
  return showLoggerName

::method "showLoggerName="     class -- setter
  expose showLoggerName
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)

  if .nil=logicalValue then         -- we did not receive a logical value!
  do
     .LogLog~error(pp(self)", 'showDateTime=': argument not logical, received:" newValue)
     return
  end
  showLoggerName=logicalValue



::method showShortName        class -- getter: show short name in log message?
  expose showShortName
  return showShortName

::method "showShortName="     class -- setter
  expose showShortName
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)

  if .nil=logicalValue then         -- we did not receive a logical value!
  do
     .LogLog~error(pp(self)", 'showDateTime=': argument not logical, received:" newValue)
     return
  end
  showShortName=logicalValue



::method init
  expose showDateTime showLoggerName showShortName logQueue

  forward class (super) continue -- let the superclass initialize first

  logQueue=.queue~new            -- used for sequencing log message in async mode

      -- define default values, use the values stored with the class object
  clz=self~class
  showDateTime  = clz~showDateTime
  showLoggerName= clz~showLoggerName
  showShortName = clz~showShortName
  self~logLevel = clz~defaultLogLevel


::method configure               -- configure this instance of a SimpleLog-Logger
  expose showDateTime showLoggerName showShortName
  use arg properties

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue

  name=self~name                 -- get name of this logger

      -- get logLevel
  val=properties~entry("LOG4REXX.LOGGER."name)
  if .nil<>val then
  do
     parse var val tmpLogLevel .
     self~logLevel=tmpLogLevel
  end

      -- get options
  do option over .list~of("showDateTime", "showLoggerName", "showShortName")
     .LogLog~debug(pp("SimpleLog")", 'configure' for" pp(a_or_an(self~class~id)":" name)": option="pp(option))
     oriVal=.message~new(self, option)~send
     val=properties~getPropertyValue("LOG4REXX.LOGGER."name"."option, oriVal)
     val=val~strip
     if oriVal<>val then
     do
        .LogLog~debug(pp("SimpleLog")", 'configure' for" pp(a_or_an(self~class~id)":" name)": setting" pp(option) "to" pp(val))
        .message~new(self, option"=", "I", val)~send  -- set new value
     end
  end


   -- method to format and output the log message
::method log                  private unguarded
  expose showShortName showLoggerName showDateTime logQueue

  guard on
  logQueue~queue(arg(1))      -- save logDir
  guard off

  if .log4r.config.asyncMode=.true then   -- async mode ?
     reply

  do while logQueue~items>0
     guard on
     logDir=logQueue~pull     -- get logDir
     guard off
     if .nil=logDir then leave   -- has another thread emptied the queue in between 'items' and 'pull'?

         -- process log
     mb=.mutableBuffer~new ~~append(.log4rexx~entry(logdir~loglevel)~left(5))
     if showDateTime=.true then
        mb ~~append(" ") ~~append(date('S', , , '-'))~~append(" ")~~append(time('L'))

     if showLoggerName then
     do
        if showShortName then
           mb ~~append(" ") ~~append("[") ~~append(self~shortName) ~~append("]")
        else
           mb ~~append(" ") ~~append("[") ~~append(self~name) ~~append("]")
     end

         -- add message
     mb ~~ append(" - ") ~~ append(logdir~message)
     .error~say(mb~string)    -- show log message on stdout
  end


::method showDateTime      -- getter
  expose showDateTime
  return showDateTime

::method "showDateTime="   -- setter
  expose showDateTime
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("SimpleLog")", 'showDateTime=' for" pp(a_or_an(self~class~id)":" name)": argument not logical, received:" newValue)
     return
  end
  if logicalValue <>showDateTime then
     showDateTime=logicalValue


::method showLoggerName
  expose showLoggerName
  return showLoggerName

::method "showLoggerName="   -- setter
  expose showLoggerName
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("SimpleLog")", 'showLoggerName=' for" pp(a_or_an(self~class~id)":" name)": argument not logical, received:" newValue)
     return
  end
  if logicalValue <>showLoggerName then
     showLoggerName=logicalValue


::method showShortName
  expose showShortName
  return showShortName

::method "showShortName="   -- setter
  expose showShortName
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("SimpleLog")", 'showShortName=' for" pp(a_or_an(self~class~id)":" name)": argument not logical, received:" newValue)
     return
  end
  if logicalValue <>showShortName then
     showShortName=logicalValue


::method string            -- create default string value
  expose showDateTime showLoggerName showShortName

  logLevel=self~logLevel
  return a_or_an(self~class~id)": name="self~name", shortName="self~shortName || -
         ", logLevel="getLogLevelAsString(logLevel)   || -
         ", showDateTime="showDateTime                || -
         ", showLoggerName="showLoggerName            || -
         ", showShortName="showShortName



/* ------------------------------------------------------------------------------ */
/* Log class that does nothing. */
::class "NoOpLog"       subclass Log   public

::method trace
::method debug
::method info
::method warn
::method error
::method fatal
::method log

::method isTraceEnabled
  return .false
::method isDebugEnabled
  return .false
::method isInfoEnabled
  return .false
::method isWarnEnabled
  return .false
::method isErrorEnabled
  return .false
::method isFatalEnabled
  return .false

::method unknown           -- do not react upon unknown messages, this is a NoOpLog !



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
