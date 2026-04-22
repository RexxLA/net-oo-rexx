#!/usr/bin/rexx
/*
   program:          log4rexx_layout.cls
   type:             Open Object Rexx  (ooRexx)
   language level:   6.01 (ooRexx version 3.1.2 and up)

   purpose:          Defines the layout classes: .Layout, .SimpleLayout,
                     .PatternLayout, .XMLLayout, .HTMLLayout

                     The 'log4rexx' framework was modelled after Apache's 'log4j', which
                     can be located at <http://jakarta.apache.org/commons/logging/>,
                     but incorporates a enhancements, most notably in the properties
                     file, where filters and layouts can be named in addition to loggers
                     and appenders.

   version:          1.1.0
   license:          Choice of  Apache License Version 2.0 or Common Public License 1.0
	date:             2007-04-11
   author:           Rony G. Flatscher, Wirtschaftsuniversit&auml;t Wien, Vienna, Austria, Europe
   changes:          2007-04-21, ---rgf, added "center" option (^) to PatternLayout, adapted code accordingly
                     2007-05-17, ---rgf: changed name of files and framework from "log4r" to
                                 "log4rexx" ("log4r" has been taken by a Ruby implementation alreday)
                     2009-10-29, ---rgf: adjust for new "::requires"-behaviour in ooRexx 4.0 (not
                                         reprocessing required files each time a requires is found
                                         anymore) and the missing, undocumented ".static_requires"

   needs:	         the 'log4rexx' framework

   usage:            ::REQUIRES log4rexx_layout.cls

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
else     -- ooRexx 4.0 or higher, do a dynamic requires of "log4rexx_init.cls" in order to get at its public routines
do
   .context~package~loadPackage("log4rexx_init.cls")
end

.LogLog~debug("in" pp(req_file) "...")

if \.log4rexx~isInstanceOf(.directory) then  -- ".LOG4REXX" directory entry does not exist yet
   .local~log4rexx=.directory~new      -- create one

if \.log4rexx~hasindex("PATTERN.CHARS") then   -- instead of defininig it as class attributes in Local
do
      -- define pattern layout characters and their index names in the loggingEvent directory
   d=.directory~new     -- valid chars: "cCdFLmMnprRta"
   d["a"]="Additional"  -- log4r-ONLY
   d["c"]="Category"    -- logger name, "category" is the original name for "logger"
   d["C"]="ClassName"
   d["d"]="DateTime"    -- DateTime of formatting
   d["f"]="FieldName"   -- log4r-ONLY
   d["F"]="FileName"
   d["L"]="LineNumber"
   d["N"]="LogNr"       -- "LineNumber" in 'log4j'
   -- "n" ... NL placeholder, do not use!
   d["M"]="MethodName"
   d["m"]="Message"
   d["p"]="LogLevel"    -- "priority"
   d["r"]="Elapsed"     -- needs to be formatted with "formatElapsedSeconds()"
   d["R"]="Elapsed"     -- needs to be formatted with "formatElapsedWithDays()"
   d["t"]="ThreadName"
   .log4rexx~pattern.chars=d

   -- .log4rexx~pattern.validChars="cCdfFlLmMnprRta"  -- characters that end the %-escape sequences
   .log4rexx~pattern.validChars="cCdfFLmMNnprRta"  -- characters that end the %-escape sequences

      -- ooRexx options for DATE() and TIME() BIFs
   .log4rexx~date.options="BDELMNOSUW"
   .log4rexx~date.options.sep="ENOSU"  -- these options allow to supply a separator char
   .log4rexx~time.options="CLNHMS"      -- time options which can be used for conversion
end



/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.Layout>
::class "Layout" public

::method init
  expose footer header contentType name
  parse arg name

  footer=""
  header=""
  contentType="text/plain"

   .LogLog~debug(pp("Layout")", *** 'init' for" pp(a_or_an(self~class~id)":" name))

::method configure
  expose name footer header contentType
  use arg properties          -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".footer", footer)
  footer=val~strip

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".header", header)
  header=val~strip

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".contentType", contentType)
  contentType=val~strip



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


::method format                     -- subclasses implement the formatting
  use arg loggingEvent

   /* show condition object with message */
  mb=.MutableBuffer~new
  mb~~append(loggingEvent~logNr) ~~append(": ")
  mb~~append(.log4rexx~entry(loggingEvent~logLevel)~left(5)) ~~append(" - ")
  mb~~append(loggingEvent~message~string) ~~append(.log4rexx~line.sep)

   /* a condition object available, if so format it and display it with the message! */
  if loggingEvent~hasindex("CONDITIONOBJECT") then
     mb~~append(formatDirectoryObject(loggingEvent~conditionObject)) ~~append(.log4rexx~line.sep)

  return mb~string


