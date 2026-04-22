#!/usr/bin/rexx
/*
   program:          log4rexx_appender.cls
   type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

   purpose:          Defines the appender classes: .Appender, .ConsoleAppender,
                     .FileAppender, .RollingFileAppender, .DailyRollingFileAppender,
                     .TelnetAppender

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

   version:          1.2.0
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11
   author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-04-17, ---rgf: changed FileAppender.fileAppend to FileAppender.append
                     2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
                     2009-10-29, ---rgf: adjust for new "::requires"-behaviour in ooRexx 4.0 (not
                                         reprocessing required files each time a requires is found
                                         anymore) and the missing, undocumented ".static_requires"

   needs:	         the 'log4rexx' framework, directly requires 'log4rexx_filter.cls' and
                     'log4rexx_layout.cls'

   usage:            ::REQUIRES log4rexx_appender.cls

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



::requires "log4rexx_filter.cls"
::requires "log4rexx_layout.cls"



/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
::class "Appender" public           -- cf. <org.apache.log4j.Appender>

::method init                       -- constructor
  expose filterQueue threshold name layout requiresLayout bFirstRun
  parse arg name                    -- retrieve name
  filterQueue=.queue~new
  layout=.nil
  requiresLayout=.false
  threshold=.log4rexx~all              -- TODO: check, if there is a default threshold value other than this
  bFirstRun=.true                   -- if .true, then header needs to be created

  .LogLog~debug(pp("Appender")", *** 'init' for" pp(a_or_an(self~class~id)":" name))

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



::method uninit                     -- destructor
  self~close                        -- make sure we close this appender


      ---------------------- methods of interface <org.apache.log4j.Appender>
      ---------------------- method of interface <org.apache.log4j.OptionHandler>

   /* after all attributes are set, this method will be run to allow activation/initialization
      of the appender, if needed */
::method activateOptions


::method addFilter                  -- add a filter (will be honored in method doAppend)
  expose filterQueue
  use arg filter                    -- decide(loggingEvent):{DENY|NEUTRAL|ACCEPT}
  filterQueue~queue(filter)

::method clearFilterQueue           -- clear the filter queue, i.e., remove any filters
  expose filterQueue
  filterQueue=.queue~new

::method close                      -- should be implemented by subclass, make sure to invoke this one too
  expose requiresLayout layout bFirstRun name
  if requiresLayout=.true then
  do
     if bFirstRun=.false & .nil<>layout then
     do
        self~process(.directory~new, "F")    -- append footer
        .LogLog~debug(pp("Appender") "for" pp(a_or_an(self~class~id)":" name)", 'close' ---> footer!")
     end
  end
  bFirstRun=.true                   -- indicate that next invocation is a new cycle, uttering a header



::method configure                     -- configure this instance of a Log-Logger
  expose name threshold filterQueue layout requiresLayout filterQueue
  use arg properties               -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  val=properties~getPropertyValue("log4rexx.APPENDER."name".THRESHOLD", threshold)
  val=val~strip
  if threshold<>val then
     self~threshold=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".requiresLayout", requiresLayout)
  val=val~strip
  if requiresLayout<>val then
     self~requiresLayout=val

      -- configure this option after "requiresLayout", as requirement may have been lifted
  val=properties~getPropertyValue("log4rexx.APPENDER."name".layout", layout)
  if val~isInstanceOf(.string) then    -- could be the default layout object
     val=val~strip
  if layout<>val then
     self~layout=val


  val=properties~entry("log4rexx.APPENDER."name".FILTER")
  if .nil<>val then
  do
     tmpQueue=.queue~new
     filterList=val~strip
     do while filterList<>""        -- create queue with filters we need for this appender
        parse var filterList f . "," filterList
        tmpQueue~queue(f)
     end

     bReset=(filterQueue~items<>tmpQueue~items)  -- different amount of filters

      -- do we have the same filter names in the same sequence?
     do i=1 to filterQueue~items while \bReset
        bReset=(filterQueue[i]~name<>tmpQueue[i])
     end

     if bReset then                 -- we need to reset the filterQueue
     do
        .LogLog~debug(pp("Appender")", 'configure' for" pp(a_or_an(self~class~id)":" name)": filter queue changed, resetting it")
        oldFilterQueue=filterQueue
        self~clearFilterQueue       -- clear present queue
        filterDir=.LogManager~filterDir
        bError=.false
        do tmpFilterName over tmpQueue    -- iterate over appender names this logger must use
           if filterDir~hasentry(tmpFilterName) then           -- does appender exist?
              self~addFilter(filterDir~entry(tmpFilterName))
           else
           do
              bError=.true
              .LogLog~error(pp("Appender")", 'configure' for" pp(a_or_an(self~class~id)":" name)": filter" pp(tmpFilterName) "does not exist!")
           end
        end

        if bError then              -- leave old in place
        do
           filterQueue=oldFilterQueue
           .LogLog~debug(pp("Appender")", 'configure' for" pp(a_or_an(self~class~id)":" name)": new filter queue in error, reset to previous queue!")
        end
     end
  end




::method doAppend
  expose threshold filterQueue requiresLayout layout bFirstRun name
  use arg loggingEvent              -- a directory object

  -- if loggingEvent~logLevel<threshold then return   -- do not carry out logging !
  if threshold>=loggingEvent~logLevel then return   -- do not carry out logging !

  if bFirstRun then
  do
     self~activateOptions           -- make sure appenders get fully initialized
     if requiresLayout & .nil<>layout then
     do
        self~process(loggingEvent, "H")   -- append header
        .LogLog~debug(pp("Appender") "for" pp(a_or_an(self~class~id)":" name)", 'doAppend' (first run) ---> header!")
     end
     bFirstRun=.false
  end

  if filterQueue~items>0 then       -- if filter defined, process it
  do f over filterQueue             -- in case we have filters, let them do their work
     res=f~decide(loggingEvent)

     if res=.log4rexx~filter.deny then return
     if res=.log4rexx~filter.accept then leave
  end

  self~process(loggingEvent)        -- now do the append of the log message


::method filterQueue    attribute


::method layout                     -- getter
  expose layout
  return layout

::method "layout="                  -- setter
  expose layout requiresLayout
  use arg newValue

  if .nil=newValue then
  do
     if requiresLayout=.true then   -- layout is required!
        .LogLog~error(pp("Appender")", 'layout=' for" pp(a_or_an(self~class~id)":" self~name)": '.nil' is only allowed, if 'requiresLayout' is .false!")
     else                           -- o.k., set layout to .nil
         layout=.nil
     return
  end

  if newValue~isInstanceOf(.layout) then  -- a layout object?
  do
     layout=newValue
     return
  end
  else
     newValue=newValue~string       -- make sure it is a string

  o=.logManager~getLayout(newValue) -- try to get a registered logger

  if .nil<>o then
  do
     layout=o                       -- assign returned layout
     return
  end

   -- error, no layout object nor name of a registered layout object!
  .LogLog~error(pp("Appender")", 'layout=' for" pp(a_or_an(self~class~id)":" self~name)": argument not a layout object nor a registered layout, received:" pp(newValue))



::method requiresLayout             -- getter
  expose requiresLayout
  return requiresLayout

::method "requiresLayout="         -- setter
  expose requiresLayout
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("Appender")", 'requiresLayout=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  requiresLayout=logicalValue


::method name           attribute   -- name of the appender


      ---------------------- methods of interface AppenderSkeleton
      /* NOTE: - not using "append" as the name for this method to allow attributes
                 of this name (e.g. in the FileAppender)
               - do not allow anyone outside of this class to activate it,
                 should be implemented by subclasses
      */
::method process        private     -- carry out the actual appending, named "append" in log4j

::method threshold      -- getter   -- starting with this level log messages will be processed
  expose threshold
  return threshold

::method "threshold="   -- setter
  expose threshold name

  tmpVal=getLogLevelAsNumber(arg(1))
  if .nil=tmpVal then
  do
     .LogLog~error(pp("Appender")", 'threshold=' for" pp(a_or_an(self~class~id)":" name)": illegal argument, received:" pp(arg(1)))
     return
  end
  threshold=tmpVal                  -- assign new logLevel value


::method string            -- create default string value
  expose name threshold filterQueue layout requiresLayout

  tmpStr="filterQueue={"
  bAddComma=.false
  do f over filterQueue
     if bAddComma then
        tmpStr=tmpStr || "," pp(f)
     else
     do
        tmpStr=tmpStr || pp(f)
        bAddComma=.true
     end
  end
  tmpStr=tmpStr"}"


  return a_or_an(self~class~id)": name="name          || -
         ", threshold="getLogLevelAsString(threshold) || -
         ", requiresLayout="requiresLayout            || -
         ", layout="pp(layout)"," tmpStr



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.varia.NullAppender>
::class "NullAppender"     subclass Appender public
::method doAppend          -- do nothing