::method contentType       attribute
::method header            attribute
::method footer            attribute
::method name              attribute


::method reset             -- allow resetting the configuration to a default setup
  expose name
  self~init(name)          -- just run the constructor(s) again

::method string            -- create default string value
  expose name
  return a_or_an(self~class~id)": name="name", contentType="self~contentType || -
             ", header="self~header", footer="self~footer


/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.SimpleLayout>
::class "SimpleLayout"     subclass Layout   public



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.PatternLayout>
::class "PatternLayout"    subclass Layout   public

::method init
  forward class (super) continue
  -- self~conversionPattern="%r [%t] %-5p %c %a - %m%n"
  -- self~conversionPattern="%r [%c] %-5p - %m%n"
  self~conversionPattern="%5N: %r [%c] %-5p - %m%n"

::method configure                  -- configure this instance of a Log-Logger
  expose conversionPattern
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".conversionPattern", conversionPattern)
  val=val~strip
  if conversionPattern<>val then
     self~conversionPattern=val


::method conversionPattern    -- getter
  expose conversionPattern
  return conversionPattern

::method "conversionPattern=" -- setter
  expose conversionPattern parsedPattern
  parse arg conversionPattern
  parsedPattern=createParsedPattern(conversionPattern)


::method format
  expose parsedPattern
  use arg loggingEvent

  return applyPattern(loggingEvent, parsedPattern)


::method parsedPattern     attribute         private

::method string
  expose conversionPattern
  return self~string:super || ", conversionPattern="conversionPattern


/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.xml.XMLLayout>
::class "XMLLayout"        subclass PatternLayout  public

::method init
  expose ProcessInstruction
  forward class (super) continue -- let first superclass initialize

  self~contentType="text/xml"
  self~header='<log4rexx:log  xmlns:log4rexx="http://www.ooRexx.org/log4rexx/schema" date="' || date("S",,,"-") time('L') || '">' .log4rexx~line.sep
  self~footer="</log4rexx:log>"
  ProcessInstruction=""          -- queue of optional PI (process instructions) to be inserted at the top of an XML file

  -- self~conversionPattern="%f{localDateTime}%d: %f{elapsedTime}%r %f{category}[%c] %f{priority} %-5p %f{message}%m"
  -- self~conversionPattern="%d: %r [%c] %-5p - %m%n"
  self~conversionPattern="#%N: %d %r [%c] %-5p - %m%n"


::method "conversionPattern="       -- setter
  forward class (super) continue    -- let the superclass first do its job

  replacement=.queue~new
  if createFieldEntries(self~parsedPattern, replacement) then  -- replace parsedPattern
  do
     self~parsedPattern=replacement -- this now includes field definitions (and corrections, if necessary)
  end


::method configure                  -- configure this instance of a Log-Logger
  expose processInstruction
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("LOG4REXX.LAYOUT."name".processInstruction", processInstruction)
  val=val~strip
  if processInstruction<>val then
     self~processInstruction=val



::method format
  use arg loggingEvent
  return applyPattern(loggingEvent, self~parsedPattern, "X")   -- indicate XML-rendering desired


::method header                     -- create XML header which should incoroporate any PIs
  expose processInstruction

  mb=.MutableBuffer~new
  if processInstruction<>"" then
     mb~~append(processInstruction)~~append(.log4rexx~line.sep)

  mb~append('<log4rexx:log  xmlns:log4rexx="http://www.ooRexx.org/log4rexx/schema" date="')
  mb~~append(date("S",,,"-")) ~~append(" ") ~~append(time('L')) ~~append('"> ') ~~append(.log4rexx~line.sep)
  return mb~string

::method processInstruction         -- getter
  expose processInstruction
  if arg(1,"E") then
     self~processInstruction=arg(1)
  return processInstruction