::method configure         -- do nothing

::method string
  return a_or_an(self~class~id)": name="self~name

/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.varia.WriterAppender>
-- ::class "WriterAppender"   subclass Appender public



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.spi.varia.ConsoleAppender>
::class "ConsoleAppender"  subclass Appender public
::method init
  expose target follow immediateFlush
  forward class (super) continue
  target=.error            -- default to STDERR (STDOUT ".output" is alternative)
  follow=.true             -- default: follow reassignments of .output/.error after configuration
  immediateFlush=.true     -- force a flush
  self~layout=.SimpleLayout~new     -- make sure we have a layout object
  self~requiresLayout=.true


::method configure                  -- configure this instance of a Log-Logger
  expose follow immediateFlush
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.APPENDER."name".FOLLOW", follow)
  val=val~strip
  if follow<>val then
     self~follow=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".immediateFlush", immediateFlush)
  val=val~strip
  if immediateFlush<>val then
     self~immediateFlush=val

  val=properties~entry("log4rexx.APPENDER."name".TARGET")
  if .nil<>val then
     self~target=val


   -- if .true, reconfiguring output stream is allowed
::method follow            -- getter
  expose follow
  return follow

::method "follow="         -- setter
  expose follow
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("ConsoleAppender")", 'follow=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  follow=logicalValue


   -- if .true, message flush is sent to stream object
::method immediateFlush    -- getter
  expose immediateFlush
  return immediateFlush

::method "immediateFlush=" -- setter
  expose immediateFlush
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("ConsoleAppender")", 'immediateFlush=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  immediateFlush=logicalValue


::method target            -- getter: return target stream
  expose target
  return target

::method "target="         -- setter, stderr, if argument string contains "ERR",
                           -- stdout, if argument string contains "OUT"
  expose target follow

  if follow<>.true then    -- allow reconfiguring ?
     return

  parse upper arg newTarget   -- parse argument, get string in uppercase

  if pos("OUT", newTarget)>0      then target=.output -- set to STDOUT
  else if pos("ERR", newTarget)>0 then target=.error  -- set to STDERR
  else
     .LogLog~error(pp("ConsoleAppender")", 'target=' for" pp(a_or_an(self~class~id)":" self~name)": argument not 'err' nor 'out', received:" pp(arg(1)~string))



::method process
  expose target immediateFlush
  use arg loggingEvent, kind

  if pos(kind, "HF")=0 then   -- not a H[eader] or F[ooter] request, just a normal log message
     target~charout(self~layout~format(loggingEvent))
  else if kind="H" then       -- header
     target~charout(self~layout~header)
  else                        -- footer
     target~charout(self~layout~footer)

  if immediateFlush=.true then   -- flush the stream ?
     target~flush


::method string
  expose follow immediateFlush target
  if target=.output then tmpStr=".output"
                    else tmpStr=".error"

  return self~string:super || ", target="tmpStr", follow="follow || -
         ", immediateFlush="immediateFlush



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.FileAppender>
::class "FileAppender"     subclass Appender public

::method init
  expose append fileName bufferedIO targetStream

  forward class (super) continue    -- let superclass do its work first
  targetStream=.nil        -- default to STDERR (STDOUT ".output" is alternative)
  -- fileName=.nil
  fileName=self~class~id"Default.log"  -- create a default log file name

  append=.true         -- by default append
  bufferedIO=.false        -- by default no bufferedIO, flush after each append

  self~layout=.SimpleLayout~new
  self~requiresLayout=.true


::method configure                  -- configure this instance of a Log-Logger
  expose append fileName bufferedIO
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.APPENDER."name".APPEND", append)
  val=val~strip
  if append<>val then
     self~append=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".bufferedIO", bufferedIO)
  val=val~strip
  if bufferedIO<>val then
     self~bufferedIO=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".fileName", fileName)
  val=val~strip            -- remove leading and trailing spaces
  if fileName<>val then
     self~fileName=val


::method append        -- getter
  expose append
  return append

::method "append="     -- setter
  expose append
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("FileAppender")", 'append=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  append=logicalValue


::method fileName          -- getter
  expose fileName
  return fileName

::method "fileName="       -- setter
  expose fileName
  parse arg newValue       -- retrieve new file name
  if newValue<>fileName then
  do
     fileName=newValue
     self~close            -- close present open stream to force using new file name
  end