::method "processInstruction="      -- setter
  expose processInstruction
  parse arg processInstruction      -- force to string value

::method string
  expose processInstruction
  return self~string:super || ", processInstruction="processInstruction



/* ------------------------------------------------------------------------------ */
   -- cf. <org.apache.log4j.PatternLayout>
::class "HTMLLayout"       subclass PatternLayout  public

::method init
  expose title styleSheetName useStyleSheet
  forward class (super) continue    -- let first superclass initialize

  self~contentType="text/html"
  self~header="<html><body>   <table>"

  lineSep=.log4rexx~line.sep
  self~footer="      </table>" lineSep || "   </body>" lineSep  || "</html>" lineSep
  title="Log4rexx Log Messages ["date("S", , ,"-") time("L")"]"

  styleSheetName=""                 -- no name for external css style sheet
  useStyleSheet =.true              -- default to .true

  -- self~conversionPattern="%f{LogNr}%N %f{LocalDateTime}%d: %f{ElapsedTime}%r %f{Category}[%c] %f{Priority} %-5p %f{Message}%m"
  -- self~conversionPattern="%d: %r [%c] %-5p - %m%n"
  -- self~conversionPattern="%f{LogNr}%N %f{DateTime}%d: %f{ElapsedTime}%r %f{Logger}[%c] %f{LogLevel} %-5p %f{Message}%m"
  self~conversionPattern="%f{LogNr}%N %f{DateTime}%d %f{ElapsedTime}%r %f{Logger}[%c] %f{LogLevel} %^p %f{Message}%-m"


::method "conversionPattern="       -- setter
  expose title styleSheetName useStyleSheet
  forward class (super) continue    -- let the superclass first do its job

  replacement=.queue~new
  if createFieldEntries(self~parsedPattern, replacement) then  -- replace parsedPattern
  do
     self~parsedPattern=replacement -- this now includes field definitions (and corrections, if necessary)
  end
  self~header=createHTMLHeader(self~parsedPattern, title, useStyleSheet, styleSheetName, self~conversionPattern)  -- now create HTML header with COLGROUP


::method configure                  -- configure this instance of a Log-Logger
  expose useStyleSheet styleSheetName title
  use arg properties                -- retrieve

  if \properties~isInstanceOf(.log4rexx.Properties) then
     return

  forward class (super) continue    -- let first superclass configure
  name=self~name

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".useStyleSheet", useStyleSheet)
  val=val~strip
  if useStyleSheet<>val then
     self~useStyleSheet=val

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".styleSheetName", styleSheetName)
  val=val~strip
  if styleSheetName<>val then
     self~styleSheetName=val

  val=properties~getPropertyValue("log4rexx.LAYOUT."name".title", title)
  val=val~strip
  if title<>val then
     self~title=val


::method format
  use arg loggingEvent
  return applyPattern(loggingEvent, self~parsedPattern, "H")   -- indicate HTML-rendering desired

::method string
  expose useStyleSheet styleSheetName
  tmpStr=", useStyleSheet="useStyleSheet", styleSheetName="styleSheetName
  return self~string:super || tmpStr

::method title             -- getter
  expose title
  return title

::method "title="          -- log4r-ONLY: setter
  expose title title useStyleSheet
  parse arg title          -- force string value


::method useStyleSheet     -- log4r-ONLY: getter
  expose useStyleSheet
  return useStyleSheet

::method "useStyleSheet="  -- log4r-ONLY: setter
  expose useStyleSheet title styleSheetName
  parse arg newValue          -- must be 0, 1, true, .true, false, .false

  logicalValue=getLogicalValue(newValue)
  if .nil=logicalValue then  -- not a logical value?
  do
     .LogLog~error(pp("HTMLLayout")", 'useStyleSheet=' for" pp(a_or_an(self~class~id)":" self~name)": argument not logical, received:" pp(newValue))
     return
  end

  if logicalValue=useStyleSheet then    -- nothing has changed
     return


  useStyleSheet=logicalValue  -- save new value
   -- re-create HTML header
  self~header=createHTMLHeader(self~parsedPattern, title, useStyleSheet, styleSheetName, self~conversionPattern)


::method styleSheetName    -- log4r-ONLY: getter
  expose styleSheetName
  return styleSheetName