::method bufferedIO        -- getter
  expose bufferedIO
  return bufferedIO

::method "bufferedIO="     -- setter
  expose bufferedIO
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("FileAppender")", 'bufferedIO=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  bufferedIO=logicalValue


::method targetStream      attribute private
-- ::method bufferSize        attribute  -- let ooRexx do the buffering, however it does it

::method activateOptions   -- now open file
  expose append fileName targetStream bOpen

  .LogLog~debug(pp("FileAppender")" for" pp(a_or_an(self~class~id)":" self~name)", 'activateOptions' ...")

  targetStream=self~openStream   -- get stream object to write to
  if append=.false then openOptions="REPLACE"
                       else openOptions="APPEND"
  targetStream~open(openOptions) -- open file
  bOpen=.true              -- indicate we have our file open

::method openStream        -- opens stream, allows overriding opening stream by subclass
  expose fileName
  .LogLog~debug(pp("FileAppender")" for" pp(a_or_an(self~class~id)":" self~name)", 'openStream': fileName="pp(fileName))
  return .stream~new(fileName)


::method close             -- close file
  expose targetStream bOpen

  forward class (super) continue    -- let superclass do its work first

  if bOpen=.false then return -- not open, hence no reason to close
  if .nil<>targetStream then
  do
     targetStream~close
     bOpen=.false
     .LogLog~debug(pp("FileAppender")" for" pp(a_or_an(self~class~id)":" self~name)", 'close': targetStream got closed.")
  end

::method process
  expose targetStream bufferedIO
  use arg loggingEvent, kind


-- say "--> FileAppender.process() for" pp(self~name)", kind="pp(kind) "*"~copies(20)

  if pos(kind, "HF")=0 then   -- not a H[eader] or F[ooter] request, just a normal log message
     targetStream~charout(self~layout~format(loggingEvent))
  else if kind="H" then       -- header
     targetStream~charout(self~layout~header)
  else                        -- footer
     targetStream~charout(self~layout~footer)

  if bufferedIO=.false then   -- flush the stream ?
     targetStream~flush


::method string
  expose append fileName bufferedIO

  return self~string:super || ", fileName="fileName", append="append || -
         ", bufferedIO="||bufferedIO





/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.RollingFileAppender>
::class "RollingFileAppender"    subclass FileAppender   public

::method init
  expose maxBackupIndex

  forward class (super) continue    -- let superclass do its work first
  self~maxFileSize=10mb             -- default: 10 MB
  maxBackupIndex=1                  -- default: 1 Backup File only


::method configure                  -- configure this instance of a Log-Logger
  expose maxBackupIndex maxFileSize
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.APPENDER."name".maxBackupIndex", maxBackupIndex)
  val=val~strip
  if maxBackupIndex<>val then
     self~maxBackupIndex=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".maxFileSize", maxFileSize)
  val=val~strip
  if maxFileSize<>val then
     self~maxFileSize=val



::method maxFileSize       -- getter
  expose maxFileSize
  return maxFileSize

::method "maxFileSize="    -- setter, handles also mixed numbers with trailing KB, MB, GB
  expose maxFileSize

  parse upper arg size
  size=strip(size)         -- remove leading and trailing blanks

  numeric digits 20        -- set here to take affect already for next BIF
  if datatype(size, "Whole") then
     maxFileSize=size
  else
  do
     pos=verify(size, "0123456789") -- get first non-digit
     if pos>0 then                  -- KB, MB, GB in hand?
     do
        parse var size amount =(pos) magnitude
        if \datatype(amount, "Whole") then  -- if no size given, default to "1"
           amount=1

        magnitude=magnitude~strip~left(1) -- get first character

        if magnitude="K" then          -- KB
           maxFileSize=amount*1024
        else if magnitude="M" then     -- MB
           maxFileSize=amount*(1024**2)
        else if magnitude="G" then     -- GB
           maxFileSize=amount*(1024**3)
        else if magnitude="T" then     -- TB
           maxFileSize=amount*(1024**4)
     end
  end
  .LogLog~debug(pp("RollingFileAppender")", 'maxFileSize=': new value="pp(maxFileSize))


::method maxBackupIndex    -- getter
  expose maxBackupIndex
  return maxBackupIndex


::method "maxBackupIndex=" -- setter
  expose maxBackupIndex
  parse arg newValue

  if \datatype(newValue, "W") & newValue>=0 then
  do
     .LogLog~error(pp("RollingFileAppender")", 'maxBackupIndex=' for" pp(a_or_an(self~class~id)":" self~name)": illegal argument value, received:" pp(newValue))
     return
  end
  maxBackupIndex=newValue