::method "styleSheetName=" -- log4r-ONLY: setter
  expose styleSheetName title useStyleSheet
  parse arg styleSheetName -- force string value
     -- now rebuild HTML header honoring appropriate styleSheet
  self~header=createHTMLHeader(self~parsedPattern, title, useStyleSheet, styleSheetName, self~conversionPattern)





-- =====================================================================
  /*
     the patternParser is represented as a queue of blank delimited strings, where

        char {L|S} {L|R} {minWidth|0} {maxWidth|0} {IndexName|.nil|LitValue}

        field #1: char
        field #2: {L|S}: "L"[iteral]|"S"[ubstitution]; if "L" then everything after the next
                         blank is regarded to be the literal value
        field #3: {L|R|C}="L"[eft]|"R"[ight]|"C"[enter] adjustment
        field #4: minimumWidth=positive number, 0 if no minimum width
        field #5: maximumWidth=positive number, 0 if no minimum width
        field #6: IndexName: to retrieve the entry from the eventLoggingDirectory,
                  if field #2 is "L", then this field is the literal value

     the following conversion characters are defined for log4rexx:

     char    name in loggingEvent directory
      c  ... "Category"    ... output category name; may be followed by {n}, where "n" indicates
                               the number of components to use from right
      C  ... "ClassName"   ... output Class name
      d  ...               ... output date and time in the form of DATE("S", , ,"-") TIME("L"), or:
                            - {DO[S]} ... D[ate],
                                          O[ption char]: one of "BDELMNOSUW",
                                          S[eparator char], if pos(O,"ENOSU")>0
                            - {TO} ... T[ime],
                                       O[ption char]: one of "CEHLMNR"

      f  ... "FieldName"   ... log4r-ONLY: indicates a new field and allows optionally to
                               set the field name/caption in {}; devised for HTML/XML-Layouts;
                               won't be otherweise used in applyPattern()
      F  ... "FileName"    ... output file name
      l  ... n/a (not available)
      L  ... "LineNumber"  ... n/a
      m  ... "Message"     ... output message
      M  ... "MethodName"  ... output method name
      N  ... "LogNr"       ... output log number
      n  ... .log4rexx~line_sep   LIT
      p  ... "Level"       ... priority of log event
      r  ... "Elapsed"     ... creating Literal using Timelog's elapsed string to format with
                               formatElapsedSeconds() routine
      R  ... "Elapsed"     ... log4r-ONLY: creating Literal using Timelog's elapsed string to format with
                               formatElapsedWithDays() routine
      t  ... "ThreadName"  ... name of the thread
      x  ... n/a (NDC, nested diagnostic context), use "a" instead
      X  ... n/a (MDC, mapped diagnostic context), use "a" instead
      a  ... "Additional"  ... string that may have been supplied as a second argument to
                               the log message (may contain e.g. thread/client infos)
      %  ...               ... LIT "%" literal
      {  ...               ... LIT "{" literal
      >  ...               ... log4r-ONLY: LIT ">" literal: indicate new "field" follows (e.g.
                               for HTML/XML-Layouts), char will not be shown
      ^  ...               ... log4r-ONLY: CENTER-adjustment, center-adjust value
  */