/*
::method activateOptions   -- now open file
  forward class (super) continue    -- let superclass do its work first
*/


::method openStream        -- opens stream, allows overriding opening stream by subclass
  expose maxBackupIndex bOpen

  filename=self~fileName            -- get fileName
  bOpen=.true

      -- need for a roll-over ?
  if maxBackupIndex>0 then
  do
     lastFileName=filename"."maxBackupIndex
     if stream(lastFileName, "C", "QUERY EXISTS")<>"" then  -- exists, delete it, rename the others
     do
        retc=SysFileDelete(lastFileName)     -- delete file
        .LogLog~debug(pp("RollingFileAppender")", 'openStream': deleted existing log-file:" pp(lastFileName) "retc:" pp(retc))
     end
      -- now rename
     bIsDos=(.log4rexx~opsys.kind="WINDOWS")
     do i=maxBackupIndex-1 to 1 by -1       -- rename the others
        tmpFileName=filename"."i
        tmpFN1=stream(tmpFileName, "C", "QUERY EXISTS")
        if tmpFN1<>"" then  -- exists, delete it, rename the others
        do
           if bIsDos then  -- DOS/WINDOWS/OS2-version
           do
              -- "ren" enquote(tmpFN1) enquote(filename"."(i+1))
              tmpFN2=filename"." || (i+1)
              call renameFile bIsDos, enquote(tmpFN1), enquote(tmpFN2)
           end
           else            -- assuming UNIX-kind of operating system
           do
              -- "mv" enquote(tmpFN1) enquote( filespec(tmpFN1, "PATH") || filename"."(i+1))
              tmpFN2=filespec(tmpFN1, "PATH") || filename"." || (i+1)
              call renameFile bIsDos, enquote(tmpFN1), enquote(tmpFN2)
           end
        end
     end

     .LogLog~debug(pp("RollingFileAppender")", 'openStream': new log-file name:" pp(fileName".1"))
     return .stream~new(fileName".1")  -- create stream for new filename
  end
  .LogLog~debug(pp("RollingFileAppender")", 'openStream': no backup generation, using:" pp(fileName))
  return .stream~new(fileName)   -- no backup-generation use filename as is

/* Do the rename in its own routine, such that an exception can be easily caught. */
renameFile: procedure
  parse arg isDos, oldName, newName

  .LogLog~debug(pp("RollingFileAppender")", 'openStream', 'renameFile':" pp(oldName) "to" pp(newName))
  signal on any
  if isDos then address "cmd"   "ren" oldName newName -- DOS, Windows, OS/2
           else address "bash"  "mv"  oldName newName -- Unix-based
any:
  return



::method process        -- after processing check whether maxFileSize has been arrived/surpassed
  expose maxFileSize bOpen

  forward class (super) continue    -- let superclass do its work first

  if bOpen=.true then
  do
     if self~targetStream~chars>=maxFileSize then
     do
        bOpen=.false
        self~close      -- close file, will force opening the file again, triggering roll-over
        .LogLog~debug(pp("RollingFileAppender")", 'process': maxFileSize exceeded, closing current stream to force roll-over on next log message.")
     end
  end


::method string
  expose maxFileSize maxBackupIndex

  return self~string:super || ", maxFileSize="maxFileSize || -
         ", maxBackupIndex="maxBackupIndex




/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.DailyRollingFileAppender>
/* The values for indicating the type of rolling differs from log4j to make it more
   "Rexxish" (simpler, self documenting): MINUTE HOUR HALF_DAY DAY WEEK MONTH
   where: DAY WEEK MONTH are always midnight
          WEEK is always Monday midnight (00:00)
*/
::class "DailyRollingFileAppender"    subclass FileAppender   public

::method init
  expose rollOverFileName rollType alarm

  forward class (super) continue    -- let superclass do its work first
  self~rollType="DAY"
  rollOverFileName=""               -- filename to be used
  alarm=.nil                        -- alarm object


::method configure                  -- configure this instance of a Log-Logger
  expose rollType
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.APPENDER."name".rollType", rollType)
  val=val~strip
  if rollType<>val then
     self~rollType=val



::method rollType          -- getter -- MINUTE HOUR HALF_DAY DAY WEEK MONTH
  expose rollType
  return rollType