::routine createParsedPattern public
  parse arg conversionPattern

  q=.queue~new
  validChars=.log4rexx~pattern.validChars -- characters that end the %-escape sequences

  do while conversionPattern \== ""
     parse var conversionPattern before "%" conversionPattern
     if before\=="" then q~queue(". L R 0 0 {}" before) -- queue as literal

     firstChar=left(conversionPattern,1)
     if pos(firstChar, "%{>")>0 then   -- "%" or "{" or ">" literal
     do
        q~queue(firstChar "L R 0 0 {}" firstChar)
        conversionPattern=conversionPattern~substr(2)
        iterate
     end

     pos=conversionPattern~verify(validChars, "Match")
     if pos=0 then   -- not found, regard "%" and everything remaining as literal
     do
        q~queue(". L R 0 0 {} %"conversionPattern)
        leave
     end

     char=substr(conversionPattern, pos, 1)  -- extract matched character

     align="R"                   -- by default align right adjusted
     if pos>1 then               -- adjustment and width information
     do
        info=conversionPattern~left(pos-1)
        adj=info~left(1)         -- extract an adjustment char?
        -- if info~left(1)="-" then
        if pos(adj, "-^")>0 then -- left or center adjusted?
        do
           if adj="-" then
              align="L"             -- align left-adjusted
           else
              align="C"

           info=substr(info,2)   -- remove alignment indicator
        end
        parse var info min "." max
        if min="" then min=0
        if max="" then max=0
     end
     else
     do
        min=0
        max=0
        if char="n" then            -- newline literal
        do
           q~queue(char "L R 0 0 {}" .log4rexx~line.sep)
           conversionPattern=conversionPattern~substr(2)
           iterate
        end
     end
     conversionPattern=conversionPattern~substr(pos+1)

     indexName=.log4rexx~pattern.chars[char] -- retrieve the index name into the loggingEvent directory
     if .nil=indexName then indexName="n/a"

     curlyContent=""
     if conversionPattern~left(1)="{" then
     do
        parse var conversionPattern "{" curlyContent "}" conversionPattern

        if char="d" & curlyContent<>"" then  -- process date/time of log message
        do
           parse upper var curlyContent bif +1 option +1 separator +1 .
           if bif="T" then                   -- TIME() BIF
           do
              if option<>"" then
              do
                 if pos(option, .log4rexx~time.options)=0 then -- illegal option, default to 'L'
                    option="L"
              end

              curlyContent=bif || option
           end
           else if bif="D" then
           do
              if option<>"" then
              do
                 if pos(option, .log4rexx~date.options)=0 then -- illegal option, default to 'S'
                 do
                    option="S"
                    separator="?"               -- indicate an error in pattern
                 end
                 else if separator<>"" then     -- separator char given
                 do
                    if pos(option, .log4rexx~date.options.sep)=0 then   -- option does not allow separator char
                       separator=""
                 end
              end

              curlyContent=bif || option || separator
           end
           else      -- unknown BIF, hence use default date format
           do
             curlyContent=""
           end
        end
     end

      -- Substitution by value from loggingEvent directory
     q~queue(char "S" align min max "{"curlyContent"}" indexName)
  end

  return q


-- =====================================================================
   /* Apply the parsed pattern to the given loggerEvent directory object. */

::routine applyPattern public
  use arg loggingEvent, parsedPattern, switch     -- switch: "H"tml or "X"ml, otherwise normal text

/*
say "-"~copies(50)
say "applyPattern: loggingEvent~additional="pp(loggingEvent~additional)
say "              switch                 ="pp(switch)
do line over parsedPattern
   say "              parsedPattern, line:    "pp(line)
end
*/

  tab="09"x
  tab2="0909"x
  lineSep=.log4rexx~line.sep

  mb=.MutableBuffer~new

  if switch="H" then
  do
     tr='   <tr class="'
     tmp=loggingEvent~logLevel
     if .nil<>tmp then
     do
        parse lower value .log4rexx~entry(tmp) with level   -- get level name in lowercase
        tr= tr || level
     end

     logNr=loggingEvent~logNr       -- try to get logNumber
     if .nil<>logNr then            -- a logNr available, is it an even one?
     do
        if logNr//2=0 then          -- an even logNr!
           tr=tr 'even'
     end
     tr = tr || '">'
     mb~~append(tab)~~append(tr) ~~append(lineSep)
  end
  else if switch="X" then
     mb~~append(tab)~~append("   <log4rexx:logentry>")~~append(lineSep)

  bFieldOpen=.false                 -- indicates (for XML/HTML) that an open field is in effect
  strFieldOpen=""                   -- contains tag-name used for open tag
  do line over parsedPattern
     parse var line char kind align min max curly string

     val=""
     if kind="L" then               -- a LITeral in hande?
     do
        if char<>">" then           -- indicate new field comes up, do not display this character
        do
           val=string
        end
     end
     else if char="d" then          -- actual date time
     do
        if curly<>"{}" then
        do
           parse var curly "{" curlyContent "}"
           parse var curlyContent bif +1 option +1 separator +1 .
           if bif="T" then
           do
              if option="" then     -- no option given
              do
                 -- val=time()
                 val=time("N", loggingEvent~time, "L")
              end
              else
              do
                 -- val=time(option)
                 val=time(option, loggingEvent~time, "L")
              end
           end
           else
           do
              if option="" then     -- no option given
              do
                 -- val=date()
                 val=date("N", loggingEvent~date, "S")
              end
              else
              do
                 if separator="" then
                 do
                    -- val=date(option)
                    val=date(option, loggingEvent~date, "S")
                 end
                 else
                 do
                    -- val=date(option, , , separator)
                    val=date(option, loggingEvent~date, "S", separator)
                 end
              end
           end
        end
        else
        do
           -- val=date("S", , , "-") time("L")
           val=date("S", loggingEvent~date, "S", "-") loggingEvent~time
        end
     end
     else if char="f" then          -- field
     do
        if pos(switch, "HX")>0 then
        do
           parse var curly "{" fieldName "}" .
           if fieldName="" then fieldName="fieldNameNotAvailable"

           if switch="H" then
           do
              if bFieldOpen then       -- close previous (open) field
              do
                 mb~~append("</td>") ~~append(lineSep)
              end
                                       -- open (new, current) field
              mb~~append(tab2)~~append("<td>")
           end
           else if switch="X" then
           do
              if bFieldOpen then       -- close previous (open) field
              do
                 mb~~append("</") ~~append(strFieldOpen) ~~append(">")
                 mb~~append(lineSep)
              end
                                       -- open (new, current) field
              strFieldOpen="log4rexx:"fieldName
              mb~~append(tab2)~~append("<") ~~append(strFieldOpen) ~~append(">")
           end
        end

        bFieldOpen=.true
        val=""
     end
     else                           -- retrieve value from loggingEvent
     do