::method "rollType="       -- setter; make sure we use the long name, even if only first chars are supplied
  expose rollType rollTypeChars
  parse upper arg type .   -- get value in uppercase, remove leading & trailing spaces

  if wordpos(type, "MINUTE HOUR HALF_DAY DAY WEEK MONTH")>0 then  -- full name supplied?
  do
     rollType=type
     if pos(type~left(1), "DW")>0 then -- first character already significant enough?
        rollTypeChars=type~left(1)
     else
        rollTypeChars=type~left(2)
  end
  else
  do
     type=type~left(2)        -- get first two characters
     if pos(type~left(1), "DW")>0 then -- first character already significant enough?
        type=type~left(1)

     wpos=wordpos(type, "MI HO HA D W MO")   -- a valid (abbreviated) type in hand?
     if wpos>0 then
     do
        rollType=word("MINUTE HOUR HALF_DAY DAY WEEK MONTH", wpos)
        rollTypeChars=type
     end
  end

::method close
  expose alarm bOpen
  if .nil<>alarm then      -- make sure alarm is cancelled
     alarm~cancel

  forward class (super) continue -- now let superclass do its work
  bOpen=.false



::method activateOptions   -- now open file
  self~rollover            -- make sure this is called first, such that the file-name gets set
  forward class (super)    -- let superclass do its work


::method openStream        -- opens stream, allows overriding opening stream by subclass
  expose bOpen rollOverFileName

  bOpen=.true
  return .stream~new(rollOverFileName)


::method rollOver          -- roll over
  expose rollType rollTypeChars bOpen rollOverFileName alarm

  if .nil<>alarm then      -- make sure any pending alarm is cancelled
     alarm~cancel

      -- use actual date and time for the filename extension
  rollOverFileName=self~fileName"."date("S",,,"-")"_"time()~left(5)~changestr(':','-')"_"rollType

      -- create a new alarm for next rollover
  aTime=getNextInvocation(rollTypeChars)     -- determine date and time of next invocation
  aTime=subword(aTime,4) subword(aTime,1,3)  -- reshuffle date and time to match Alarm's syntax
  alarm=.alarm~new(aTime, .message~new(self, "rollOver"))

  if bOpen=.true then   -- close appender, causes opening new one on next log entry,
  do                    -- using the new value "rollOverFileName"
     bOpen=.false
     self~close
  end


::method string
  expose rollType

  return self~string:super || ", rollType="rollType


   -- defining as a public routine, such that "log4rexx.testUnit" can test this routine as well
::routine getNextInvocation   public
  parse arg rollType

  if arg(2,"Exists") then  -- if second argument exists, then we are in debug mode
  do
     parse upper arg type .
      -- make sure rollType gets correct value
     if pos(type~left(1), "DW")>0 then -- first character already significant enough?
        rollType=type~left(1)
     else                              -- get first two significant characters
        rollType=type~left(2)

     parse arg , sortedDate nowTime
     baseDays=date("B", sortedDate, "S")  -- turn sorted date into base days
     parse var nowTime timeHours ":" timeMinutes ":" .
  end
  else
  do
     parse value date("S") date("B") time() with sortedDate baseDays nowTime
     parse var nowTime timeHours ":" timeMinutes ":" .
  end

  if rollType="MI" then             -- at the next minute
  do
     timeMinutes=timeMinutes+1
     if timeMinutes>59 then         -- increase hours?
     do
        timeMinutes=0
        timeHours=timeHours+1
        if timeHours>23 then
        do
           baseDays=baseDays+1
           timeHours=0
        end
     end
  end
  else if rollType="HO" then        -- at the next full hour
  do
     timeMinutes=0
     timeHours=timeHours+1
     if timeHours>23 then
     do
        baseDays=baseDays+1
        timeHours=0
     end
  end
  else if rollType="HA" then        -- next half day (midnight or noon/midday)
  do
     timeMinutes=0
     if timeHours<12 then timeHours=12
     else      -- next day at midnight
     do
        timeHours=0
        baseDays=baseDays+1
     end
  end
  else      -- full days or more, always at midnight
  do
         -- make sure midnight
     timeMinutes=0
     timeHours  =0

     if rollType="D" then           -- next day
     do
        baseDays=baseDays+1
     end
     else if rollType="W" then      -- next monday
     do
        baseDays=baseDays+7-(baseDays//7)
     end
     else if rollType="MO" then     -- next month
     do
        parse var sortedDate yy +4 mm +2 dd
        mm=mm+1
        if mm>12 then
        do
           mm=01
           yy=yy+1
        end
        dd=01
        baseDays=date("B", yy||mm~right(2,0)||dd, "S")  -- turn sorted day to basedays
     end
  end

  return date("N", baseDays, "B") timeHours~right(2,0)":"timeMinutes~right(2,0)":00"

-- pp: procedure; return "["arg(1)~string"]"





/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.net.TelnetAppender>
::class "TelnetAppender"  subclass Appender public

::method init                    -- constructor
  expose serverSocket clients port logQueue bNewPort mAcceptThread bStopAppender keepClients

  serverSocket=.nil              -- indicate not available yet
  keepClients=.false             -- if closing server, should clients be closed or not?
  logQueue=.nil                  -- indicate not available yet
  port=23                        -- default telnet port
  bNewPort=.true                 -- indicate new port (create ServerSocket, start accept(), ...)
  bStopAppender=.false           -- indicate to not stop appender
  clients=.set~new               -- use a set to store client sockets
  mAcceptThread=.nil             -- messageObject of accept() method running in separate thread
  self~maxLogsInQueue=25         -- default to 25 log entries in circularQueue

  forward class (super) continue

  self~layout=.SimpleLayout~new
  self~requiresLayout=.true

  if \.local~hasentry("rgf.Socket") then  -- server socket class not available yet
  do
     call "rgf.sockets.cls"               -- call program that contains the Socket definitions
  end



::method configure                  -- configure this instance of a Log-Logger
  expose port keepClients maxLogsInQueue
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.APPENDER."name".port", port)
  val=val~strip
  if port<>val then
     self~port=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".keepClients", keepClients)
  val=val~strip
  if keepClients<>val then
     self~keepClients=val

  val=properties~getPropertyValue("log4rexx.APPENDER."name".maxLogsInQueue", maxLogsInQueue)
  val=val~strip
  if maxLogsInQueue<>val then
     self~maxLogsInQueue=val


::method activateOptions            -- now open file
  expose serverSocket port logQueue maxLogsInQueue bNewPort mAcceptThread bStopAppender

  if .nil=logQueue then    -- need to create the queue in the first place?
     logQueue=.circularQueue~new(maxLogsInQueue)   -- create circularQueue

  if .nil<>serverSocket & bNewPort=.true then     -- a serverSocketCollectingClients instance already available, close it
  do
     self~closeServerSocket         -- stop ServerSocket
  end

  if .nil=serverSocket | bNewPort then                  -- no serverSocket, create one
  do
     serverSocket=.rgf.ServerSocket~new(port) -- create new ServerSocket
     bStopAppender=.false           -- indicate that we do not wish to stop appender

        -- start asynchroneously accepting connections
     -- mAcceptThread=.message~new(serverSocket, "ACCEPT", 'I', 0) -- allows to gracefully stop accepting
     mAcceptThread=.message~new(serverSocket, "ACCEPT") -- use blocking version of accept()
     mAcceptThread~notify(.message~new(self, "NEWCLIENT"))  -- if done, invoke this method
     mAcceptThread~start      -- start the method (asynchroneously)
  end

  if bNewPort=.true then            -- handled case of new port
     bNewPort=.false

  forward class (super)    -- let superclass do its work as well



::method close                      -- close the appender
  expose bStopAppender serverSocket

  bStopAppender=.true               -- indicate that we are about to stop the appender
  forward class (super) continue    -- let superclass do its closing stuff (e.g. will send footer)
  self~closeServerSocket            -- now close server socket
  serverSocket=.nil                 -- indicate no serverSocket available anymore


::method keepClients       -- getter  -- determines whether to keep clients after server port got changed
  expose keepClients
  return keepClients

::method "keepClients="    -- setter
  expose keepClients
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("TelnetAppender")", 'keepClients=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end
  keepClients=logicalValue


::method maxLogsInQueue    -- getter
  expose maxLogsInQueue

  if arg()=1 then          -- used as a setter as well!
     maxLogsInQueue=arg(1)

  return maxLogsInQueue


::method "maxLogsInQueue="    -- setter
  expose logQueue maxLogsInQueue
  parse arg nrElements

  if datatype(nrElements, "W") & nrElements>=0 then
  do
     maxLogsInQueue=nrElements
     if .nil<>logQueue then            -- resize circularQueue
        logQueue~resize(nrElements)
     else
        logQueue=.CircularQueue~new(nrElements)
  end


   -- this gets invoked by notification, if mAcceptThread has completed
   -- only processes notification, if appender is not about to be stopped!