-- say "char="pp(char) pp(.log4rexx~pattern.chars[char]) pp(loggingEvent~entry(.log4rexx~pattern.chars[char]~string))
        val=loggingEvent~entry(.log4rexx~pattern.chars[char]~string)  -- get entry from loggingEvent
        if .nil=val then            -- no entry
           val="n/a"                -- or: ".nil"
        else if pos(char, "rR")>0 then
        do
           if char="r" then val=formatElapsedSeconds(val)
                       else val=formatElapsedWithDays(val)
        end
        else if char="p" then
        do
           val=.log4rexx~entry(val)          -- get human-readable rendering of level
        end
        else if pos(char, "cC")>0 then
        do
           parse var curly "{" num "}"
           if datatype(num, "W") then     -- extract component words (from right)?
           do
               val=subword(reverse(val~changestr(".", " ")), 1, num)~reverse~changestr(" ", ".")
           end
        end
     end

        -- apply min/max, adjustment formatting
     if min>0 & length(val)<min then         -- make value wide enough
     do
        if align="R"      then val=val~right(min) -- right adjust
        else if align="L" then val=val~left(min)  -- left adjust
        else val=val~center(min)                  -- center adjust
     end
     if max>0 & length(val)>max then         -- truncate from left
        val=val~left(max)

     if val\=="" then                  -- only if at least one character is available
     do
        if pos(switch, "HX")>0 then
           mb~append(escapeMarkupChars(val))
        else
           mb~append(val)                 -- append chunk
     end

     if char="m" then      -- we just processed a message, check for ConditionObject to be outputted with message!
     do
         /* a condition object available, if so format it and display it with the message! */
         if loggingEvent~hasindex("CONDITIONOBJECT") then
         do
            -- if switch="H" then mb~~append(.log4rexx~line.sep)~~append(tab)~~append(tab2) ~~append('<span class="coll condition">')
            mb~~append(.log4rexx~line.sep)
            mb~~append(formatDirectoryObject(loggingEvent~conditionObject, switch, .true))

            -- if switch="H" then mb~~append(tab)~~append(tab2)~~append('</span>')
            mb~~append(.log4rexx~line.sep)

            if pos(switch, "HX")>0 then    -- make sure that closing tag is indented
               mb~append(tab2)
         end
     end
  end

  if switch="H" then
  do
     if bFieldOpen then       -- close previous (open) field
     do
        mb~~append("</td>") ~~append(lineSep)
     end

     mb~~append(tab) ~~append("   </tr>")         ~~append(lineSep) ~~append(lineSep)
  end
  else if switch="X" then
  do
     if bFieldOpen then       -- close previous (open) field
     do
        mb~~append("</") ~~append(strFieldOpen) ~~append(">") ~~append(lineSep)
     end

     mb~~append(tab) ~~append("   </log4rexx:logentry>")~~append(lineSep) ~~append(lineSep)
  end

  return mb~string




-- =====================================================================
   /* Enquote string with double-quotes, escape sring's content's quotes.
      Accepts optional quote-argument to allow for single-quoting. */
::routine enQuote                public
  parse arg string, quote
  if quote="" then quote='"'

  return quote || changestr(quote, string, quote||quote) || quote




-- =====================================================================
   /* Analyze parsedPattern for %f (field) items; if none given, then
      create a queue with %f items, throw away any literals.
   */
::routine createFieldEntries     public
  use arg parsedPattern, replacement

  bFields=.false
  do i=1 to parsedPattern~items while \bFields
     bFields=(parsedPattern[i]~left(1)="f")
  end

  if bFields then             -- check whether all fields have a string value to display in the header
  do
     retValue=.false
     counter=1
     if parsedPattern[1]~left(1)<>"f" then   -- does not start with a field, insert a definition
     do
        fn_name=.log4rexx~pattern.chars["f"]
        replacement~queue("f S L 0 0 {Field_1}" fn_name)
        counter=2
        retValue=.true                    -- indicate to use replacement
     end

     do line over parsedPattern
        parse var line char kind align min max curly fieldName
        if char="f" & curly="{}" then        -- field definition does not have a name assigned to it
        do
           replacement~queue(char kind align min max "{Field_"counter"}" fieldName)
           counter=counter+1
           retValue=.true                 -- indicate to use replacement
        end
        else
           replacement~queue(line)
     end
     return retValue
  end

  fn_name=.log4rexx~pattern.chars["f"]

  do line over parsedPattern
     parse var line char kind align min max curly fieldName
     if kind="L" then iterate             -- ignore literal
                                          -- define field and its name
     replacement~queue("f S L 0 0 {"fieldName"}" fn_name)
     replacement~queue(line)              -- queue Substitution definition
  end
  return .true                            -- indicate that replacement queue has been defined


-- =====================================================================
   /* Create the HTMLHeader

   */