::method newClient
  expose serverSocket mAcceptThread clients logQueue bStopAppender

  if bStopAppender<>.true & mAcceptThread~completed then
  do
     clientSocket=mAcceptThread~result -- get result object from accept method

     if bStopAppender<>.true then      -- create and start another accept() message
     do
           -- start asynchroneously accepting connections
        mAcceptThread=.message~new(serverSocket, "ACCEPT", 'I', 0) -- allows to gracefully stop accepting
        mAcceptThread~notify(.message~new(self, "NEWCLIENT"))  -- if done, invoke this method
        mAcceptThread~start         -- start the method (asynchroneously)
     end

     if .nil<>clientSocket then     -- o.k. we received a client socket
     do
        do log over logQueue        -- send logs from CircularQueue
           clientSocket~send(log)
        end
        clients~put(clientSocket)   -- put client into set of clients to send logs to

        .LogLog~debug(pp("TelnetAppender")", 'newClient', accepted:" pp(clientSocket))
     end
  end


::method port                 -- getter
  expose port
  if arg()=1 then             -- used as a setter as well!
     self~port=arg()
  return port


::method "PORT="              -- setter
  expose port bNewPort
  parse arg newPort

      -- new port?
  if datatype(newPort, "W") & newPort<>port & port>0 & port<65536 then
  do
     port=newPort             -- save new serverPort
     bNewPort=.true           -- indicate we need a new serverSocket
     -- self~activateOptions  -- close appender, close previous ServerSocket, create new ServerSocket
     .LogLog~debug(pp("TelnetAppender")", 'port=', new server port set to:" pp(newPort))
  end



::method process
  expose clients logQueue

  use arg loggingEvent, kind

  if pos(kind, "HF")=0 then   -- not a H[eader] or F[ooter] request, just a normal log message
     msgString=self~layout~format(loggingEvent)
  else if kind="H" then       -- header
     msgString=self~layout~header
  else                        -- footer
     msgString=self~layout~footer

  logQueue~queue(msgString)   -- queue message string
  quitChars="0304"x||"Qq"     -- if these chars are received from the client, then connection will be closed with a feedback
  do c over clients           -- send log message to all attached clients
     if c~waitForReceive(0)=1 then     -- is there something to receive from the client?
     do
        .LogLog~debug(pp("TelnetAppender") "'process' for" pp(a_or_an(self~class~id)":" self~name) "--> ready to receive, client : ["c~string"]")
        tmp=c~receive(-1)~string    -- receive data, if any

           -- CTL-C, CTL-D, "q|Q[uit]" will close connection to client
        if verify(tmp, quitChars, "M")>0 then       -- client wants to stop
        do
            -- give client feedback, then close connection and continue with next client
           c~send("0d0a"x || date("S",,,"-") time('L')": closing connection per your request." "0a"x)
           c~close
           clients~remove(c)
           iterate
        end
     end

     if c~send(msgString)<0 then    -- error sending something, close client socket
     do
        c~close                     -- close clientSocket
        clients~remove(c)           -- remove from "clients"
     end
  end


::method closeServerSocket     unguarded private
  expose clients serverSocket mAcceptThread keepClients bStopAppender

  if .nil=serverSocket then return  -- not yet started, but already removing this appender

--  self~close                        -- close appender to force writing footer

  guard on
  bStopAppender=.true               -- do not process notification messages anymore
  guard off

  serverSocket~stopAccepting        -- make sure that no new clients are accepted
  call sysSleep min(1, (serverSocket~checkInterval/1000)+.01)  -- sleep up to a second

  serverSocket~close                -- close server socket
  serverSocket~waitForException(1)  -- wait up to a second

  if keepClients=.false then
  do
     do clientSocket over clients   -- close all clients
        clientSocket~close
        guard on
        clients~remove(clientSocket)-- remove clientSocket from collection
        guard off
     end
  end

  if mAcceptThread~completed then   -- has accept() completed?
  do
     res=mAcceptThread~result       -- get result object
     if .nil<>res then              -- a clientSocket?
     do
        res~close                   -- close it
        guard on
        clients~remove(res)         -- make sure it is removed from the collection, if it got put there in the meantime
        guard off
     end
  end


::method string
  expose port maxLogsInQueue keepClients

  return self~string:super || ", port="port || -
         ", maxLogsInQueue="maxLogsInQueue  || -
         ", keepClients="keepClients


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