::routine createHTMLHeader       public
  use arg parsedPattern, title, useStyleSheet, styleSheetName, conversionPattern

  tab="0909"x
  lineSep=.log4rexx~line.sep

  if useStyleSheet=.true then
  do
     if styleSheetName="" then      -- not supplied use internal one
     do
        styleSheet='<style type="text/css">                                                 ' lineSep -
                   '@media all {                                                            ' lineSep -
                   '  body, table {font-family: arial,sans-serif; font-size: x-small;}      ' lineSep -
                   '  body        {background: #FFFFFF; margin-top: 6px; margin-left: 6px;} ' lineSep -
                   '  th          {background: #336699; color: #FFFFFF; text-align: left;}  ' lineSep -
                   '  tr.even     {background: #E5F2FF;}                                    ' lineSep -
                   '                                                                        ' lineSep -
                   '  tr.trace    {color: navy;   font-style: italic; }                     ' lineSep -
                   '  tr.debug    {color: blue;   font-style: italic; }                     ' lineSep -
                   '  tr.info     {color: black;                      }                     ' lineSep -
                   '  tr.warn     {color: orange;                     }                     ' lineSep -
                   '  tr.error    {color: brown;  font-weight: 900;   }                     ' lineSep -
                   '  tr.fatal    {color: red;    font-weight: 900;   }                     ' lineSep -
                   '                                                                        ' lineSep -
                   '  table       {border-spacing: 1px; padding: 4px; border: 1px;          ' lineSep - /* "border_spacing: 1px": show thin white line between cells */
                   '               border-color: #224466; width: 100%;}                     ' lineSep -
                   '                                                                        ' lineSep -
                   '  table.coll  {border-spacing: 0px; padding: 4px;                       ' lineSep -
                   '               border: 1px;   border-color: #224466;                    ' lineSep -
                   '               width: 100%;   font-weight: normal;                      ' lineSep -
                   '               text-align: left;                                        ' lineSep -
                   '              }                                                         ' lineSep -
                   '                                                                        ' lineSep -
                   '  table.condition  {border-spacing: 0px; padding: 4px;                  ' lineSep -
                   '               background: thistle;                                     ' lineSep -
                   '               font-style: normal;  color: black;                       ' lineSep -
                   '              }                                                         ' lineSep -
                   '                                                                        ' lineSep -
                   '                                                                        ' lineSep -
                   '  table.coll td.index {font-weight: bolder; width: 20%;                 ' lineSep -
                   '                       vertical-align: top}                             ' lineSep -
                   '  table.coll td.item  {font-weight: normal; width: 80%;}                ' lineSep -
                   '  table.coll td span.subitem {font-family: mono, Courier;}              ' lineSep -
                   '                                                                        ' lineSep -
                   '}                                                                       ' lineSep -
                   '                                                                        ' lineSep -
                   '@media print {                                                          ' lineSep -
                   '  body  {font-size: 8pt;}                                               ' lineSep -
                   '  table {padding: 0px; font-size: 8pt; }                                ' lineSep -
                   '}                                                                       ' lineSep -
                   '</style>                                                                ' lineSep

     end
     else      -- link to supplied styleSheetName
     do
        styleSheet='      <link rel="stylesheet" href="'styleSheetName'" type="text/css">' lineSep
     end
  end
  else      -- do not use a style sheet
  do
    styleSheet=""
  end

  mb=.MutableBuffer~new
  mb~~append('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">')~~append(lineSep)
  mb~~append("<html>")                                   ~~append(lineSep)
  mb~~append("   <head>")                                ~~append(lineSep)
  mb~~append("      <title>")~~append(escapeMarkupChars(title))~~append("</title>") ~~append(lineSep)

   -- CSS
  mb~~append( styleSheet)

  mb~~append("   </head>")                               ~~append(lineSep)
  mb~~append(lineSep)

  mb~~append("   <body>")                                ~~append(lineSep)
  mb~~append('      <hr size="1" noshade>')              ~~append(lineSep)
  mb~~append('      Log session start time: ')

  -- emphasizeBegin='<span style="font-family: monospace; font-style: italic; font-weight: bolder;">'
  emphasizeBegin='<span style="font-family: monospace; font-style: italic;">'
  emphasizeEnd  ='</span>'
  mb~append(emphasizeBegin)
  mb~append(date('S',,,'-') time('L'))
  mb~append(emphasizeEnd)
  mb~append(lineSep)

  -- mb~~append("<br>")~~append(lineSep)
  mb~~append("<br> ")~~append(lineSep)
  mb~append( '      ConversionPattern in effect: ')
  mb~~append("<br>")~~append(emphasizeBegin)
  mb~append(escapeMarkUpChars(conversionPattern))
  mb~append(emphasizeEnd)
  mb~append(lineSep)

  mb~~append("<br>")~~append(lineSep) ~~append("<br>")~~append(lineSep)
  mb~~append("      <table>")                            ~~append(lineSep)

      -- create table headers
  cb=.MutableBuffer~new       -- COLGROUP buffer
  cb~~append("         <colgroup>")                      ~~append(lineSep)
  alignLeft  ="            <col align='left'>"   lineSep
  alignRight ="            <col align='right'>"  lineSep
  alignCenter="            <col align='center'>" lineSep

  mb~~append("            <tr>")                         ~~append(lineSep)
  tmpAlign=""
  do line over parsedPattern     -- create
     parse var line char kind align min max curly string
     if char="f" then      -- a field in hand!
     do
         -- create a COL entry in case tmpAlign has a value (means we are moving to the next field)
        if tmpAlign="L"      then cb~append(alignLeft)
        else if tmpAlign="R" then cb~append(alignRight)
        else if tmpAlign="C" then cb~append(alignCenter)

        parse var curly "{" name "}".
        if name="" then name="n/a"
        mb~~append("            <th>")~~append(name)~~append("</th>")               ~~append(lineSep)
     end
     else if char<>"." then
     do
        tmpAlign=align
     end
  end
  if tmpAlign="L"      then cb~append(alignLeft)
  else if tmpAlign="R" then cb~append(alignRight)
  else if tmpAlign="C" then cp~append(alignCenter)

  cb~~append("         </colgroup>")                     ~~append(lineSep)

  mb~~append("            </tr>")                        ~~append(lineSep)~~append(lineSep)

   -- now add the COLGROUP block
  mb~~append(cb~string)~~append(lineSep)~~append(lineSep)
  return mb~string



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
