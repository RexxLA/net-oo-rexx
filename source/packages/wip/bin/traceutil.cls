/*
   author:     Rony G. Flatscher
   name:       traceutils.cls
   purpose:    utilities for working with TraceObjects
   date:       2024-02-01 - 2025-02-1810
   license:    AL 2.0, CPL 1.0
   status:     WIP (work in progress)
   version:    0.20250218_2339
   changes:    2024-06-20, rgf   - add support for new TraceObject entries RECEIVER and
                                   VARIABLE (stringtable NAME, VALUE, ASSIGNMENT=.true|.false)
               2024-07-01, rgf   - adjust for processing new entries RECEIVER, VARIABLE (has
                                   a StringTable with information)
                                 - toJson, fromJson, toCSV, fromCSV, toXml, fromXml
               2024-07-20, rgf   - adjust to new TraceObject entries (e.g. ISWAITING, CALLERSTACKFRAME)
               2024-07-21        - do not flatten [CALLER]STACKFRAME, create StringTable (Direcotry) for them
               2024-07-22        - also mark "GUARD ON" as waiting if no instructions follow in the same invocation
               2024-08-19        - change frame entry "TARGETTYPE" to "TARGETCANONICALNAME" (e.g. "a Test" or "The Test class")
               2024-08-30        - ... many changes, now also sets isBlocked for callers/invoker dependent
                                   on method that waits (guard on, guard on when, entering invocation)
               2024-12-29        - start implementing profiling from a tracelog
               2025-02-05        - intentionally only supports SQLite as there is no "standard"
                                   SQL implementation among the RDMBS that would allow to create
                                   a SQL script that works on all of them; SQLite has become fast
                                   and powerful enough (including the availablity of the most
                                   important analytical functions) for the purpose of analysis
                                   of ooRexx tracelogs

   WIP (work in progress, alpha) 2025-02-05
   author: Rony G. Flatscher, 2025, planned to be released under AL 2.0 and CPL 1.0

*/


/** An ooRexx package (program) that defines utility routines, classes and methods
*   for working with TraceObject log data.
*
*  @since 20240201 (ooRexx 5.1.0)
*
*/

pkgLocal=.context~package~local  -- get access to this package local directory

pkgLocal~cr.lf               = "0d0a"x
pkgLocal~non.printable.ascii = xrange("00"x,"1F"x)||"FF"x   -- like rgf_util2.rex
-- pkgLocal~encoding.utf        = .false  -- TODO: replace once UTF-8 can be expected to .true, relevant for escape2()

   -- translate index names to title names
pkgLocal["ENTRY.NAMES"] = .stringTable~of(                     -
            ("ARGUMENTS"            ,"arguments"            ), -
            ("ATTRIBUTEPOOL"        ,"attributePool"        ), -
            ("CALLERSTACKFRAME"     ,"callerStackFrame"     ), -  -- since July 2024 by ooRexx
            ("EXECUTABLEPACKAGE"    ,"executablePackage"    ), -
            ("EXECUTABLEID"         ,"executableId"         ), -
            ("HASSCOPELOCK"         ,"hasScopeLock"         ), -
            ("INTERPRETER"          ,"interpreter"          ), -
            ("INVOCATION"           ,"invocation"           ), -
            ("ISBLOCKED"            ,"isBlocked"            ), -  -- August 30 2024
            ("ISGUARDED"            ,"isGuarded"            ), -
            ("ISWAITING"            ,"isWaiting"            ), -  -- since July 2024 by ooRexx; and annotation (if blocked invocation entries)
            ("LINE"                 ,"line"                 ), -  -- via StackFrame
            ("LINENR"               ,"lineNr"               ), -  -- via StackFrame
            ("NAME"                 ,"name"                 ), -  -- via StackFrame
            ("NUMBER"               ,"number"               ), -
            ("OPTION"               ,"option"               ), -
            ("PACKAGE"              ,"package"              ), -  -- via StackFrame
            ("RECEIVER"             ,"receiver"             ), -  -- new (June 2024), synonym for TARGET
            ("RECEIVERID"           ,"receiverId"           ), -  -- new (June 2024), synonym for TARGET
            ("RECEIVERCANONICALNAME","receiverCanonicalName"), -  -- new (June 2024), synonym for TARGET
            ("SCOPE"                ,"scope"                ), -  -- via StackFrame (method)
            ("SCOPEID"              ,"scopeId"              ), -  -- via StackFrame (method)
            ("SCOPELOCKCOUNT"       ,"scopeLockCount"       ), -
            ("SCOPEPACKAGE"         ,"scopePackage"         ), -  -- via StackFrame (method)
            ("STACKFRAME"           ,"stackFrame"           ), -
            ("TARGET"               ,"target"               ), - -- via StackFrame (object)
            ("TARGETID"             ,"targetId"             ), - -- via StackFrame (object)
            ("TARGETPACKAGE"        ,"targetPackage"        ), - -- via StackFrame (object) | -- ("TARGETTYPE"           ,"targetType"  ), - -- via StackFrame (object)
            ("TARGETPACKAGEID"      ,"targetPackageId"      ), - -- via StackFrame (object)
            ("TARGETCANONICALNAME"  ,"targetCanonicalName"  ), - -- via StackFrame (object)
            ("THREAD"               ,"thread"               ), -
            ("TIMESTAMP"            ,"timestamp"            ), -
            ("TRACELINE"            ,"traceLine"            ), -
            ("TYPE"                 ,"type"                 ), -  -- via StackFrame
            ("VARIABLE"             ,"variable"             )  -  -- VARIABLE, new (June 2024)
        )


  -- VARIABLE: entry is a StringTable: INDEX -> replacementText for externalizing
pkgLocal["ENTRY.NAMES.VARIABLE"] = .stringTable~of(    -     -- new (June 2024)
            ("NAME"             ,"name"             ), -
            ("VALUE"            ,"value"            ), -    -- for the string value
            ("VALUETYPE"        ,"valueType"        ), -    -- the type of the value
            ("VALUEID"          ,"valueId"          ), -    -- for the IdentityHash string value
            ("ASSIGNMENT"       ,"assignment"       )  )

  -- STACKFRAME: entry is a StringTable: INDEX -> replacementText for externalizing
pkgLocal["ENTRY.NAMES.STACKFRAME"] = .stringTable~of(  -     -- new (July 2024)
            ("ARGUMENTS"          ,"arguments"           ), -
            ("EXECUTABLEPACKAGE"  ,"executablePackage"   ), -
            ("EXECUTABLEID"       ,"executableId"        ), -
            ("INVOCATION"         ,"invocation"          ), -
            ("LINE"               ,"line"                ), -
            ("NAME"               ,"name"                ), -
            ("PACKAGE"            ,"package"             ), -
            ("SCOPE"              ,"scope"               ), -
            ("SCOPEID"            ,"scopeId"             ), -
            ("SCOPEPACKAGE"       ,"scopePackage"        ), -
            ("TARGET"             ,"target"              ), -   -- | -- ("TARGETTYPE"         ,"targetType"          ), -
            ("TARGETCANONICALNAME","targetCanonicalName" ), -
            ("TARGETID"           ,"targetId"            ), -
            ("TARGETPACKAGE"      ,"targetPackage"       ), -
            ("TARGETPACKAGEID"    ,"targetPackageId"     ), - -- via StackFrame (object)
            ("TRACELINE"          ,"traceLine"           ), -
            ("THREAD"             ,"thread"              ), -  -- 20240818: added in spawnReply() to indicate a start or reply spawn
            ("TYPE"               ,"type"                )  )

   -- use alphabetic order
pkgLocal["FIELD.ORDER.STACKFRAME"] = .entry.names.stackframe~allindexes~sort

   -- order to use for creating JSON/CSV/XML files fields/columns
pkgLocal["FIELD.ORDER"] = ("OPTION", "NUMBER", "TIMESTAMP", "INTERPRETER",  -
                          "THREAD",     -
                          "INVOCATION", -
                          "LINENR",  -
                          "CALLERSTACKFRAME", -    -- new (July 2024)
                          "STACKFRAME", -    -- new (July 2024)
                          "VARIABLE", -      -- new (June 2024)
                          "RECEIVER", -               -- new (June 2024), same as "TARGET"
                          "RECEIVERCANONICALNAME", -  -- new (July 2024), same as "TARGET"
                          "RECEIVERID", -             -- new (June 2024), same as "TARGETID"
                          "ATTRIBUTEPOOL", -
                          "SCOPELOCKCOUNT", -
                          "ISGUARDED",  -
                          "HASSCOPELOCK", -
                          "ISWAITING", -
                          "ISBLOCKED", -
                          "TRACELINE"  -
                          )

   -- includes any fields added by annotation (ISBLOCKED since 202408)
pkgLocal["FIELD.ORDER.ANNOTATED"] = ("OPTION", "NUMBER", "TIMESTAMP", "INTERPRETER",  -
                          "THREAD",     -
                          "INVOCATION", -
                          "LINENR", -
                          "CALLERSTACKFRAME", -       -- new (July 2024)
                          "STACKFRAME", -             -- new (July 2024)
                          "VARIABLE", -               -- new (June 2024)
                          "RECEIVER", -               -- new (June 2024), same as "TARGET"
                          "RECEIVERCANONICALNAME", -  -- new (July 2024), same as "TARGET"
                          "RECEIVERID", -             -- new (June 2024), same as "TARGETID"
                          "ATTRIBUTEPOOL", -
                          "SCOPELOCKCOUNT", -
                          "ISGUARDED",  -
                          "HASSCOPELOCK", -
                          "ISWAITING", -
                          "ISBLOCKED", -
                          "TRACELINE"  -
                          )


   -- entries that are only available if method routine gets traced (object-related)
pkgLocal["OBJECT.RELATED"] = .set~of("ATTRIBUTEPOOL",  "ISGUARDED", -
                                     "RECEIVER", "RECEIVERID", "RECEIVERCANONICALNAME", -
                                     "SCOPELOCKCOUNT", "HASSCOPELOCK" -
                                     "ISWAITING"  -
                                     "ISBLOCKED", -
                                     )

   -- object-/method-related
pkgLocal["OBJECT.RELATED.ANNOTATED"] = .object.related~copy

   -- define needle for adding, querying, removing "::options trace x"
pkgLocal~trace.needle="-- added by tracetool.rex"


::requires "json.cls"         -- get ooRexx distributed support for JSON
::requires "csvStream.cls"    -- get ooRexx distributed support for CSV



/* ======================================================================== */

/** Create a JSON rendering from supplied collection.
 *
 * @param collection
 * @param option "M[inimal]" ... minimal, "C[RLF]" ... minimal, but CR-LF after each traceObject,
 *               "H[uman]" ... human legible
 *
 * @return a string encoded as JSON representing all of the traceObjects in "collection"
*/
::routine toJson              public
  use strict arg collection, option="C"

  bGotProcessed=processTraceObjectLog(collection)  -- make sure STACKFRAME entry gets processed, if necessary
  opt=option~left(1)~upper
  if pos(opt,"MCH")=0 then
     raise syntax 93.914 array (1, '"M" (minimal), "C" (minimal with CRLF) or "H" (human legible)', arg(1))

  indent="   "    -- if human legible use CRLF and indentation
  indent2=indent~copies(2)
  mb=.MutableBuffer~new
  mb~append("[")
  ch?=pos(opt,"CH")>0

  tmpFieldOrder=.field.order.annotated
  maxOrder=tmpFieldOrder~items   -- determine number of fields
  maxColl=collection~items       -- determine number of traceobjects

  crlftab="0d 0a 09 09"x

  if ch? then mb~append(.cr.lf)
  do counter c traceObj over collection
     if opt='H' then mb~append(indent)

     noObjInfos?=(traceObj~stackFrame~type<>"METHOD")

     mb~append("{")
     if opt='H' then mb~append(.cr.lf,indent2)

     do counter c2 idx over tmpFieldOrder   -- show entries
        -- not in a method, skip any method related entries
        if noObjInfos?, .object.related.annotated~hasIndex(idx) then
            iterate

        if \traceObj~hasEntry(idx) then
            iterate

        val=traceObj[idx]
         -- "VARIABLE"-entry only available if TRACE I and a variable resolution or variable assignment
        if val~isNil, wordpos(idx, "CALLERSTACKFRAME HASSCOPELOCK ISGUARDED ISWAITING ISBLOCKED VARIABLE")>0 then
           iterate -- skip

        -- a method in hand
        mb~append('"',.entry.names[idx],'":')
        if ch? then mb~append(' ')

        select case idx
            -- number
        when "ATTRIBUTEPOOL", "INTERPRETER", "INVOCATION", "LINENR", -
             "NUMBER", "SCOPELOCKCOUNT", "THREAD" then mb~append(val)

            -- boolean
        when "HASSCOPELOCK", "ISGUARDED", "ISWAITING", "ISBLOCKED" then
                 mb~append(val~?("true","false"))

        when "STACKFRAME", "CALLERSTACKFRAME" then
             do
                 -- "val" is the StringTable containing information on the stackframe
                 stackIndices=.field.order.stackframe
                 stackIdxItems=stackIndices~items
                 mb~append("{")
                 if ch? then mb~append(crlftab, ' ')
                 do counter stackC stackIdx over stackIndices
                    if \val~hasEntry(stackIdx) then
                       iterate

                    mb~append('"',.entry.names.stackFrame[stackIdx],'":') -- add name

                    if ch? then mb~append(' ')
                    -- tmpVal=val[stackIdx~upper]
                    tmpVal=val[stackIdx]

                    if stackIdx="ARGUMENTS", tmpVal~isA(.array) then   -- add value
                       tmpVal=tmpVal~makeString(,",") -- turn into a comma delimited string
                    else
                    do
                       if tmpVal~isNil then
                          mb~append("null")
                       else if wordpos(stackIdx, "INVOCATION LINE THREAD")>0 then
                          mb~append(tmpVal)
                       else
                          mb~append('"',escJson(tmpVal),'"')
                    end

                    if stackC<stackIdxItems then   -- append comma, if not last StringTable item
                       mb~append(",")
                    if ch? then
                       mb~append(crlftab, ' ')
                 end
                 mb~append("}")
             end

        when "VARIABLE" then  -- June 2024: stores a StringTable with variable related information
             do
                 -- "val" is the StringTable containing information on the traced variable
                 mb~append("{")
                 if ch? then mb~append(crlftab, ' ')
                 -- add attributes: NAME, VALUE, VALUEID, ASSIGNMENT
                  -- NAME entry
                 mb~append('"',.entry.names.variable['NAME'],'":')
                 if ch? then mb~append(' ')
                 mb~append('"',val['NAME'],'",')

                  -- VALUE  entry
                 varValue=val["VALUE"]    -- get value entry
                 if ch? then mb~append(crlftab, ' ')
                 mb~append('"',.entry.names.variable['VALUE'],'":')
                 if ch? then mb~append(' ')
                 mb~append('"',varValue~string~changeStr('"','\"'),'",')

                  -- VALUETYPE
                 if ch? then mb~append(crlftab, ' ')
                 mb~append('"',.entry.names.variable['VALUETYPE'],'":')
                 if ch? then mb~append(' ')
                 mb~append('"',canonicalObjectName(varValue)~changeStr('"','\"'),'",')

                  -- VALUEID
                 if ch? then mb~append(crlftab, ' ')
                 mb~append('"',.entry.names.variable['VALUEID'],'":')
                 if ch? then mb~append(' ')
                 mb~append('"',id2x(varValue~identityHash),'",')

                  -- ASSIGNMENT entry (.true,.false)
                 if ch? then mb~append(crlftab, ' ')
                 mb~append('"',.entry.names.variable['ASSIGNMENT'],'":')
                 if ch? then mb~append(' ')
                 mb~append(val["ASSIGNMENT"]~?("true","false"))
                 if ch? then mb~append(crlftab, ' ')
                 mb~append("}")
             end

            -- string
        otherwise -- "TIMESPAN", "TRACELINE", "OPTION", ... some METHOD related entries can be .nil, make that seen
             mb~append('"',escJson(nilString(val)),'"')
        end

        if c2<>maxOrder then
        do
           mb~append(",")
           if opt='H' then mb~append(.cr.lf,indent2)
        end
     end
     if opt='H' then mb~append(.cr.lf,indent)
     mb~append("}")
     if maxColl<>c then     -- not last item?
        mb~append(",")

     if ch? then mb~append(.cr.lf)
  end
  mb~append("]")
  return mb~string

escJson: procedure      -- escape double quote and backslash in JSON style
  parse arg val
  return val~changeStr('\','\\') ~changeStr('"', '\"')

/* ======================================================================== */

::routine toJsonFile          public
  use strict arg fn, arr, option='C'   -- Crlf: almost minimal, but each traceObject in its own line
  jsonData=toJson(arr,option)    -- turn traceObjects into json
  call writeFile fn, jsonData    -- write to file
  return

/* ======================================================================== */

::routine fromJsonFile        public
  use strict arg fn

  inArray=.json~fromJsonFile(fn)
  toArray=.array~new
  do counter c1 inObj over inArray
     traceObj=.traceObject~new
     do idx over inObj~allIndexes
        select case idx~upper
        when "TIMESTAMP" then    -- recreate DateTime instance
           traceObj~setEntry(idx,.dateTime~fromIsoDate(inObj[idx]))

        when "STACKFRAME", "CALLERSTACKFRAME", "VARIABLE" then     -- recreate and store StringTable
        do
           coll=inObj[idx]       -- get collection describing variable
           st=.StringTable~new   -- stores variable information
           do with index varIdx item varItem over coll
              st~setEntry(varIdx, fromNilString(varItem))   -- store with uppercased index
           end
           traceObj~setEntry(idx,st)   -- save StringTable
        end
        otherwise
           traceObj~setEntry(idx,fromNilString(inObj[idx]))
        end
     end
     toArray~append(traceObj)
  end

  return toArray



/* ========================================================================= */

/** Create a CSV rendering from supplied collection.
 *
 * @param collection the collection of traceObjects
 * @param createTitle? indicates whether to supply a title line (default: .true)
 *
 * @return a string formatted as CSV (comma separated values) representing
 *         the traceObjects supplied via "collection"
 * @return a string encoded as CSV (comma separated values representing all of
 *         the traceObjects in "collection"
*/
::routine toCSV               public
  use strict arg collection, createTitle?=.true
  bGotProcessed=processTraceObjectLog(collection)  -- make sure STACKFRAME entry gets processed, if necessary
  crlf  ="0d0a"x  -- CR-LF
  mb=.MutableBuffer~new

  tmpFieldOrder=.field.order.annotated
  maxOrder=tmpFieldOrder~items    -- determine number of fields
  maxColl=collection~items       -- determine number of traceobjects
  if createTitle?=.true then
     call createTitleLine mb, maxOrder, tmpFieldOrder
  do counter c0 traceObj over collection
     noObjInfos?=(traceObj~stackFrame~TYPE<>"METHOD")   -- object related entries available?
     do counter c2 idx over tmpFieldOrder   -- show entries
        -- not in a method, skip any method related entries
        if noObjInfos?, .object.related.annotated~hasIndex(idx) then  -- skip?
        do
           mb~append(',')        -- empty column
           iterate
        end

        if \traceObj~hasEntry(idx) then
        do
           mb~append(',')        -- empty column
           iterate
        end

        val=traceObj[idx]
        if val~isNil, wordpos(idx, "CALLERSTACKFRAME HASSCOPELOCK ISGUARDED ISWAITING ISBLOCKED VARIABLE")>0 then -- skip
        do
           mb~append(',')        -- empty column
           iterate
        end

         -- VARIABLE entry only available if TRACE I in effect
        else if idx="VARIABLE" then   -- val is a StringTable
        do
           if val~isNil then val=''  -- do not show an entry in CSV, not even ".nil"
           else
           do
              varName      =val~name
              varValue     =val~value
              varValueType =canonicalObjectName(varValue)
              varValueId   =id2x(varValue~identityHash)
              varAssignment=val~assignment
              varValue = nilString(varValue)

              varMb=.mutableBuffer~new
              varMb~append(varName, varAssignment~?(" <= ", " => "), "[",varValue~string,"]")
              varMb~append(" / type: ",varValueType," / id: ",varValueId,"")
              varMb~append(" | assignment=", varAssignment)
              val=varMb~string   -- replace StringTable with its content as a string
           end
        end

        else if wordpos(idx,"STACKFRAME CALLERSTACKFRAME")>0 then    -- val is a StringTable
        do
           if val~isNil then val=''    -- do not show an entry in CSV, not even ".nil"
           else
           do  -- loop over stackframe fields, make a single string out of all values present in StringTable
              stackMb=.mutableBuffer~new
              do stackIdx over .field.order.stackFrame
                 if \val~hasIndex(stackIdx) then iterate -- skip non-existing entries

                 stackMb~append(.entry.Names[stackIdx], ": ")
                 stackVal=val[stackIdx]
                 stackVal=nilString(stackVal)

                 -- special treatment: ARGUMENTS is an array
                 if stackVal~isA(.array) then
                     stackMb~append(stackVal~makeString(,","))
                 else
                     stackMb~append(stackVal~string)

                 stackMb~append(" / ")
              end
              val=stackMb~string   -- replace StringTable with its content as a string
           end
        end

        mb~append(quote(nilString(val),.true))   -- escape as traceline may contain quotes

        if c2<>maxOrder then mb~append(",")
     end

     if maxColl<>c0 then    -- not last traceObject ?
        mb~append(.cr.lf)
  end
  return mb~string

createTitleLine: procedure
   use arg mb, maxOrder, tmpFieldOrder
   do counter c idx over tmpFieldOrder   -- show entries
     mb~append(.entry.names[idx])
     if c<>maxOrder then mb~append(",")
   end
   return mb~append(.cr.lf)


/* ======================================================================== */

::routine toCsvFile           public
  use strict arg fn, arr, option=.true -- .true (write header line, default)

  csvData=toCsv(arr,option)      -- turn traceObjects into csv
  call writeFile fn, csvData     -- write to file

  return


/* ======================================================================== */

-- see ooRexx documentation "Rexx Extension Library Reference" (rexxextensions.pdf)
::routine fromCsvFile        public
  use strict arg fn
  toArray=.array~new
  csv=.csvStream~new(fn)
  csv~skipHeaders=.false                  -- we want the header row as normal line
  csv~open('read')
  arrHeaderFields=csv~CSVLinein
  do counter c val over arrHeaderFields   -- uppercase field names
     arrHeaderFields[c]=val~upper
  end

  if arrHeaderFields[1]<>"OPTION" then    -- no header fields from us
  do
     csv~close
     raise syntax 40.900 array ('"'fn'": CSV header (first line) does not start with a field named "OPTION" (written in any case)')
  end

  do while csv~chars>0
     fields=csv~CSVLinein
     traceObj=.traceObject~new
     do counter c0 hdrField over arrHeaderFields
        value=fromNilString(fields[c0]) -- if a .nil representation use .nil
        if hdrField="TIMESTAMP" then
           traceObj~setEntry(hdrField,.dateTime~fromIsoDate(value))

        else if hdrField="VARIABLE" then
        do
            if value<>"" then
            do
               st=.stringTable~new
               parse var value varName . "[" varValue "]" "/" varType "/" "id:" varId "|" "assignment=" varAssignment .
               st~name      =varName
               st~value     =varValue
               st~valueType =varType~strip
               st~valueId   =varId~strip
               st~assignment=varAssignment
               traceObj~setEntry(hdrField,st)
            end
        end

      -- NOTE: manually parsing, sequence and spelling must match!
        else if wordpos(hdrField, "STACKFRAME CALLERSTACKFRAME")>0 then
        do
            if value<>"" then
            do
               st=.stringTable~new
               arrPos = .array~new  -- get starting position of field
               nrFields=.field.order.stackframe~items
                  -- get the start positions
               do counter c fieldName over .field.order.stackframe
                  mixedFieldName = .entry.names.stackframe[fieldName]   -- get mixed name
                  if c=1 then    -- first argument
                     needle=mixedFieldName":"
                  else
                     needle="/" mixedFieldName":"

                  pos=pos(needle, value)
                  arrPos[c,1]=pos               -- start position
                  arrPos[c,2]=pos+needle~length -- start of value portion
               end

                  -- now extract and process the values
               do counter c fieldName over .field.order.stackframe
                  if arrPos[c,1]=0 then iterate    -- field not in encoded string

                  nextStart=0    -- beginning of next field
                  do i=c+1 while i<=nrFields     -- in case subsequent fields are missing
                     if arrPos[i,1]<>0 then
                     do
                        nextStart=arrPos[i,1]
                        leave
                     end
                  end

                  if nextStart=0 then  -- last field "/ type: ... / " in hand
                  do
                     fieldValue=value~substr(arrPos[c,2])~strip
                        -- remove trailing blank+slash
                     fieldValue=fieldValue~left(fieldValue~length-1)~strip
                  end
                  else
                  do
                     if fieldName="TRACELINE" then
                     do
                           -- remove first leading blank, keep remaining ones
                        fieldValue=value~substr(arrPos[c,2]+1, nextStart-arrPos[c,2]-2)
                        -- fieldValue=fieldValue~strip("trailing")
                     end
                     else
                     do
                        fieldValue=value~substr(arrPos[c,2], nextStart-arrPos[c,2])
                        fieldValue=fieldValue~strip
                     end
                  end

                     -- skip CSV columns that have no value unless arguments field in hand
                  if fieldValue="", fieldName<>"ARGUMENTS" then
                     iterate

                  fieldValue=fromNilString(fieldValue)

                  st~setEntry(fieldName, fieldValue)
               end

               traceObj~setEntry(hdrField,st)
            end
        end

        else if value<>"" then
           traceObj~setEntry(hdrField,value)
     end
     toArray~append(traceObj)
  end
  csv~close
  return toArray


/* ======================================================================== */

/** Create a XML rendering from supplied collection.
 *
 * @param collection
 * @param option "M[inimal]" ... minimal, "C[RLF]" ... minimal, but CR-LF after each traceObject,
 *               "H[uman]" ... human legible
 *
 * @return a string encoded as JSON representing all of the traceObjects in "collection"
*/
::routine toXml               public
  use strict arg collection, option="C"
  bGotProcessed=processTraceObjectLog(collection)  -- make sure STACKFRAME entry gets processed, if necessary
  opt=option~left(1)~upper
  if pos(opt,"MCH")=0 then
     raise syntax 93.914 array (1, '"M" (minimal), "C" (minimal with CRLF) or "H" (human legible)', arg(1))
  ch?=pos(opt,"CH")>0

  indent="   "    -- if human legible use CRLF and indentation
  indent2=indent~copies(2)
  indent3=indent~copies(3)
  mb=.MutableBuffer~new
  mb~append("<traceLog>")

  tmpFieldOrder=.field.order.annotated
  maxOrder=tmpFieldOrder~items   -- determine number of fields
  maxColl=collection~items       -- determine number of traceobjects

  if ch? then mb~append(.cr.lf)
  do counter c traceObj over collection
     noObjInfos?=(traceObj~stackFrame~TYPE<>"METHOD")   -- object related entries available?

     if opt='H' then
        mb~append(indent, "<traceObject>", .cr.lf, indent2)
     else
        mb~append("<traceObject>")

     do counter c2 idx over tmpFieldOrder   -- show entries

        if noObjInfos?, .object.related.annotated~hasIndex(idx) -- skip?
           then iterate

        if \traceObj~hasEntry(idx) then
           iterate

        val=traceObj[idx]
         -- "VARIABLE"-entry only available if TRACE I and a variable resolution or variable assignment
        if val~isNil, wordpos(idx, "CALLERSTACKFRAME HASSCOPELOCK ISGUARDED ISWAITING ISBLOCKED VARIABLE")>0 then
           iterate -- skip

        tagName=.entry.names[idx]
        mb~append('<',tagName,'>')

        select case idx
            when "TRACELINE" then mb~append(escXml(val))

            when "STACKFRAME", "CALLERSTACKFRAME" then
                 do
                     -- "val" is the StringTable containing information on the stackframe
                     stackIndices=.field.order.stackframe
                     stackIdxItems=stackIndices~items

                     do counter stackC stackIdx over stackIndices
                        if \val~hasEntry(stackIdx) then
                           iterate

                       stackTagName=.entry.names.stackframe[stackIdx]
                       if opt='H' then mb~append(.cr.lf, indent3)
                       mb~append('<',stackTagName,'>')

                       tmpVal=val[stackIdx]

                       if stackIdx="ARGUMENTS" then   -- add value
                          if tmpVal~isA(.array) then
                             tmpVal=tmpVal~makeString(,",")

                       mb~append(escXml(nilString(tmpVal)))
                       mb~append('</',stackTagName,'>')
                     end

                     if opt='H' then mb~append(.cr.lf, indent2)
                 end

            when "VARIABLE" then  -- June 2024: stores a StringTable with variable related information
                 do
                    -- val is the stringTable with variable information
                    varTagName=.entry.names.variable["NAME"]
                    if opt='H' then mb~append(.cr.lf, indent3)
                    mb~append('<',varTagName,'>')
                    mb~append(val["NAME"])
                    mb~append('</',varTagName,'>')

                    varTagName=.entry.names.variable["VALUE"]
                    varValue=val["VALUE"]
                    if opt='H' then mb~append(.cr.lf, indent3)
                    mb~append('<',varTagName,'>')
                    mb~append(escXml(varValue~string))
                    mb~append('</',varTagName,'>')

                    varTagName=.entry.names.variable["VALUETYPE"]
                    if opt='H' then mb~append(.cr.lf, indent3)
                    mb~append('<',varTagName,'>')
                    mb~append(canonicalObjectName(varValue))
                    mb~append('</',varTagName,'>')

                    varTagName=.entry.names.variable["VALUEID"]
                    if opt='H' then mb~append(.cr.lf, indent3)
                    mb~append('<',varTagName,'>')
                    mb~append(id2x(varValue~identityHash))
                    mb~append('</',varTagName,'>')

                    varTagName=.entry.names.variable["ASSIGNMENT"]
                    if opt='H' then mb~append(.cr.lf, indent3)
                    mb~append('<',varTagName,'>')
                    mb~append(val["ASSIGNMENT"])
                    mb~append('</',varTagName,'>')
                    if opt='H' then mb~append(.cr.lf, indent2)
                 end
            otherwise
                mb~append(nilString(val))
        end

        mb~append("</",tagName,">")
        if c2<>maxOrder then
        do
           if opt='H' then mb~append(.cr.lf,indent2)
        end
     end

     if opt='H' then
        mb~append(.cr.lf, indent, "</traceObject>", .cr.lf) -- add a CR-LF
     else
        mb~append("</traceObject>", ch?~?(.cr.lf,"")) -- add a CR-LF
  end
  mb~append("</traceLog>")
  return mb~string

escXml: procedure      -- escape double quote and backslash in JSON style
  parse arg val
  return val~changeStr('&','&amp;') ~changeStr('<','&lt;') ~changeStr('>','&gt;')


/* ======================================================================== */

::routine nilString     -- we use ooRexx environment symbol ".nil" to represent it as a string
  use arg val
  if val~isNil then return ".nil"
  return val

/* ======================================================================== */

::routine fromNilString    -- turn the (expected) string ".nil" to .nil
  use arg val
  if val~isNil            then return .nil
  if val~upper=".NIL"     then return .nil
  if val="The NIL object" then return .nil
  return val

/* ======================================================================== */

::routine toXmlFile     public
  use strict arg fn, arr, option='C'   -- Crlf: almost minimal, but each traceObject in its own line

  xmlData=toXml(arr,option)    -- turn traceObjects into xml
  call writeFile fn, xmlData   -- write to file
  return

/* ======================================================================== */

::routine fromXmlFile        public
  use strict arg fn
  s=.stream~new(fn)~~open('read')
  data=s~charIn(1,s~chars)  -- read entire content
  s~close

  toArray=.array~new
  parse var data '<traceLog>' data '</traceLog>'
  data=data~translate("   ","0d0a"x)  -- translate CR and LF to a blank
  do while data<>""
     parse var data '<traceObject>' traceObjData '</traceObject>' data
     if traceObjData<>"" then
     do
        traceObj=.traceObject~new
        do while traceObjData<>""   -- parse traceObject data

           parse var traceObjData '<' startTag '>' .
           if wordpos(startTag~upper, "STACKFRAME CALLERSTACKFRAME VARIABLE")>0 then
           do
               endTag='</'startTag'>'
               parse var traceObjData '<' startTag '>' strContainedElements (endTag) traceObjData

               st=.StringTable~new
               do while strContainedElements<>""   -- now parse the value related entities
                  parse var strContainedElements '<' containedStartTag '>' containedValue '</' containedEndTag '>' strContainedElements
                  if containedStartTag<>containedEndTag then     -- not a proper XML encoding
                     raise syntax 40.900 array ('"'fn'": not a proper XML encoding, containedStartTag='pp(containedStartTag) "<> containedEndTag="pp(containedEndTag))
                     st~setEntry(containedStartTag,fromNilString(unescXml(containedValue)))
               end
               -- set variables to allow standard processing
               endTag=startTag   -- remove brackets from endtag
               value=st          -- assign StringTable
           end
           else   -- any other element without nested elements
           do
              parse var traceObjData '<' startTag '>' value '</' endTag '>' traceObjData
           end

           if startTag<>endTag then     -- not a proper XML encoding
              raise syntax 40.900 array ('"'fn'": not a proper XML encoding, startTag='pp(startTag) "<> endTag="pp(endTag))

           ucTag = startTag~upper   -- uppercase tagname

           value=fromNilString(value)  -- if '.nil' replace with .nil

           if \value~isNil then
           do
              if ucTag="TRACELINE" then value=unescXml(value)
              else if ucTag="TIMESTAMP" then value=.dateTime~fromIsoDate(value)
           end
           traceObj~setEntry(ucTag,value) -- save value
        end
        if traceObj~items>0 then    -- has content?
           toArray~append(traceObj) -- save traceObject
     end
  end
  return toArray

unescXml: procedure
  parse arg val
  return val~changeStr('&gt;','>') ~changeStr('&lt;','<') ~changeStr('&amp;','&')


/* ======================================================================== */

::routine quote               public
  use strict arg val, escape=.false
  if \val~isNil, escape then
     return '"' || val~makeString~changeStr('"','""') || '"'
  return '"'val'"'

/* ======================================================================== */

::routine writeFile
  use strict arg fn, data
  s=.stream~new(fn)
  s~~open("write replace") ~~charout(data) ~~close -- write all bytes
  return


/* ========================================================================= */


/* ========================================================================= */
/* Analyze trace objects and determine the guard state (currentGuardState; 'g'|'u') 'g'uarded, 'u'unguarded
 * at runtime and the wait state (isWaiting; 'r'|'B') 'r'unning, 'B'locked
 *
 * @param  collection
 * @return copy of recevied collection
*/
::routine annotateRuntimeState public
   use strict arg coll

   bGotProcessed=processTraceObjectLog(coll)  -- make sure STACKFRAME entry gets processed, if necessary

   myArr=coll~makeArray
signal on syntax

      -- sort by attributePools, thread, invocation and number
   myArr~sortWith(.sortByAttributePool_Thread_Invocation_Number~new)
   if myArr~lastItem~stackFrame~type<>"METHOD" then  -- no method related annotations necessary, return what we got
      return myArr~sort

   firstMethodIdx=findFirstMethodTraceObject(myArr)  -- binary search first method related TraceObject
   if firstMethodIdx<>-1 then
      call annotateWaitState myArr, firstMethodIdx

   return myArr~sort    -- sort ascendingly by number, reinstating the original sequence

syntax:
   co=condition('obj')
   call showCo .line, co
   -- call "rgf_util2.rex"; say ppCondition2(co)
   say "---"
   raise propagate

::routine showCO public -- TODO: remove, just meant for the WIP version
   use arg line, co
   .error~say( "--> an unexpected syntax condition occurred in line #" pp(line)", co (BEGIN):" )
   do counter c idx over co~allindexes~sort
      .error~say( "    //-->" pp(idx)~left(15,'.') pp(co[idx]) )
      if wordpos(idx, "STACKFRAMES TRACEBACK")>0 then
      do
         do s over co[idx]
           .error~say( "             //-->" pp(s) )
         end
      end
   end
   .error~say( "<-- an unexpected syntax condition occurred, co (END)." "(generated by 'showCo' in line:" (.line-12)")")
   .error~say( '---' )
   return



/* ========================================================================= */
/** Analyze "guard [on|oiff] when ...", determine and annotate traceObjects in wait (block) state
*  @param myArr array of traceObjcts sorted ATIN (attribute, thread, invocation, number)
*  @param startIdx index into array pointing to the first method related TraceObject
*/
-- needs to be sorted as: myArr~sortWith(.sortByAttributePool_Thread_Invocation_Number~new)
::routine annotateWaitState
   use strict arg myArr, startIdx=1

   signal on syntax
   arrItems=myArr~items

   arrBlockedInvocations=.array~new
   arrInvocations=.array~new   -- collect TraceObjects for invocation entries/exits
   do i=1 to startIdx-1    -- get the routine invocation traces
      traceObj=myArr[i]
      -- if invocation entry/exit, collect traceObject
      if wordpos(traceObj~traceLine~word(1), ">I> <I<")>0 then
      do
         arrInvocations~append((traceObj,i))    -- save as traceObject and position in myArr
      end
   end

   -- 20240720, rgf: only check for blocked invocations (if ">I>" has no further traceobjects assume isWaiting=.true)
   -- 20240722, rgf: the same for GUARD ON as last statement of its invocation chain
   bInvocationEntry=.false
   do i=startIdx to arrItems
      traceObj=myArr[i]
      parse upper value traceObj["TRACELINE"] with 1 xline +6 8 xprefix +3 12 xw1 xw2 xw3 .

      -- if invocation entry/exit, collect traceObject
      if wordpos(xprefix, ">I> <I<")>0 then
         arrInvocations~append((traceObj,i))    -- save as traceObject and position in myArr

      /* assume hanging (waiting), if invocation entry or GUARD ON (without a when condition)
       *  or a "WHEN" evaluation yielding "0" are the last trace objects within the invocation ID */
      if xprefix=">I>" | (xprefix=">K>" & xw1='"WHEN"' & xw2="=>" & xw3='"0"') | -
                         ((xw1 xw2)="GUARD ON" & xw3<>"WHEN")
      then
      do
         if i = arrItems then   -- no subsequent trace object, hence assume waiting (hanging, blocking)
         do
            traceObj["ISWAITING"]=.true
            if xprefix=">I>" | ((xw1 xw2)="GUARD ON") then
               traceObj["ISBLOCKED"]=.true

               -- mark all callers as blocked
            arrBlockedInvocations~append((traceObj,i))   -- save traceObj and its index into myArr

            -- waiting for guard lock for "GUARD ON" (hanging, blocking)
         end
         else if traceObj~invocation <> myArr[i+1]~invocation then
         do
            traceObj["ISWAITING"]=.true
            if xprefix=">I>" | ((xw1 xw2)="GUARD ON") then
               traceObj["ISBLOCKED"]=.true

               -- mark all callers as blocked
            arrBlockedInvocations~append((traceObj,i))   -- save traceObj and its index into myArr
         end
      end
   end

   if arrBlockedInvocations~items>0 then  -- need mark blocked callers/invokers?
      call processBlockedInvocations myArr, arrInvocations, arrBlockedInvocations
   return

   -- block all callers/invokers
processBlockedInvocations: procedure
   use strict arg myArr, arrInvocations, arrBlockedInvocations

   do i=arrBlockedInvocations~items to 1 by -1
      currArr=arrBlockedInvocations[i]
      traceObj=currArr[1]   -- can be a "GUARD ON" or a ">I>"
      -- find trace entry with executableID being the same as the blocked statement
      currIdx=findTraceEntry(traceObj, arrInvocations)
      if currIdx>0 then
      do
         traceObj=arrInvocations[currIdx][1]
         call markInvokerBeingBlocked myArr, traceObj, arrInvocations, currIdx
      end
   end
   return


   -- find and return index for arrInvocations of trace entry containing the blocked statement
findTraceEntry: procedure
   use strict arg traceObj, arrInvocations, idx=(arrInvocations~items)
      -- search position (idx) of invocation entry trace (>I>) in arrInvocations
   executableID=traceObj~stackframe~executableID
   do idx=idx to 1 by -1
      tmpTraceObj=arrInvocations[idx][1]
      if tmpTraceObj~stackFrame~executableID=executableID, tmpTraceObj~traceline~word(1)=">I>" then
         return idx
   end
   return 0


syntax:
   co=condition('obj')
   call showCo .line, co
   -- call "rgf_util2.rex"; say ppCondition2(co)
   say "---"
   raise propagate

   -- find invoker, mark invocation line as being blocked
markInvokerBeingBlocked: procedure
   use strict arg myArr, traceObj, arrInvocations, currIdx=(arrInvocations~items)
   callerSF=traceObj~callerStackFrame

   if callerSF~hasIndex("THREAD") then -- invoked from another thread (reply, start), cannot block
   do
         -- if entering a reply keyword statement, then stay and mark the caller/invoker statement to be blocked
      currTraceObj=myArr[arrInvocations[currIdx][2]]  -- fetch callerSF's traceObject
      if currTraceObj~traceLine~word(1)=">I>" then    -- trace entry
      do
         currSFTraceLine=currTraceObj~stackframe~traceLine~upper
            -- not a reply (hence a start message), cannot be blocked
         if \subword(currSFTraceLine,2)~startsWith("*-* REPLY") then
            return
         currIdx+=1  -- have this exact trace entry find again below, such that its last statement gets marked as blocked
      end
   end

   executableID=callerSF~executableID  -- get executable ID from caller stack frame
   if executableID~isNil then          -- invoked from compiled/native code, we lost trace as no callerStackFrame infos
      return

   -- find invoker executable, then locate last traceline and mark it as being blocked
   do while currIdx>1
      currIdx-=1     -- find previous ">I>"
      curr_arr=arrInvocations[currIdx]
      currTraceObj=curr_arr[1]  -- get traceObject entry
      if currTraceObj~traceLine~word(1)=">I>" then -- we found an invocation entry
      do
         if currTraceObj~stackFrame~executableID = executableID then -- the matching one ?
         do    -- we found the one, now get its last traceObj
             next_invoc_arr=arrInvocations[currIdx+1] -- position on next invocation trace
             posInMyArr=next_invoc_arr[2] -- get index in myArr

             tmpTO=myArr[posInMyArr-1] -- get previous TraceObject which is the caller/invoker
             tmpTO~isBlocked=.true     -- mark as blocked
             -- now recurse and mark the caller of this invocation as blocked as well, if any
             call markInvokerBeingBlocked myArr, currTraceObj, arrInvocations, currIdx-1
             return currIdx
         end
      end
   end
   return


/* ========================================================================= */
/** Binary search routine to find index of first TraceObject of a method.
* @param arr sorted array of traceObjects (ordered by attributepool and number)
* @return index of first method related TraceObject or <ocde>-1</code> if none found
*/
::routine findFirstMethodTraceObject  -- assumes order by attributepool, methods at the end, returns -1 if none
  use arg arr

  if arr~lastItem~stackFrame~type<>"METHOD" then  -- no method related TraceObject available, indicate with -1
     return -1

  left = 1                             -- first index
  right = arr~items                    -- last index
  do while left <= right
      m = (left + right) % 2           -- index that halves the sorted array
      if arr[m]~stackFrame~type<>"METHOD" then    -- not a method, search in right remaining half
         left = m + 1
      else                             -- a method TraceObject found
      do
          if arr[max(1,m-1)]~stackFrame~type="METHOD" then -- if next smaller a method, then search left remaining half
             right = m - 1
          else                         -- nope, we are at the first method TraceObject, return index
             return m
      end
  end
  return -1    -- not found, indicate with -1



/* ========================================================================= */
/*
 *  floating methods to format a traceObject
 */

/** Routine to return named floating method.
 * @param name the name of the floating method defined in this package
 * @return the method object or <code>.nil</code> if not found
*/
::routine getFloatingMethod public
  parse arg name
  return .methods~entry(name) -- return method object or .nil


/* ======================================================================== */

/** A floating method that formats traceObjects by prepending the <code>NUMBER</code>,
*   the longTime of <code>TIMESTAMP</code>, then supplies the information formatted
*   like .TraceObject~option's <code>Full</code> but adding method related annotation
 *  entries (i.e. <code>CURRENTGUARDSTATE</code> in lowercase letters "u" or "g",
 *  if differing from the defined guard state because of <code>GUARD</code> statements;
 *  <code>ISWAITING</code> with "W" if in wait/block state)
 *  Returns the resulting string.
 */
::method formatExtensiveWithAnnotations
  use arg traceObj

signal on syntax
  mb=.mutableBuffer~new
  mb~append('#', adjRight(str(traceObj~number),5), " | ")
  ts=traceObj~timeStamp
  if ts~isA(.DateTime) then mb~append(ts~longTime, " ")
                       else mb~append(" "~copies(16))

  mb~append("[")
  mb~append("R", adjLeft(str(traceObj["INTERPRETER"]),3), " ")  -- R_exx interpreter instance
  mb~append("T", adjLeft(str(traceObj["THREAD"])     ,3), " ")  -- T_hread/activity
  mb~append("I", adjLeft(str(traceObj["INVOCATION"]) ,4)     )  -- I_nvocation/activation
  ap=traceObj["ATTRIBUTEPOOL"]
  if \ap~isNil then        -- an object's variable dictionary in hand, we are in a method
  do
     mb~append(" ")
     isGuarded=str(traceObj["ISGUARDED"])
     if isGuarded='?' then
        mb~append(isGuarded)              -- ? (if not set), else G_uarded or U_unguarded
     else
        mb~append(isGuarded~?("G","U")) -- G_uarded or U_unguarded

     bHasScopeLock=str(traceObj["HASSCOPELOCK"])

     if      isGuarded=.true,  bHasScopeLock=.false then mb~append('u ')
     else if isGuarded=.false, bHasScopeLock=.true  then mb~append('g ')
     else mb~append("  ")

     mb~append("A", adjLeft(ap,4), " ")   -- Attribute pool (variable dictionary)
     mb~append("L", adjLeft(str(traceObj["SCOPELOCKCOUNT"]),3), " ") -- L ... lock reserve count

     if bHasScopeLock='?' then
        mb~append(bHasScopeLock)              -- indicates that value is not present
     else
        mb~append(bHasScopeLock~?("*"," "))   -- asterisk to indicate holding object lock (can execute)

     bIsWaiting=str(traceObj["ISWAITING"])
     bIsBlocked=str(traceObj["ISBLOCKED"]) -- from annotation
     if datatype(bIsBlocked,"O"), bIsBlocked then
        mb~append("B")
     else if datatype(bIsWaiting,"O") then -- a lOgical type ?
        mb~append(bIsWaiting~?("W"," "))
     else
        mb~append(" ")                -- not present: do not show run state at all

     mb~append("]  ")
  end
  else
  do
     mb~append("]                   ")  -- Full: make sure we align traceline
     if traceObj["ISBLOCKED"]=.true then
         mb~overlay("B",58)
  end

  mb~append(str(traceObj["TRACELINE"]))
  return mb~string


syntax:
   co=condition('obj')
   call showCo .line, co
   -- call "rgf_util2.rex"; say ppCondition2(co)
   say "---"
   raise propagate

str: procedure       -- make sure we supply a string if .nil, otherwise MutableBuffer causes an error
  use arg value
  if value~isNil then return '?' -- no entry, Rexx user omitted or deleted it
  return value

adjRight: procedure  -- must be within method
  use strict arg value, width=3
  if value~length>=width then return value
  return value~right(width)

adjLeft: procedure   -- must be within method
  use strict arg value, width=3
  if value~length>=width then return value
  return value~left(width)


/* ======================================================================== */

/** A floating method that formats traceObjects that supplies the information formatted
 *  like .TraceObject~option's <code>Full</code> in a dense format and method related annotation
 *  entries (i.e. <code>CURRENTGUARDSTATE</code> in lowercase letters "u" or "g",
 *  if differing from the defined guard state because of <code>GUARD</code> statements;
 *  <code>ISWAITING</code> with "W" if in wait/block state).
 *  Remark: meant for creating dense trace output for short programs, e.g. for articles,
 *  hence package information stripped.
 *
 * @param an annotated TraceObject
 * @param a trace line prepended with extended trace information in brackets in a dense format
 */

::method formatFullWithAnnotationsDense
  use arg traceObj

signal on syntax
  mb=.mutableBuffer~new

  mb~append("[")
  -- mb~append("R", adjLeft(str(traceObj["INTERPRETER"]),1), " ")  -- R_exx interpreter instance
  mb~append("T", adjLeft(str(traceObj["THREAD"])     ,1), " ")  -- T_hread/activity
  mb~append("I", adjLeft(str(traceObj["INVOCATION"]) ,1)     )  -- I_nvocation/activation
  ap=traceObj["ATTRIBUTEPOOL"]
  if \ap~isNil then        -- an object's variable dictionary in hand, we are in a method
  do
     mb~append(" ")
     isGuarded=str(traceObj["ISGUARDED"])
     if isGuarded='?' then
        mb~append(isGuarded)              -- ? (if not set), else G_uarded or U_unguarded
     else
        mb~append(isGuarded~?("G","U"))   -- G_uarded or U_unguarded

     bHasScopeLock=str(traceObj["HASSCOPELOCK"])

     if      isGuarded=.true,  bHasScopeLock=.false then mb~append('u ')
     else if isGuarded=.false, bHasScopeLock=.true  then mb~append('g ')
     else mb~append("  ")

     mb~append("A", adjLeft(ap,1), " ")   -- Attribute pool (variable dictionary)
     mb~append("L", adjLeft(str(traceObj["SCOPELOCKCOUNT"]),1), " ") -- L ... lock reserve count

     if bHasScopeLock='?' then
        mb~append(bHasScopeLock)              -- indicates that value is not present
     else
        mb~append(bHasScopeLock~?("*"," "))   -- asterisk to indicate holding object lock (can execute)

     bIsWaiting=str(traceObj["ISWAITING"])
     bIsBlocked=str(traceObj["ISBLOCKED"]) -- from annotation
     if datatype(bIsBlocked,"O"), bIsBlocked then
        mb~append("B")
     else if datatype(bIsWaiting,"O") then      -- a lOgical type ?
        mb~append(bIsWaiting~?("W"," "))   -- r_unning, W_ait | B_locked)
     else
        mb~append(" ")                 -- not present: do not show run state at all

     mb~append("] ")
  end
  else
  do
     mb~append("]                    ")  -- Full: make sure we align traceline
     if traceObj["ISBLOCKED"]=.true then
         mb~overlay("B",18)
  end


  -- mb~append(str(traceObj["TRACELINE"]))
  traceLine=str(traceObj["TRACELINE"])
  parse var traceLine prefix type localInfos 'in package' pkgName
  pkgName=pkgName~strip
  if pkgName<>"" then pkgName=pkgName~left(max(1,length(pkgName)-1))

  if wordPos(prefix, ">I> <I<")<>0 then    -- remove package name
  do
     bDoNotShowPackages=.true               -- do not show packages at all
     if bDoNotShowPackages=.true then
     do
        parse var traceLine traceLine " in package" . -- remove package information
     end
     else   -- only show packages if necessary and in dense format (not the full path)
     do
        if type="Routine", localInfos=pkgName then -- remove routine name and package are the same, remove it
        do
           parse var traceLine traceLine " in package" . -- remove package information
        end
        else if traceLine~pos("in package")>0 then
        do
            parse var traceLine before " in package " .
            traceLine=before "in package" reducePath(pkgName)"."
        end
     end
  end

  -- overlay, but make sure to leave extended trace prefix complete
  extPrefix=mb~string~strip   -- get extended trace prefix
  return extPrefix~overlay(traceLine~substr(4),max(extPrefix~length+1,23))

  return mb~string

reducePath: procedure -- reduce fully qualified package name to show last directory
   use arg fullPath
   dirSep=.file~separator
   lpos=fullPath~lastPos(dirSep)
   if lpos=0 then return fullPath   -- no file separator, not a fully qualified path
   lpos=fullPath~lastPos(dirSep,lpos-1)
   if lpos=0 then return fullPath   -- only one file separator, seems to be short enough
   return "..."fullPath~substr(lpos)


syntax:
   co=condition('obj')
   call showCo .line, co
   -- call "rgf_util2.rex"; say ppCondition2(co)
   say "---"
   raise propagate

str: procedure       -- make sure we supply a string if .nil, otherwise MutableBuffer causes an error
  use arg value
  if value~isNil then return '?' -- no entry, Rexx user omitted or deleted it
  return value

adjRight: procedure  -- must be within method
  use strict arg value, width=3
  if value~length>=width then return value
  return value~right(width)

adjLeft: procedure   -- must be within method
  use strict arg value, width=3
  if value~length>=width then return value
  return value~left(width)


/* ======================================================================== */

/** A floating method that formats traceObjects that supplies the information formatted
 *  like .TraceObject~option's <code>Full</code> in a dense format and method related annotation
 *  entries (i.e. <code>CURRENTGUARDSTATE</code> in lowercase letters "u" or "g",
 *  if differing from the defined guard state because of <code>GUARD</code> statements;
 *  <code>ISWAITING</code> with "W" if in wait/block state).
 *  Remark: meant for creating dense trace output for short programs, e.g. for articles,
 *  hence package information stripped. This variant caters for two digits for thread id,
 *  invocation id, attribute pool id and lock count.
 *
 * @param an annotated TraceObject
 * @param a trace line prepended with extended trace information in brackets in a dense format
 */

::method formatFullWithAnnotationsDense2
  use arg traceObj

signal on syntax
  mb=.mutableBuffer~new
  mb~append("[")
  -- mb~append("R", adjLeft(str(traceObj["INTERPRETER"]),1), " ")  -- R_exx interpreter instance
  mb~append("T", adjLeft(str(traceObj["THREAD"])     ,2), " ")  -- T_hread/activity
  mb~append("I", adjLeft(str(traceObj["INVOCATION"]) ,2)     )  -- I_nvocation/activation
  ap=traceObj["ATTRIBUTEPOOL"]
  if \ap~isNil then        -- an object's variable dictionary in hand, we are in a method
  do
     mb~append(" ")
     isGuarded=str(traceObj["ISGUARDED"])
     if isGuarded='?' then
        mb~append(isGuarded)              -- ? (if not set), else G_uarded or U_unguarded
     else
        mb~append(isGuarded~?("G","U"))   -- G_uarded or U_unguarded

     bHasScopeLock=str(traceObj["HASSCOPELOCK"])

     if      isGuarded=.true,  bHasScopeLock=.false then mb~append('u ')
     else if isGuarded=.false, bHasScopeLock=.true  then mb~append('g ')
     else mb~append("  ")

     mb~append("A", adjLeft(ap,2), " ")   -- Attribute pool (variable dictionary)
     mb~append("L", adjLeft(str(traceObj["SCOPELOCKCOUNT"]),2), " ") -- L ... lock reserve count

     if bHasScopeLock='?' then
        mb~append(bHasScopeLock)             -- indicates that value is not present
     else
        mb~append(bHasScopeLock~?("*"," "))  -- asterisk to indicate holding object lock (can execute)

     bIsWaiting=str(traceObj["ISWAITING"]) -- from annotation
     bIsBlocked=str(traceObj["ISBLOCKED"]) -- from annotation
     if datatype(bIsBlocked,"O"), bIsBlocked then
        mb~append("B")
     else if datatype(bIsWaiting,"O") then      -- a lOgical type ?
        mb~append(bIsWaiting~?("W"," ")) -- r_unning, W_ait | B_locked)
     else
        mb~append(" ")                 -- not present: do not show run state at all

     mb~append("] ")
  end
  else
  do
     mb~append("]                        ")  -- Full: make sure we align traceline
     if traceObj["ISBLOCKED"]=.true then
         mb~overlay("B",22)
  end

  traceLine=str(traceObj["TRACELINE"])
  parse var traceLine prefix type localInfos 'in package' pkgName
  pkgName=pkgName~strip
  if pkgName<>"" then pkgName=pkgName~left(max(1,length(pkgName)-1))

  if wordPos(prefix, ">I> <I<")<>0 then    -- remove package name
  do
     bDoNotShowPackages=.true               -- do not show packages at all
     if bDoNotShowPackages=.true then
     do
        parse var traceLine traceLine " in package" . -- remove package information
     end
     else   -- only show packages if necessary and in dense format (not the full path)
     do
        if type="Routine", localInfos=pkgName then -- remove routine name and package are the same, remove it
        do
           parse var traceLine traceLine " in package" . -- remove package information
        end
        else if traceLine~pos("in package")>0 then
        do
            parse var traceLine before " in package " .
            traceLine=before "in package" reducePath(pkgName)"."
        end
     end
  end

  -- overlay, but make sure to leave extended trace prefix complete
  extPrefix=mb~string~strip   -- get extended trace prefix
  return extPrefix~overlay(traceLine~substr(4),max(extPrefix~length+1,27))

  return mb~string

reducePath: procedure -- reduce fully qualified package name to show last directory
   use arg fullPath
   dirSep=.file~separator
   lpos=fullPath~lastPos(dirSep)
   if lpos=0 then return fullPath   -- no file separator, not a fully qualified path
   lpos=fullPath~lastPos(dirSep,lpos-1)
   if lpos=0 then return fullPath   -- only one file separator, seems to be short enough
   return "..."fullPath~substr(lpos)


syntax:
   co=condition('obj')
   call showCo .line, co
   -- call "rgf_util2.rex"; say ppCondition2(co)
   say "---"
   raise propagate

str: procedure       -- make sure we supply a string if .nil, otherwise MutableBuffer causes an error
  use arg value
  if value~isNil then return '?' -- no entry, Rexx user omitted or deleted it
  return value

adjRight: procedure  -- must be within method
  use strict arg value, width=3
  if value~length>=width then return value
  return value~right(width)

adjLeft: procedure   -- must be within method
  use strict arg value, width=3
  if value~length>=width then return value
  return value~left(width)


/* ========================================================================= */
/*
 * This comparator sorts the TraceObjects by interpreter, thread, invocation and number.
*/
::class sortByInterpreter_Thread_Invocation_Number subclass Comparator  public -- sort by thread, invocation, nr
::method compare
   use arg left, right

   val=sign(left~interpreter - right~interpreter)
   if val<>0 then return val

   val=sign(left~thread - right~thread)
   if val<>0 then return val

   -- both are equal, now sort by invocation number
   val=sign(left~invocation - right~invocation)
   if val<>0 then return val

   -- both are equal, now sort by number which is the original trace sequence
   return sign(left~number - right~number)



/* ========================================================================= */
/*
 * This comparator sorts the TraceObjects by invocation and number.
*/
::class sortByInvocation_Number subclass Comparator public  -- sort by invocation, nr
::method compare
   use arg left, right

   val=sign(left~invocation - right~invocation)
   if val<>0 then return val

   -- both are equal, now sort by number which is the original trace sequence
   return sign(left~number - right~number)


/* ========================================================================= */
/*
 * This comparator sorts the TraceObjects by number.
*/
::class sortByNumber subclass Comparator public  -- sort by invocation, nr
::method compare
   use arg left, right
   return sign(left~number - right~number)


/* ========================================================================= */
/*
 * This comparator sorts the TraceObjects by attributePool and number.
*/
::class sortByAttributePool_Number subclass Comparator  public -- attributePool, thread, invocation and number
::method compare
   use arg left, right

   apLeft =left~attributePool
   apRight=right~attributePool

   if \apLeft~isNil, \apRight~isNil then
   do
     -- both attribute pool numbers are present
     val=sign(apLeft - apRight)
     if val<>0 then return val

      -- bot are equal, now sort by nr which is the original trace sequence
      return sign(left~number - right~number)
   end

      -- both are not given, hence a routine, order by number
   if apLeft~isNil, apRight~isNil then
      return sign(left~number - right~number)

   if apLeft~isNil  then return -1
   if apRight~isNil then return 1
   return 0



/* ========================================================================= */
/*
 * This comparator sorts the TraceObjects by attributePool, thread and number.
*/
::class sortByAttributePool_Thread_Number subclass Comparator  public -- attributePool, thread, invocation and number
::method compare
   use arg left, right

   apLeft =left~attributePool
   apRight=right~attributePool

   if \apLeft~isNil, \apRight~isNil then
   do
     -- both attribute pool numbers are present
     val=sign(apLeft - apRight)
     if val<>0 then return val

     val=sign(left~thread - right~thread)
     if val<>0 then return val

      -- bot are equal, now sort by nr which is the original trace sequence
      return sign(left~number - right~number)
   end

      -- both are not given, hence a routine, order by number
   if apLeft~isNil, apRight~isNil then
      return sign(left~number - right~number)

   if apLeft~isNil  then return -1
   if apRight~isNil then return 1
   return 0


/* ========================================================================= */
/*
 * This comparator sorts the TraceObjects by attributePool, invocation and number.
*/
::class sortByAttributePool_Invocation_Number subclass Comparator  public -- attributePool, thread, invocation and number
::method compare
   use arg left, right

   apLeft =left~attributePool
   apRight=right~attributePool

   if \apLeft~isNil, \apRight~isNil then
   do
     -- both attribute pool numbers are present
     val=sign(apLeft - apRight)
     if val<>0 then return val

     val=sign(left~invocation - right~invocation)
     if val<>0 then return val

      -- bot are equal, now sort by nr which is the original trace sequence
      return sign(left~number - right~number)
   end

      -- both are not given, hence a routine, order by number
   if apLeft~isNil, apRight~isNil then
      return sign(left~number - right~number)

   if apLeft~isNil  then return -1
   if apRight~isNil then return 1
   return 0


/* ========================================================================= */
/*
 * This comparator is meant for easying the routine annotateRuntimeState, it
 * sorts the TraceObjects by attributePool, thread, invocation and number.
*/
::class sortByAttributePool_Thread_Invocation_Number subclass Comparator  public -- attributePool, thread, invocation and number
::method compare
   use arg left, right

   apLeft =left~attributePool
   apRight=right~attributePool

   if \apLeft~isNil, \apRight~isNil then
   do
     -- both attribute pool numbers are present
     val=sign(apLeft - apRight)
     if val<>0 then return val

     val=sign(left~thread - right~thread)
     if val<>0 then return val

     val=sign(left~invocation - right~invocation)
     if val<>0 then return val

      -- bot are equal, now sort by nr which is the original trace sequence
      return sign(left~number - right~number)
   end

      -- both are not given, hence a routine, order by number
   if apLeft~isNil, apRight~isNil then
      return sign(left~number - right~number)

   if apLeft~isNil  then return -1
   if apRight~isNil then return 1
   return 0


/* ======================================================================== */

/** This routine creates a hexadecimal value from the identityHash number returned by .Object's
    identityHash method taking the bitness of the ooRexx interpreter into account.
    If running on a 64-bit interpreter the hexadeciimal value will be 16 characters
    long, if running on a 32-bit interpreter it will be 8 characters long.

    @param argVal the identityHash number returned by .Object's identityHash method
    @param deliString on 64-bit systems: optional delimiter string for grouping eight hex digit
                characters, defaults to underscore (_)
    @return hexadecimal value
    @since  2022-09-29 in BSF.CLS
    @author Rony G. Flatscher
*/
::routine id2x public       -- "pointer" to hexadecimal string: convert identityHash value to hexadecimal string
  use strict arg argVal, deliString=("_")

  iDigits=.rexxinfo~internalDigits  -- get number of internal digits
  numeric digits iDigits
  val=argVal~d2x(iDigits)  -- convert to a hexadecimal string
  len=(iDigits=9)~?(8,16)  -- determine length of hexadecimal value
  hexval = val~right(len)  -- extract the hex digits representing 32 or 64 bit value
  if iDigits=18, deliString<>"" then   -- insert delimiter into hexadecimal string
     hexVal=hexVal~insert(deliString,8)
  return hexVal


/* ======================================================================== */

  /** Make sure we use the object name based on the class name.
      @param obj the object for which a canonicaly object name gets created
      @return the canonical object name
      @since  2022-09-29 in BSF.CLS
  */
 ::routine canonicalObjectName
   use arg obj
   if obj~isNil       then return .nil~string
   if obj~isA(.class) then return "The" obj~id "class"
   clzName=obj~class~id     -- get object's class name^
   return article(clzName) clzName
 article:   -- indeterminate article (starts with a vowel -> "an", else "a")
   if pos(clzName[1], "aAoOuU")>0 then return "an"
   return "a"


/* ======================================================================== */

   /** Create and return a string representation of the supplied object.
       @param target (object)
       @return the target's string representation
       @since  2022-09-29 in BSF.CLS
   */
 ::routine targetAsString
    use arg target
    return id2x(target~identityHash) "("canonicalObjectName(target)")"


/* ========================================================================= */
::routine getPackageFromObject
   use strict arg obj
   if obj~isNil then return ".nil"

   select
       when obj~isA(.package) then return obj      -- already a package
       when obj~isA(.class)   then return obj~package -- a class object, get its package
       otherwise                   return obj~class~package   -- an object, get its class' package
   end


/* ======================================================================== */

   /** Create and return the package name the object's class is defined in.
       @param target (object)
       @return the target's string representation
       @since  2022-09-29 in BSF.CLS
   */
 ::routine getPackageName
    use arg obj
    if obj~isNil then return ".nil" -- a scope can be .nil
    pkg = getPackageFromObject(obj)

    if pkg~isNil then return ".nil" -- no package object available

    -- can be a fully qualified path, REXX, INSTORE, or a name defined dynamically for a package
    return editPath(pkg~name)


--
/* ======================================================================== */
::routine editPath public
-- .error~charout(".")
-- TODO: test thoroughly
   parse arg name, kind    -- if kind was supplied (no matter what value)

   if name~verify("/\","Match")=0 then --- if no path delimiter return unchanged
      return name

   sep=.file~separator
   if kind="" then
   do
      return extract(name)
   end
   else  -- if kind argument was supplied (no matter what value)
   do    -- remove part from currDir in name that is common to shorten full path
      currDir=directory() -- get current directory
      pos=currDir~compare(name)    -- if the same returns 0, else first position that differs
      if pos>0 then
      do
          if pos>length(currDir) then
          do
               -- skip delimiter
             return name~substr(pos+(name[pos]=sep))  -- return part that is unique
          end
          else
             return "..." || name~substr(pos) -- return part that is unique
      end
   end
   return name


   -- if a fully qualified path, use filename and last directory, prepend with three dots to indicate it
   -- can be also REXX, INSTORE, and an arbitrary name defined when creating package dynamically
extract: procedure
   lpos1=name~lastPos(sep)
  -- say
  -- say .line": sep="pp(sep) "lpos1="pp(lpos1) "name="pp(name)
   if lpos1<=1 then return name
   lpos2=name~lastPos(sep,lpos1-1)
  -- say .line": sep="pp(sep) "lpos2="pp(lpos2) "name="pp(name)
   if lpos2<=1 then return name
   lpos3=name~lastPos(sep,lpos2-1)
  -- say .line": sep="pp(sep) "lpos3="pp(lpos3) "name="pp(name)
   if lpos3=0 then return name

     -- include directory the program resides in
  -- say .line": sep="pp(sep) "| returning" pp("..." || sep || name~substr(lpos2+1))
   return "..." || sep || name~substr(lpos2+1)





/* ======================================================================== */

   /** Scope is the class object whose methods get used, return its class name.
       Note: a class object's class methods have the scope of that class object itself.

       @param target (object)
       @return the target's string representation
       @since  2022-09-29 in BSF.CLS
   */
::routine getScopeName
  use arg scope
  if scope~isNil then return ".nil" -- a scope can be .nil
  return scope~id   -- return class' name


/* ======================================================================== */

  /** Process all traceObjects supplied in the orderable collection to use
      the <code>STACKFRAME<code> entry to add its information to the traceObject, namely
      <code>PACKAGE<code>, <code>NAME<code>, <code>LINENR<code>, <code>TYPE<code>, and
      if a StackFrame for a method then <code>TARGET<code>, <code>TARGETID<code>,
      <code>TARGETPACKAGE<code>, <code>SCOPE<code> and <code>SCOPEPACKAGE<code>.
      This way it becomes possible to get at that information, if reconstructing a
      traceObject collection from an external file.

      <p>If traceObject does not contain the entry <em>TYPE</em> then assume unprocessed,
      raw traceObject stack. Process all <em>stackFrame</entries> and add appropriate entries
      to traceObject.

      @param coll an orderable collection containing the logged traceObjects to process in place
      @return .true if processing took place, .false else (log was already processed at some other time)
  */
::routine processTraceObjectLog
  use strict arg coll
  .Validate~classType("OrderableCollection", coll, .OrderedCollection)
  if coll~items=0 then return .false
  .Validate~classType("TraceObject", coll~firstItem, .TraceObject)

  if coll[1]~hasEntry("LINENR") then
     return .false   -- assume already processed!

  -- this only works if directly from TraceObject's collector (without any processing applied)
  do counter c1 traceObj over coll
      stackFr=traceObj["STACKFRAME"]  -- fetch stackFrame
      if stackFr~isNil then iterate   -- no STACKFRAME, TraceObject not created by ooRexx

      traceObj["LINENR"] = stackFr~line   -- LINENR is an entry added by this tool
      receiver=traceObj["RECEIVER"]   -- new (June 2024)
      if \receiver~isNil then
      do
         traceObj["RECEIVERID"]  =id2x(receiver~identityHash)
         traceObj["RECEIVERCANONICALNAME"]=canonicalObjectName(receiver)
         traceObj["RECEIVER"]    =receiver~string
      end

      call process stackFr                -- add string version entries

      stackFr=traceObj["CALLERSTACKFRAME"]   -- fetch callerStackFrame, if available
      if \stackFr~isNil then              -- add string version entries
         call process stackFr
  end
  return .true

   -- proccess stack frame by adding string representations for some entries to the stringTable
process: procedure
  use strict arg stackFr
signal on syntax
  exec=stackFr~executable
  if stackFr~type="METHOD" then    -- object and method related information
  do
      target=stackFr~target
      if \target~isNil then
      do
         -- string representation, e.g. "a Test" (if instance of type) "The Test class" (if a class object)
         stackFr["TARGETCANONICALNAME"]=canonicalObjectName(target)
         stackFr["TARGETID"]       =id2x(target~identityHash)
         tgtPkg = getPackageFromObject(target)
         stackFr["TARGETPACKAGE"]  =getPackageName(tgtPkg)
         stackFr["TARGETPACKAGEID"]=id2x(tgtPkg~identityHash)
         stackFr["TARGET"]         =trimIfNecessary(target~string, 30) -- e.g. a MutableBuffer might return a huge string
      end

      scope =exec~scope
      if \scope~isNil then
      do
         stackFr["SCOPEPACKAGE"]    =getPackageName(scope)
         stackFr["SCOPE"]           =scope~id
         stackFr["SCOPEID"]         =id2x(scope~identityHash)
      end
  end

   -- it may be the case that "artifical" TraceObjects get created which already
   -- determine the desired name and add it under "PACKAGE" to the stackframe
   -- (tracetool.rex does this to mark the beginning and ending of the tracelog creation)
  if \stackFr~hasEntry("PACKAGE") then -- if not created by tracetool.rex use the exec's name
     stackFr["PACKAGE"]=getPackageName(exec~package) -- not yet assigned, get edited package name

  stackFr["EXECUTABLEID"]     =id2x(exec~identityHash)
  stackFr["EXECUTABLEPACKAGE"]=exec~package~name

  return

syntax:
  co=condition('o')
   call showCo .line, co
/* --
say .line":" "in SYNTAX:" "| type  ="pp(stackFr~type)
do counter c idx over stackFr~allindexes~sort
   say c~right(2)": stackFr("idx")="pp(stackFr[idx])
end
say "---"
-- */
   -- call "rgf_util2.rex"; say ppCondition2(co)
say "---"

  raise propagate


/* ========================================================================= */
/** Binary search routine: given an invocation number find index of first or last TraceObject of that invocation number
* @param arr sorted array of traceObjects (ordered by thread, invocation, number)
* @return index of first method related TraceObject or <ocde>-1</code> if none found
*/
-- TODO: adapt search to different ordering: thread, invocation, number
--       MAYBE: just sorting by lineNr as callerStackFrame has a LINE entry from StackFrame (could be .nil if e.g. compiled)
--              HOWEVER: beware! a line '4' could be present for different packages!
::routine findInvocationTraceObject  -- assumes order by attributepool, methods at the end, returns -1 if none
  use strict arg arr, thread, invocation=.nil, bFirst=.false   -- position on last TraceObject by default

  if arr~lastItem~stackFrame~type<>"METHOD" then  -- no method related TraceObject available, indicate with -1
     return -1

  left = 1                             -- first index
  right = arr~items                    -- last index
  do while left <= right
      m = (left + right) % 2           -- index that halves the sorted array
      if arr[m]~stackFrame~type<>"METHOD" then    -- not a method, search in right remaining half
         left = m + 1
      else                             -- a method TraceObject found
      do
          if arr[max(1,m-1)]~stackFrame~type="METHOD" then -- if next smaller a method, then search left remaining half
             right = m - 1
          else                         -- nope, we are at the first method TraceObject, return index
             return m
      end
  end
  return -1    -- not found, indicate with -1


/* ======================================================================== */

::routine trimIfNecessary
  use strict arg str, maxLength=30
  if str~length>maxLength then
     return str~left(maxLength)"..."   -- trim and add ellipsis to indicate more data there
  return str


/* ======================================================================== */

-- TODO: to be removed after debugging
::routine pp            -- enclose string value in square brackets
  return "["arg(1)"]"


/* ========================================================================= */
-- TODO: to be removed after debugging
::routine ppTraceObj
 use arg traceObj
 if traceObj~isNil then return .nil~string

 str="N"nz(traceObj["NUMBER"])~right(4)":" 'L'nz(traceObj["LINENR"])~left(3) "R"nz(traceObj["INTERPRETER"])~left(2) -
     "T"nz(traceObj["THREAD"])~left(3) "I"nz(traceObj["INVOCATION"])~left(5)-
     pp(nz(traceObj["NAME"]) "")~left(20,".") "T: "nz(traceObj["TYPE"])~left(1)

 if traceObj["TYPE"]="METHOD" then
 do
     str=str "A"nz(traceObj["ATTRIBUTEPOOL"])~left(3)
     str=str "S["nz(traceObj["SCOPE"])"]"
     str=str "LC"nz(traceObj["SCOPELOCKCOUNT"])~left(2)
     str=str "L"nz(traceObj["HASSCOPELOCK"])
     str=str "G="nz(traceObj["ISGUARDED"])
     str=str "CGS="nz(traceObj["CURRENTGUARDSTATE"])
     str=str "W="nz(traceObj["ISWAITING"])
     str=str "B="nz(traceObj["ISBLOCKED"])
 end
 str=str "TL["nz(traceObj["TRACELINE"])"]"
 return str

nz: procedure
   use arg val
   if val~isNil then return '?'
   return val


/* ======================================================================== */

/* Escape non-printable chars in Rexx-style, adjusted from rgf_util2.rex.
   Assumes 8-bit ASCII-based codepage, should not be used if e.g. UTF-8.
*/
::routine escape2 public   -- rgf, 20091214
  parse arg a1

  -- if .encoding.utf=.true then return enquote2(a1)

  res=""
  do while a1\==""
     pos1=verify(a1, .non.printable.ascii, "M")
     if pos1>0 then
     do
        pos2=verify(a1, .non.printable.ascii, "N" , pos1)

        if pos2=0 then
           pos2=length(a1)+1

        if pos1=1 then
        do
           parse var a1 char +(pos2-pos1) a1
           bef=""
        end
        else
           parse var a1 bef +(pos1-1) char +(pos2-pos1) a1

        if res=="" then
        do
           if bef \=="" then res=enquote2(bef) '|| '
        end
        else
        do
           res=res '||' enquote2(bef) '|| '
        end

        res=res || '"'char~c2x'"x'
     end
     else
     do
        if res<>""  then
           res=res '||' enquote2(a1)
        else
           res=a1

        a1=""
     end
  end
  return res


/* ======================================================================== */

/* Enquote string, escape quote/apostrophe. Optionally supply character(s) to serve as
   quote/apostrophe. Adjusted from rgf_util2.rex
*/
::routine enquote2 public  -- rgf, 20091214
  use arg string, quote='"'

  if string~isA(.string) then
     return quote || string~changestr(quote, quote~copies(2)) || quote

  return quote || string~makeString~changestr(quote, quote~copies(2)) || quote



/* ======================================================================== */
/* ======================================================================== */
-- adding/querying/removing tracetool.rex ::options directives
/* ======================================================================== */
/** Queries, adds or deletes "::OPTIONS TRACE x" statements at the end of
*   a program. The statements gets a line comment "-- added by tracetool.rex"
*   appended which serves as a needle for querying or deleting.
*
*   @param option one of 'Query', 'Add', 'Delete'
*   @param traceType only present, if 'Add' option, one of "All", "Result",
*                    "Intermediates", "Labels", "Normal"
*   @param filePattern optional (default: "*.rex *.cls *.frm *.rxj *.rxo") enclosed
*                    in double quotes, used for SysFileTree(), can be a single file path,
*   @param recursive? optional (default: .false), if .true, then searching subdirectories as well
*
*/
::routine manageOptionsDirectives public
  use arg switch="Query"

  parse upper arg option +1
  if pos(option, "AQD")=0 then
     raise syntax 40.900 array ('option argument must be one of: "A" (add), "Q" (query), or "D" (delete), received:' switch)

     -- defaults
  traceType=.nil
  defaultFilepattern="*.rex *.cls *.frm *.rxj *.rxo"

  select case option
      when "A" then  -- add ::options trace
               do
                  -- fetch arguments appropriately
                  use strict arg _, argTraceType="R", filePattern=(defaultFilepattern), recursive?
                  traceType=argTraceType~upper~left(1)
                  if pos(traceType, "AILNR")=0 then
                     raise syntax 40.900 array ('traceType argument must be one of "A" (all), "I" (intermediates), "L" (labels), "N" (normal), or or "R" (remove), received:' argTraceType)
               end
      when "Q", "D" then   -- just fetch arguments appropriately
                   use strict arg _, filePattern=(defaultFilepattern), recursive?=.false
  end
  .Validate~logical("recursive?", recursive?)

  if pos(filePattern~left(1), "'""")>0 then  -- need to remove quotes?
  do
      quote=filePattern~left(1)
      parse var filePattern (quote) filePattern (quote)
  end

  .error~say("option" pp(option)": processing" pp(filepattern) recursive?~?("recursively","") "...")

  timeStamp=.dateTime~new
  do filespec over filePattern~makeArray(" ")
     -- .error~say("option" pp(option)": processing" pp(filespec) recursive?~?("recursively","") "...")
     sftOptions="FO" || recursive?~?("S","")
     call sysFileTree filespec, "files.", sftOptions
     filen=files.0~length
     do fi=1 to files.0
        call processFile files.fi
     end
  end
  return

processFile: procedure expose option argTraceType filePattern recursive? timeStamp
  parse arg file

  str=.stream~new(file) -- read file into an array
  arr=str~arrayIn
  str~close

  select case option
      when 'A' then  -- add a tracetool.rex ::options trace entry to the end
               do
                  arr~append("::OPTIONS TRACE" argTraceType .trace.needle pp(timeStamp))
                 .error~say("1" file)
               end
      when 'Q' then  -- query whether a tracetool.rex ::options trace entry is present
               do
                 present?=arr~lastItem~pos(.trace.needle)>0
                 .error~say(present? file)
                 return
               end
      when 'D' then  -- remove all tracetool.rex ::options trace entries from the end
               do
                  removed?=.false
                  do i=arr~items to 1 by -1
                     if arr[i]~pos(.trace.needle)>0 then
                        removed?=(removed? | arr~remove(i)<>.nil)
                     else
                        leave
                  end
                  .error~say(removed? file)
                  if \removed? then return   -- no need to change file
               end
  end

  -- option 'A', 'R': replace edited file
  str=.stream~new(file)~~open("write replace")
  str~arrayout(arr)
  str~close
  return



/* ======================================================================== */
/* ======================================================================== */
-- profiling
/* ======================================================================== */

/* ======================================================================== */
::routine dumpAllInvocations
  use strict arg profiler
.error~say
.error~say( .context~name":" )
tab="09"x
  len=profiler~allInvocations~items~length
  len2=len+2
  sum=.timespan~fromSeconds(0) -- new: sollte dasselbe machen, geht aber  nicht! :(
  do counter c invocationObj over profiler~allInvocations~allitems~sort -- allindexes~sort
     idx=invocationObj~invocationKey
     dur  =invocationObj~duration
     enter=invocationObj~enter
     exit =invocationObj~exit
     if exit~isNil then
        .error~say( tab "#" c~right(len)":" "id="pp(idx~right(len2)) pp(dur) "enter:" pp(enter~number~right(len)":" enter~timeStamp~longTime) "exit:" pp(exit))
     else
        .error~say( tab "#" c~right(len)":" "id="pp(idx~right(len2)) pp(dur) "enter:" pp(enter~number~right(len)":" enter~timeStamp~longTime) "exit:" pp(exit~number~right(len)":" exit~timeStamp~longTime) "| exit-enter:" (exit~timeStamp - enter~timeStamp) )
     .error~say( tab~copies(5) "execPK="pp(invocationObj~runBy)", creatorPK="pp(invocationObj~createdBy) )
     .error~say( tab~copies(5) invocationObj)
     .error~say

     if enter~invocation>0 then sum+=dur -- ignore tracetool.rex entry
  end
  .error~say
  .error~say( tab "sum:" pp(sum) )
  .error~say

/* ======================================================================== */
-- TODO: remove these temporary routines
::routine dumpAllInvocations2
  use strict arg profiler
.error~say
  .error~say( "L#" .line~right(4)"-".context~name":" )
tab="09"x
  len=profiler~allInvocations~items~length
  len2=len+2
  sum=.timespan~fromSeconds(0) -- new: sollte dasselbe machen, geht aber  nicht! :(

  do counter c invocationObj over profiler~allInvocations~allitems~sort -- allindexes~sort
     idx  =invocationObj~invocationKey
     dur  =invocationObj~duration
     enter=invocationObj~enter
     exit =invocationObj~exit

     if enter~invocation>2 then sum+=dur -- ignore tracetool.rex entries

     .error~say( tab "#" c~right(len)":" "key="pp(idx~right(len2)) pp(dur) "| enter:" '#' pp(enter~number~right(len)) pp(enter~timeStamp) adjLeft(pp(enter),70) )
     if exit~isNil then
        .error~say( tab~copies(5)                                           "   | exit: " '  ' '-'~copies(len) '' pp(exit) )
     else
        .error~say( tab~copies(5)                                           "   | exit: " '#' pp(exit~number~right(len)) pp(exit ~timeStamp) adjLeft(pp(exit ),70) )
  end
  .error~say
  .error~say( tab "sum:" pp(sum) )
  .error~say

/* ======================================================================== */
::routine adjLeft
  use strict arg val,left=.nil,filler=" "
  if left==.nil then return val
  maxLeft=left-3     -- maximum characters to show, followed by ellipsis (...)
  if val~length<maxLeft then return val
  return val~left(maxLeft,filler)"..."

/* ======================================================================== */
::routine adjRight
  use strict arg val,right=.nil,filler=" "
  if right==.nil then return val
  if val~length>right then return val
  return val~right(right,filler)

/* ======================================================================== */
::routine dumpAllExecutables
  use strict arg profiler
  .error~say
  .error~say( "L#" .line~right(4)"-".context~name":" )
  tab="09"x
  len=profiler~allExecutables~items~length
  do counter c exec over profiler~allExecutables~allItems~sort
     execPK=exec~executablePK

     allRuns=profiler~execRunsInvocation~allAt(execPK)
     if allRuns\==.nil then
        allRuns=allRuns~makeArray~~sortWith(.SortByInvocationKey~new)~toString(,',')

     .error~say( tab "#" c~right(len)":" pp(execPK~left(22))"->"pp(exec) "| exec used for:" pp(nz(allRuns,'n/a')) )
  end
  .error~say
  return


/* ======================================================================== */
::routine nz
  use arg value, valIfNull="?"
  if value==isNil then return varIfNull
  return value


/* ======================================================================== */
-- TODO: remove these temporary routines
::routine dumpExecRunsInvocation  -- ID exec got created for
  use strict arg profiler
  .error~say
  .error~say( "L#" .line~right(4)"-".context~name":" )
  tab="09"x
  len=profiler~allExecutables~items~length
  do counter c exec over profiler~allExecutables~allItems~sort
     execPK=exec~executablePK
     allInvocations=profiler~execCreatesInvocation~allAt(execPK)
     if allInvocations==.nil then iterate -- skip executables that do not invoke anything themselves
     allInvocations=allInvocations~makeArray~sortWith(.SortByInvocationKey~new)~toString(,',')

     .error~say( tab "#" c~right(len)":" pp(execPK~left(22))"->"pp(exec) "| exec invokes:" pp(nz(allInvocations,0)) )
  end
  .error~say


/* ======================================================================== */
-- TODO: remove these temporary routines
::routine dumpExecCreatesInvocation     -- IDs invoked from exec
  use strict arg profiler
  .error~say
  .error~say( "L#" .line~right(4)"-".context~name":" )
  tab="09"x
  len=profiler~execCreatesInvocation~items~length
  i=1
  do execPK over profiler~allExecutables~allIndexes~sort
     allInvoked=profiler~execCreatesInvocation~allAt(execPK)      -- skip execs that do not invoke
     if allInvoked\==.nil then
     do
        if allInvoked~items=0 then iterate      -- skip execs that do not invoke
        allInvoked=allInvoked~makeArray~sortWith(.SortByInvocationKey~new)~toString(,',')
     end

     .error~say( tab "#" i~right(len)":" pp(execPK~left(22)) pp(profiler~allExecutables[execPK]) "invoking:" pp(nz(allInvoked,0)) )
     i+=1
  end
  .error~say


/* ======================================================================== */
-- TODO: remove these temporary routines
::routine dumpExecDurations
  use strict arg profiler
  .error~say
  .error~say( "L#" .line~right(4)"-".context~name":" )
  tab="09"x

  len=profiler~allExecutables~items~length
  say "SHOW exec~duration, ordered ascendingly:"
  say

  do counter i exec over profiler~allExecutables~allItems~sortWith(.sortExecsByDuration~new)
     -- .error~say( tab "#" i~right(len)":" pp(exec~duration) pp(exec))
     .error~say( tab "#" i~right(len)":" pp(exec~exec2string1(profiler)))
  end
  .error~say

  say "SHOW exec~duration, ordered descendingly:"
  say
  do counter i exec over profiler~allExecutables~allItems~sortWith(.sortExecsByDuration~new(.false))
     -- .error~say( tab "#" i~right(len)":" pp(exec~duration) pp(exec))
     .error~say( tab "#" i~right(len)":" pp(exec~exec2string1(profiler)))
  end
  .error~say


/* ======================================================================== */
-- TODO: remove these temporary routines
::routine dumpAllProfilerInfos
  use strict arg profiler
  .error~say
  .error~say( "L#" .line~right(4)"-".context~name":" )

  .error~say
  .error~say("---> "~copies(20))
  .error~say(">>> debug allInvocations")
  .error~say
  call dumpAllInvocations profiler
  .error~say('<'"---"~copies(30))

  .error~say
  .error~say("---> "~copies(20))
  .error~say(">>> debug allInvocations2")
  .error~say
  call dumpAllInvocations2 profiler
  .error~say('<'"---"~copies(30))

  .error~say
  .error~say("---> "~copies(20))
  .error~say(">>> debug allExecutables")
  .error~say
  call dumpAllExecutables profiler
  .error~say('<'"---"~copies(30))

  .error~say
  .error~say("---> "~copies(20))
  .error~say(">>> debug execRunsInvocation")
  .error~say
  call dumpExecRunsInvocation profiler
  .error~say("<- "~copies(30))

  .error~say
  .error~say("---> "~copies(20))
  .error~say(">>> debug execCreatesInvocation")
  .error~say
  call dumpExecCreatesInvocation profiler
  .error~say("<- "~copies(30))

  .error~say
  .error~say("---> "~copies(20))
  .error~say(">>> debug execDurations (test sorting by durations ascendingly and descendingly)")
  .error~say
  call dumpExecDurations profiler
  .error~say("<- "~copies(30))
  .error~say("===="~copies(30))
  .error~say



/* ======================================================================== */
/** Calculate % with TimeSpan objects.
*
* @param total total TimeSpan
* @param fraction Timespan
* @return percent value of fraction of total, formatted to three
*         integer and two decimal places
*/
::routine calcPercent
     -- calculate and return percentage
  use strict arg total, fraction
  totMS =total~microSeconds
  if totMS=0 then return format(0,3,2)
  currMS=fraction~microSeconds
  res=100*currMS/totMS
  if res>999 then -- integer part larger than three digits
  do
     parse var res int '.' dec
     if dec<>"" then -- extract decimal portion, round it up to two decimal places
     do
        dec=(1000+dec//1000+5)~substr(2,2)  -- roundup
     end
     else   -- no decimal places, use 00
        dec="00"
     return int'.'dec~left(2)
  end
  return format(res,3,2)
  -- return format(100*currMS/totMS,3,2)


/* ======================================================================== */
/** Control routine to carry out all steps needed for profiling.
*
*   @param traceLog array of TraceObjects to analyze
*   @return .true if successful, .false else
*/
::routine profile public
  use strict arg traceLog, depth=7, reportType=" ", createSql?=.false, sqlSwitch=.nil, dbName="", sqlFileName=""

  .validate~nonNegativeWholeNumber("depth",depth)
  .context~package~local~bDebug=.false -- .true

  profiler=.profiler~new(traceLog)

-- bDebug=.true
if .bDebug=.true | bDebug=.true then
do
  say .line":" "/**\ "~copies(20)
  call dumpAllProfilerInfos profiler   -- for debugging
end

  allItems=profiler~allExecutables~allItems  -- get all executables
  allExecsSortedByDuration    = allItems~sortWith(.sortExecsByDuration~new(.false))
  allExecsSortedByAvgDuration = allItems~sortWith(.sortExecsByAvgDuration~new(.false))

  profiler~dumpProfile_duration(allExecsSortedByDuration)

  if pos(reportType, " S")>0 then
     profiler~dumpProfile_callTree_global(allExecsSortedByDuration,depth,.true)
  if pos(reportType, " A")>0 then
     profiler~dumpProfile_callTree_global(allExecsSortedByAvgDuration,depth,.false)

  if pos(reportType, " S")>0 then
    profiler~dumpProfile_callTree_group(allExecsSortedByDuration,depth,.true)
  if pos(reportType, " A")>0 then
    profiler~dumpProfile_callTree_group(allExecsSortedByAvgDuration,depth,.false)

  if pos(reportType, " S")>0 then
     profiler~dumpProfile_callTree_global_group_relative_caller(allExecsSortedByDuration,depth,.true)
  if pos(reportType, " A")>0 then
     profiler~dumpProfile_callTree_global_group_relative_caller(allExecsSortedByAvgDuration,depth,.false)

  if createSql?, sqlFileName<>"" then
     profiler~createSql(dbName,sqlFileName,sqlSwitch)


/* ======================================================================== */
/* Comparator for sorting by duration ascendingly (default) or descendingly
* (supply .false as argument to the new message).
*/
::class sortExecsByDuration subclass comparator

::method init
  use strict arg ascending?=.true

  .Validate~logical("sortAscendingly",ascending?)

  if ascending? then          -- use predefined ascending comparator
     self~setMethod("compare", self~instanceMethod("compareAscendingly"))
  else
     self~setMethod("compare", self~instanceMethod("compareDescendingly"))

::method compareAscendingly   -- code for ascending sort
   use arg left, right
   if left~duration<right~duration then return -1 -- left smaller then right
   if left~duration>right~duration then return  1 -- left bigger  then right
      -- duration equal, sort by executable's name et.al.
   return left~executableSortField~caselessCompareTo(right~executableSortField)
   return 0                                       -- equal

::method compareDescendingly  -- code for descending sort (default)
   use arg left, right
   if left~duration<right~duration then return  1 -- invert: left smaller then right
   if left~duration>right~duration then return -1 -- invert: left bigger  then right
      -- duration equal, sort by executable's name et.al.
   return left~executableSortField~caselessCompareTo(right~executableSortField)
   return 0                                       -- equal


/* ======================================================================== */
/* Comparator for sorting by duration ascendingly (default) or descendingly
* (supply .false as argument to the new message).
*/
::class sortExecsByAvgDuration subclass comparator

::method init
  use strict arg ascending?=.true

  .Validate~logical("sortAscendingly",ascending?)

  if ascending? then          -- use predefined ascending comparator
     self~setMethod("compare", self~instanceMethod("compareAscendingly"))
  else
     self~setMethod("compare", self~instanceMethod("compareDescendingly"))

::method compareAscendingly   -- code for ascending sort
   use arg left, right
   if left~avgDuration<right~avgDuration then return -1 -- left smaller then right
   if left~avgDuration>right~avgDuration then return  1 -- left bigger  then right
      -- duration equal, sort by executable's name et.al.
   return left~executableSortField~caselessCompareTo(right~executableSortField)
   return 0                                       -- equal

::method compareDescendingly  -- code for descending sort (default)
   use arg left, right
   if left~avgDuration<right~avgDuration then return  1 -- invert: left smaller then right
   if left~avgDuration>right~avgDuration then return -1 -- invert: left bigger  then right
      -- duration equal, sort by executable's name et.al.
   return left~executableSortField~caselessCompareTo(right~executableSortField)
   return 0                                       -- equal


/* ======================================================================== */
/* Comparator for sorting by number (TraceObject's sequence number)
 * ascendingly (default) or descendingly (supply .false as argument
 * to the new message).
*/
::class sortExecsByNumber subclass comparator

::method init
  use strict arg ascending?=.true

  .Validate~logical("sortAscendingly",ascending?)

  if ascending? then          -- use predefined ascending comparator
     self~setMethod("compare", self~instanceMethod("compareAscendingly"))
  else
     self~setMethod("compare", self~instanceMethod("compareDescendingly"))

::method compareAscendingly   -- code for ascending sort
   use arg left, right
   return sign(left~number - right~number)

::method compareDescendingly  -- code for descending sort (default)
   use arg left, right
   return -sign(left~number - right~number)



/* ======================================================================== */
/* Comparator for sorting by invocationKey ascendingly (default) or descendingly
* (supply .false as argument to the new message).
*/
-- invocationKey: "invocationId_1" or "invocationId_2" (in the REPLY case)
::class sortByInvocationKey subclass comparator

::method init
  use strict arg ascending?=.true

  .Validate~logical("sortAscendingly",ascending?)

  if ascending? then          -- use predefined ascending comparator
     self~setMethod("compare", self~instanceMethod("compareAscendingly"))
  else
     self~setMethod("compare", self~instanceMethod("compareDescendingly"))

::method compareAscendingly   -- code for ascending sort
   use arg left, right
   parse var left   leftNum1 "_" leftNum2
   parse var right rightNum1 "_" rightNum2
   val=leftNum1-rightNum1
   if val=0 then
      val=leftNum2-rightNum2
   return sign(val)

::method compareDescendingly  -- code for ascending sort
   use arg left, right
   parse var left   leftNum1 "_" leftNum2
   parse var right rightNum1 "_" rightNum2
   val=leftNum1-rightNum1
   if val=0 then
      val=leftNum2-rightNum2
   return -sign(val)


/* ======================================================================== */
/** Profiler maintains collection objects for profiling.
*/

::class Profiler private

::attribute traceLog                -- array of TraceObjects
::attribute allExecutables          -- execPK       -> executable
::attribute allInvocations          -- invocationID -> invocation
::attribute execRunsInvocation      -- execPK       -> invocation.invocationId
::attribute execCreatesInvocation   -- execPK       -> invocation.invocationId
-- TODO: sumExecDurations not useful, get total time from invocation object
--       rather exclude the invocation objects that are run by an unknown exec
--       - sort by duration descendingly, then show durations and %
::attribute sumExecDurations        -- sum of executable durations
::attribute allExecThatRan


/* ------------------------------------------------------------------------ */
::method init
  expose tracelog allExecutables allInvocations execRunsInvocation execCreatesInvocation sumExecDuration allExecThatRan
  use strict arg traceLog

  allExecutables       =.stringTable~new     -- execPK       -> executable object
  allInvocations       =.stringTable~new     -- invocationID -> invocation object
  execRunsInvocation   =.relation~new  -- execPK       -> invocationID
  execCreatesInvocation=.relation~new        -- execPK       -> invocationID
  sumExecDuration      =.timeSpan~new(0,0)
  allExecThatRan       =.array~new           -- executables that ran one of the invocations

  self~processTraceObjects    -- process trace log
  self~calcExecDurations      -- sum up duration of executables


/* ------------------------------------------------------------------------ */
::method calcExecDurations
  expose traceLog allExecutables allInvocations execRunsInvocation execCreatesInvocation sumExecDuration allExecThatRan
  use strict arg

  if sumExecDuration<>.TimeSpan~new(0,0) then
      sumExecDuration=.TimeSpan~new(0,0)

   -- get those executables that were used to run any invocations (ignore any other,
   -- possibly the tracetool.rex entries in the tracelog or those that were used to
   -- run the program by tracetool.rex)
  allExecThatRan=allExecThatRan~empty~appendAll(.set~new~union(execRunsInvocation~allIndexes))
  execThatDidNotRun=.set~new~putAll(allExecutables~allIndexes~difference(allExecThatRan))

  tab="09"x
  -- do counter c execPK over setExecThatRunInvocation
  do counter c execPK over allExecutables
     exec=allExecutables[execPK]
     do invocId over execRunsInvocation~allAt(execPK)~sort  -- iterate over all invocations
        invocObj=allInvocations[invocId]
        exec~duration+=invocObj~duration
     end
     sumExecDuration+=exec~duration
     if exec~timesCalled>0 then
        exec~avgDuration=exec~duration/exec~timesCalled
  end


/* ------------------------------------------------------------------------ */
/** Process the trace log and store results in the attributes allExecutables,
*
*/
::method processTraceObjects private
  expose traceLog allExecutables allInvocations execRunsInvocation execCreatesInvocation

   -- sort traceLog
  traceLog~sortWith(.sortByInvocation_Number~new) -- "in"
  traceLogItems =traceLog~items
  traceLineEnter="       >I>"
  traceLineExit ="       <I<"

    -- define variables from caller to be exposed to procedure
  vars="self tracelog allExecutables allInvocations execRunsInvocation execCreatesInvocation" -
       "traceLog traceLogItems traceLineEnter traceLineExit"

  -- step 1: process tracelog
  call processTraceLog        -- start out
  return

  -------------------------------------------------------------------------------
  -- step 2: process TraceObjects: logData must be sorted by number;
  --         20250214: cater for REPLY which causes the entry and exit to appear twice
  processTraceLog: procedure expose (vars)     -- step 2
    startIdx=1
    lastIdx =traceLogItems
     -- if tracelog got created with tracetool.rex the first and last tracelog entry
     -- have the thread id and invocation id 0, the second and third entry reflect
     -- the creation of the routine object for the Rexx program that tracetool invokes
     -- on a separate thread
    tmpTraceObj=traceLog[1]
    startInvocationObj=.nil
        -- created by tracetool.rex?
    startTraceObj=.nil
    endTraceObj  =.nil

    startIdx=1   -- value may get changed in the following block
    if tmpTraceObj~invocation=0, tmpTraceObj~traceline~pos("(start collecting)")>0 then
    do
       startTraceObj=tmpTraceObj   -- tracetool.rex' entry
       endTraceObj  =traceLog[2]   -- tracetool.rex' entry

          -- create start invocation, will reflect total duration of trace logging
       startInvocationKey = startTraceObj~invocation"_1"
       startInvocationObj =.invocation~new(startInvocationKey, startTraceObj, endTraceObj)
       self~addInvocation(0, startInvocationObj)
       startIdx=3  -- skip processed trace objects
    end

      -- 20250214: use key (invocationId+" "+counter="1") to cater for double invocation for REPLY
    previousTraceObj     =.nil
    previousInvocationObj=.nil
    previousInvocationId =-1
    previousInvocationKey=.nil

    do i=startIdx to lastIdx  -- now process remaining traceObjects
       nextTraceObj    =traceLog[i]
       nextInvocationId=nextTraceObj~invocation

       if previousInvocationId<>nextInvocationId | previousInvocationKey==.nil then
          nextInvocationKey=nextInvocationId"_1"

       tmpInvocation=allInvocations[nextInvocationKey]

       -- REPLY case: there are two invocations with the same invocation number
      if tmpInvocation\==.nil, nextInvocationId=previousInvocationId, nextTraceObj~traceLine~startsWith(traceLineExit) then
      do
-- say .line":" "1) invocationId="pp(nextInvocationId) pp(nextTraceObj~traceLine) "- a REPLY in hand?" copies("*** ",10)
          if i<lastIdx then   -- not the last traceObject?
          do
             peekTraceObj=traceLog[i+1]
-- say .line":" "2) innvocationId="pp(previousInvocationId) "peekTraceObj~invocation="pp(peekTraceObj~invocation)
             if peekTraceObj~invocation=nextInvocationId then   -- same invocation, hence a reply
             do
-- say .line":" "3) invocationId="pp(nextInvocationId) pp(nextTraceObj~traceLine) "- a REPLY in hand!!" copies("<-- ",10)
                -- if we arrive here, we are in the second invocation part of a REPLY
                -- peekTraceObj~traceLine~startsWith(traceLineEnter)
                tmpInvocation~exit=nextTraceObj    -- set exit trace object
                nextInvocationKey=nextInvocationId"_2"
                newInvocationObj =.invocation~new(nextInvocationKey,peekTraceObj)
                self~addInvocation(nextInvocationKey, newInvocationObj)

                previousInvocationId =nextInvocationId
                previousInvocationKey=nextInvocationKey
                previousInvocationObj=newInvocationObj
                previousTraceObj     =peekTraceObj
                i+=1    -- we used the peekTraceObj, adjust counter
                iterate
             end
          end
      end


-- say .line":" "|-> nextInvocationKey="pp(nextInvocationKey) "prevInvocationKey="pp(previousInvocationKey)

/* --
if nextInvocationId=14 then
do
   say .line":" "id=14:" "i="pp(i) "nextInvocationKey="pp(nextInvocationKey) "//"nextTraceObj"\\"
   str=""
   if tmpInvocation=.nil then str=pp(tmpInvocation)
                         else str=pp(tmpInvocation) "exit:" pp(tmpInvocation~exit)
   say .line":" "id=14:" "i="pp(i) str
end

if tmpInvocation\==.nil, nextTraceObj~traceLine~startsWith("       <I<") then
   say .line":" "nextInvocationId="pp(nextInvocationId)": end of invocation trace line:" pp(nextTraceObj~traceLine)

         -- if invocation exists and has already an exit TraceObject, we are in a REPLY invocation
if nextInvocationId=14 then trace i
       if tmpInvocation\==.nil,tmpInvocation~exit\==.nil then  -- process REPLY's second invocation
do
          nextInvocationKey=nextInvocationId "2"
say .line":""newInvocationkey="pp(newInvocationKey) "/// \\\ "~copies(20)
end
trace n

if nextInvocationId=14 then
do
   say .line": id=14 -> tmpInvocation="pp(tmpInvocation) "*** "~copies(15)
   say .line": id=14    nextTraceObj ="pp(nextTraceObj ) "*** "~copies(15)
-- trace i
--   say .line": nextTraceObj        ->" ppTraceObj(nextTraceObj ) "*** "~copies(20)
   say .line": nextTraceObj            ="pp(nextTraceObj)
   say .line": ppTraceObj(nextTraceObj)="pp(ppTraceObj(nextTraceObj))
   say "---"
end
-- */

       -- if nextInvocationId<>previousInvocationId then -- new invocation?
       if nextInvocationKey<>previousInvocationKey then  -- new invocation?
       do
           -- first check whether we have to close a pending one
          if previousTraceObj \== .nil then
          do
              -- assign previousTraceObj
              if previousTraceObj~traceline~startsWith(traceLineExit) then
              do
                 previousInvocationObj~exit=previousTraceObj
              end
              else  -- either an INTERNALCALL or pending (unfinished) invocation ...
              do
                    -- if previousTraceObj is an INTERNALCALL, then use current traceObj instead
                 if previousTraceObj~stackFrame~type="INTERNALCALL" then
                 do
                    previousInvocationObj~exit=nextTraceObj
                 end
              end
          end

           -- now create new invocation related objects and adjust variables
          newInvocationObj =.invocation~new(nextInvocationKey,nextTraceObj)
          -- self~addInvocation(nextInvocationId, newInvocationObj)
          self~addInvocation(nextInvocationKey, newInvocationObj)

          previousInvocationId =nextInvocationId
          previousInvocationKey=nextInvocationKey
          previousInvocationObj=newInvocationObj
       end

       if i<>lastIdx then
          previousTraceObj     =nextTraceObj
    end

    -- last traceObject serves as exit object?
    if previousTraceObj\==.nil then
    do
       if previousTraceObj~number<>nextTraceObj~number then
       do
           -- assume last traceObject is the exit one
          previousInvocationObj~exit=nextTraceObj
       end
       else   -- we have the same traceObject as enter already, use tracelog[2] as exit
       do
           -- this may include the sysSleep time from tracetool.rex !
          if nextTraceObj~stackFrame~type="INTERNALCALL", endTraceObj\==.nil then
             previousInvocationObj~exit=endTraceObj
       end
    end


/* ------------------------------------------------------------------------ */
-- 20250214: use key instead of invocationId to cater for REPLY (has double invocations)
::method addInvocation
  expose tracelog allExecutables allInvocations execRunsInvocation execCreatesInvocation
  use strict arg invocationKey, newInvocationObj

  bNew=\allInvocations~hasEntry(invocationKey)
  enterTraceObj=newInvocationObj~enter

  sf=enterTraceObj~stackFrame
  tmpNumber=enterTraceObj~number -- get the sequence number to allow to sort by it
  tmpPK1=getExecPK(sf)   -- get the primary key we need

  if bNew then   -- not yet seen, remember
  do
     allInvocations~setEntry(invocationKey,newInvocationObj)
     execObj1=allExecutables[tmpPk1] -- try to fetch executable object

     if execObj1==.nil then  -- executable not yet created?
        execObj1=.Executable~new(self, sf, tmpPK1,tmpNumber)      -- create executable

     newInvocationObj~runBy=tmpPK1     -- assign executable that runs this invocation
     execObj1~timesCalled+=1      -- increase counter

      -- document that this new exec executes this new invocation (1:1 relationship)
     execRunsInvocation[tmpPK1]=invocationKey
     csf=enterTraceObj~callerStackFrame
     if csf\==.nil then    -- do we have a need to create the caller executable?
     do
        tmpPK2=getExecPK(csf)  -- get the primary key we need
        execObj2=allExecutables[tmpPK2]
        if execObj2==.nil then  -- executable not yet created
           execObj2=.Executable~new(self, csf,tmpPK2,-tmpNumber)   -- create executable

        newInvocationObj~createdBy=tmpPK2

         -- add this invocation to caller's exec as it invoked it (1:N relationship)
        execCreatesInvocation[tmpPK2]=invocationKey
        execObj2~setOfCalledExecs~put(execObj1) -- save called exec obj in caller exec
     end

/* -->
-- TODO: 20250209 type "exec" can never be .nil, means that the "important" part gets always executed
     else   -- an internal call (label got invoked), parent is executable that contains this label
     do
         contextExecId=enterTraceObj~stackFrame~executableId -- this should have been processed already
         if contextExecId\==.nil then     -- now we fill in
         do
            contextExec=allExecutables~entry(contextExecId)
-- TODO: "exec" nowhere defined in the entire routine, hence string value that can never be .nil
            if exec\==.nil then        -- if executable exists use it to fill in
            do
-- say .line":" "exec\==.nil, exec="pp(exec)
               contextPK=contextExec~executablePK     -- get executablePK of container
               execCreatesInvocation[contextPK]=invocationKey   -- register it in .execCreatesInvocation
               newInvocationObj~createdBy=contextPK   -- store in newInvocation
               contextExec~setOfCalledExecs~put(execObj1) -- save called exec obj in caller exec
            end
         end
     end
<-- */
  end


/* ------------------------------------------------------------------------ */
::method dumpProfile_duration
  expose allExecutables
  use strict arg allExecsSorted=.nil

  title=">>> ordered descendingly by duration of executables (% of total duration):"
  ruler="-"~copies(title~length)
  say title
  say ruler

  if allExecsSorted==.nil then  -- sort descendingly
    allExecsSorted = allExecutables~allItems~sortWith(.sortByDuration~new(.false))

  ignoreExecs =.set~new  -- set of executables to ignore (e.g. already processed)
  do i=1 to min(3,allExecsSorted~items)
     exec=allExecsSorted[i]
      -- ignore executables without calling executable, and TraceLogStart executable,
      -- both may be present if tracelog was created by tracetool.rex
     if exec~timesCalled=0 | exec~name~caselessStartsWith("TraceLogStart")  then
     do
        ignoreExecs~put(exec)
        iterate
     end
     leave     -- we start with this one
  end

  totalDuration=exec~duration -- save longest duration

  do i=i to allExecsSorted~items
     exec=allExecsSorted[i]
     if exec~timesCalled=0 then iterate   -- skip, executable not in tracelog

        -- skip, to be ignored or executable not in tracelog
     -- if ignoreExecs~hasindex(exec) | exec~timesCalled=0 then iterate
     say calcPercent(totalDuration,exec~duration)"%" exec~exec2string3
  end


/* ------------------------------------------------------------------------ */
-- use total duration for percent calculations, i.e. first invocation's duration
::method dumpProfile_callTree_global
  expose allExecutables
  use strict arg allExecsSorted=.nil, maxDepth=7, useAggregate?=.true

  say
  title=">>>" useAggregate?~?("aggregated","averaged") "duration call tree (% of global total duration):"
  ruler="-"~copies(title~length)
  say title
  say ruler

  durationComparator=.sortExecsByDuration~new(.false)   -- sort descendingly
  if allExecsSorted==.nil then
    allExecsSorted = allExecutables~allItems~sortWith(durationComparator)

  ignoreExecs =.set~new  -- set of executables to ignore (e.g. already processed)
  do i=1 to min(3,allExecsSorted~items)
     exec=allExecsSorted[i]
      -- ignore executables without calling executable, and TraceLogStart executable,
      -- both may be present if tracelog was created by tracetool.rex
     if exec~timesCalled=0 | exec~name~caselessStartsWith("TraceLogStart")  then
     do
        ignoreExecs~put(exec)
        iterate
     end
     leave     -- we start with this one
  end

  indent="    "   -- indent string
  if useAggregate? then
     call showProfileTree exec, exec~duration, 0, useAggregate?
  else
     call showProfileTree exec, exec~avgDuration, 0, useAggregate?

  return

showProfileTree: procedure expose maxDepth ignoreExecs durationComparator indent
  use strict arg tmpExec, totalDuration, level=0, useAggregate?=.true

  if maxDepth>0, level=maxDepth then
  do
     -- say indent~copies(level-1) "... cut ... (exceeding maxDepth="maxDepth")" tmpExec~exec2string2
     say indent~copies(level-1) || "*** cut *** (exceeding maxDepth="maxDepth")" tmpExec~exec2string3
     return
  end

  -- say indent~copies(level) calcPercent(totalDuration,tmpExec~duration)"%" tmpExec~exec2string2
  if useAggregate? then
     say indent~copies(level) || calcPercent(totalDuration,tmpExec~duration)"%" tmpExec~exec2string3
  else
     say indent~copies(level) || calcPercent(totalDuration,tmpExec~avgDuration)"%" tmpExec~exec2string3avg

  if ignoreExecs~hasIndex(tmpExec) then
  do
     if tmpExec~setOfCalledExecs~items>0 then
        say indent~copies(level) || "*** cut *** (substructure got already displayed)"
     else
        say indent~copies(level) || "*** hint *** (got already displayed)"
     return
  end

  ignoreExecs~put(tmpExec) -- do not show its children the next time
  if tmpExec~setOfCalledExecs~items=0 then return  -- no children, we are done for this one

   -- process children
  do calledExec over tmpExec~setOfCalledExecs~allIndexes~sortWith(durationComparator)
     -- call showProfileTree calledExec, tmpExec~duration, level+1
     call showProfileTree calledExec, totalDuration, level+1, useAggregate?
  end
  return


/* ------------------------------------------------------------------------ */
-- use group's total duration for percent calculations
::method dumpProfile_callTree_group
  expose allExecutables
  use strict arg allExecsSorted=.nil, maxDepth=7, useAggregate?=.true

  say
  title=">>>" useAggregate?~?("aggregated","averaged") "duration call tree (% of group's total duration):"
  ruler="-"~copies(title~length)
  say title
  say ruler

  durationComparator=.sortExecsByDuration~new(.false)   -- sort descendingly
  if allExecsSorted==.nil then
     allExecsSorted = allExecutables~allItems~sortWith(durationComparator)

  ignoreExecs =.set~new  -- set of executables to ignore (e.g. already processed)
  do i=1 to min(3,allExecsSorted~items)
     exec=allExecsSorted[i]
      -- ignore executables without calling executable, and TraceLogStart executable,
      -- both may be present if tracelog was created by tracetool.rex
     if exec~timesCalled=0 | exec~name~caselessStartsWith("TraceLogStart")  then
     do
        ignoreExecs~put(exec)
        iterate
     end
     leave     -- we start with this one
  end

  indent="    "   -- indent string
  if useAggregate? then
     call showProfileTree exec, exec~duration, 0, useAggregate?
  else
     call showProfileTree exec, exec~avgDuration, 0, useAggregate?

  return

showProfileTree: procedure expose maxDepth ignoreExecs durationComparator indent
  use strict arg tmpExec, totalDuration, level=0, useAggregate?=.true

  if maxDepth>0, level=maxDepth then
  do
     if useAggregate? then
        say indent~copies(level-1) || "*** cut *** (exceeding maxDepth="maxDepth")" tmpExec~exec2string3
     else
        say indent~copies(level-1) || "*** cut *** (exceeding maxDepth="maxDepth")" tmpExec~exec2string3avg
     return
  end

  if useAggregate? then
     say indent~copies(level) || calcPercent(totalDuration,tmpExec~duration)"%" tmpExec~exec2string3
  else
     say indent~copies(level) || calcPercent(totalDuration,tmpExec~avgDuration)"%" tmpExec~exec2string3avg

  if ignoreExecs~hasIndex(tmpExec) then
  do
     if tmpExec~setOfCalledExecs~items>0 then
        say indent~copies(level) || "*** cut *** (substructure got already displayed)"
     else
        say indent~copies(level) || "*** hint *** (already displayed)"
     return
  end

  ignoreExecs~put(tmpExec) -- do not show its children the next time

   -- calc total duration of children execs
  groupTotal=.TimeSpan~new(0,0)
  childExecs=tmpExec~setOfCalledExecs~allIndexes~sortWith(durationComparator)
  do calledExec over childExecs
     if useAggregate? then
        groupTotal+=calledExec~duration
     else
        groupTotal+=calledExec~avgDuration
  end

   -- process children
  do calledExec over childExecs
     call showProfileTree calledExec, groupTotal, level+1, useAggregate?
  end
  return


/* ------------------------------------------------------------------------ */
-- use total duration for percent calculations, i.e. first invocation's duration
::method dumpProfile_callTree_global_group_relative_caller
  expose allExecutables
  use strict arg allExecsSorted=.nil, maxDepth=7, useAggregate?=.true

  say
  title=">>>" useAggregate?~?("aggregated","averaged") "duration call tree (% of group's total duration relative to caller):"
  ruler="-"~copies(title~length)
  say title
  say ruler

  durationComparator=.sortExecsByDuration~new(.false)   -- sort descendingly
  if allExecsSorted~isNil then
     allExecsSorted = allExecutables~allItems~sortWith(durationComparator)

  ignoreExecs =.set~new  -- set of executables to ignore (e.g. already processed)
  do i=1 to min(3,allExecsSorted~items)
     exec=allExecsSorted[i]
      -- ignore executables without calling executable, and TraceLogStart executable,
      -- both may be present if tracelog was created by tracetool.rex
     if exec~timesCalled=0 | exec~name~caselessStartsWith("TraceLogStart")  then
     do
        ignoreExecs~put(exec)
        iterate
     end
     leave     -- we start with this one
  end

  indent="    "   -- indent string
  if useAggregate? then
     call showProfileTree exec, exec~duration, 0, useAggregate?
  else
     call showProfileTree exec, exec~avgDuration, 0, useAggregate?
  return

showProfileTree: procedure expose maxDepth ignoreExecs durationComparator indent
  use strict arg tmpExec, totalDuration, level=0, useAggregate?=.true

  if maxDepth>0, level=maxDepth then
  do
     say indent~copies(level-1) || "*** cut *** (exceeding maxDepth="maxDepth")" tmpExec~exec2string3
     return
  end

  if useAggregate? then
     say indent~copies(level) || calcPercent(totalDuration,tmpExec~duration)"%" tmpExec~exec2string3
  else
     say indent~copies(level) || calcPercent(totalDuration,tmpExec~avgDuration)"%" tmpExec~exec2string3avg

  if ignoreExecs~hasIndex(tmpExec) then
  do
     if tmpExec~setOfCalledExecs~items>0 then
        say indent~copies(level) || "*** cut *** (substructure got already displayed)"
     else
        say indent~copies(level) || "*** hint *** (already displayed)"
     return
  end

  ignoreExecs~put(tmpExec) -- do not show its children the next time

   -- process children
  do calledExec over tmpExec~setOfCalledExecs~allIndexes~sortWith(durationComparator)
     if useAggregate? then
        call showProfileTree calledExec, tmpExec~duration, level+1, useAggregate?
     else
        call showProfileTree calledExec, tmpExec~avgDuration, level+1, useAggregate?
  end
  return


/* ------------------------------------------------------------------------ */
::method createSQL
  expose tracelog allExecutables allInvocations execRunsInvocation execCreatesInvocation
  use strict arg dbName, sqlFileName, sqlSwitch="-s"

  .error~say
  .error~say(.line":" .context~name "- depending on the size of the tracelog ("tracelog~items "items) this may take a while ...")

  mbTO      =.MutableBuffer~new  -- insert TraceObjects
  mbSF      =.MutableBuffer~new  -- insert StackFrames
  mbCSF     =.MutableBuffer~new  -- insert CallerStackFrames
  mbVars    =.MutableBuffer~new  -- insert Variables
  mbExecs   =.MutableBuffer~new  -- insert Executables
  mbInvocs  =.MutableBuffer~new  -- insert Invocations (Activations)

  tracelog~sort      -- make sure it is sorted by number

  -- insert into TraceObject and related tables
  mbTO    ~append(.resources~sql_insert_traceobject     ~makeString)
  mbSF    ~append(.resources~sql_insert_stackFrame      ~makeString)
  mbCSF   ~append(.resources~sql_insert_callerStackFrame~makeString)
  mbVars  ~append(.resources~sql_insert_variable        ~makeString)

      -- use table sequence for fields
  to_fields="OPTION","NUMBER","TIMESTAMP","USTIMESTAMP","INTERPRETER","THREAD",      -
            "INVOCATION","LINENR","RECEIVER","RECEIVERCANONICALNAME", "RECEIVERID",  -
            "ATTRIBUTEPOOL","SCOPELOCKCOUNT","ISGUARDED","HASSCOPELOCK","ISWAITING", -
            "ISBLOCKED","TRACELINE"

  to_fields_break="RECEIVERID TRACELINE"  -- these are placed on a new indented line
  count_to_fields=to_fields~items


  sf_fields="NUMBER","ARGUMENTS","EXECUTABLEPACKAGE","EXECUTABLEID","INVOCATION","LINE","NAME",                -
            "PACKAGE","SCOPE","SCOPEID","SCOPEPACKAGE","TARGET","TARGETCANONICALNAME","TARGETID", -
            "TARGETPACKAGE","TARGETPACKAGEID","TRACELINE","TYPE"
  sf_fields_break="PACKAGE TARGETPACKAGE" -- these are placed on a new indented line
  count_sf_fields=sf_fields~items

   -- has a field "thread" in addition to a normal stackframe
  csf_fields="NUMBER","ARGUMENTS","EXECUTABLEPACKAGE","EXECUTABLEID","INVOCATION","LINE","NAME",                -
             "PACKAGE","SCOPE","SCOPEID","SCOPEPACKAGE","TARGET","TARGETCANONICALNAME","TARGETID", -
             "TARGETPACKAGE","TARGETPACKAGEID","TRACELINE","THREAD","TYPE"
  csf_fields_break="PACKAGE TARGETPACKAGE" -- these are placed on a new indented line
  count_csf_fields=csf_fields~items

  var_fields="NUMBER","NAME","VALUE","VALUETYPE","VALUEID","ASSIGNMENT"
  count_var_fields=var_fields~items

  count_TO=tracelog~items

  tab3="09"x
  crlf="0d0a"x
  sfAddComma =.false
  csfAddComma=.false
  varAddComma=.false

  do counter cto traceObj over traceLog
     -- process TO
     bNoOpenParen?=.true

     do counter cf field over to_Fields
        if field="USTIMESTAMP" then iterate  -- already handled
        if bNoOpenParen? then
        do
           mbTO~append(crlf, tab3, "(")
           bNoOpenParen?=.false  -- it is now available
        end

        if wordpos(field, "RECEIVERID TRACELINE")>0 then -- on new line
           mbTo~append(crlf, tab3)

        val=traceObj~send(field)
        if val==.nil then        -- not available
        do
-- say .line":" "field="pp(field) "isNULL!"
           mbTO~append("NULL")
        end
        else
        select case field
            when "TIMESTAMP" then   -- dateTime field
                 do
                    timestamp=traceObj~timestamp
                    mbTO~append("'", timestamp, "',")
                    mbTO~append(timestamp~fullDate) -- usTimeStamp: cf. DateTime: microsecends since "00-00-01 00:00:00.000000"
                 end

            when "OPTION", "RECEIVER", "RECEIVERCANONICALNAME", "RECEIVERID", -  -- enquote
                 "TRACELINE" then
                    mbTO~append(enquote2(traceObj~send(field),"'"))

            otherwise
                    mbTO~append(val)
        end
        if cf<count_to_fields then mbTO~append(",")
           -- break to a new line to match the field list in the INSERT part
     end
     mbTo~append(")")
     if cto<count_TO then mbTO~append(",", crlf)

     -- process SF
     currNumber=traceObj~number
     sf=traceObj~stackFrame
     if sf\==.nil then
     do
        sf~number=currNumber
        call process_stackFrame mbSF, sf, sf_fields, sf_fields_break, count_sf_fields, sfAddComma, cto<count_to
        sfAddComma=.true   -- from now on insert a comma first thing
     end

        -- process CSF (has one field - "thread" - more than SF)
     csf=traceObj~callerStackFrame
     if csf\==.nil then
     do
        csf~number=currNumber
        call process_stackFrame mbCSF, csf, csf_fields, csf_fields_break, count_csf_fields, csfAddComma, cto<count_to
        csfAddComma=.true  -- from now on insert a comma first thing
     end

     -- process VARS
     var=traceObj~variable
     if var\==.nil then
     do
        var~number=currNumber
        call process_stackFrame mbVars, var, varAddComma, cto<count_to
        varAddComma=.true  -- from now on insert a comma first thing
     end
  end

      -- insert into executable table
  mbExecs~append(.resources~sql_insert_executable~makeString)
  call process_execs mbExecs, allExecutables

      -- insert into invocation table
  mbInvocs~append(.resources~sql_insert_invocation~makeString)
  call process_invocs mbInvocs, allInvocations

      -- now create and write sql file
  sfn=.stream~new(sqlFileName)~~open("write replace")
  sfn~lineout("-- tracetool.rex, created file" enquote2(sqlFilename) "on:" .dateTime~new "using" enquote2(.rexxinfo~name) crlf)
      -- write prolog
  select case sqlSwitch
     when '-sl' then    -- SQLite
            prolog=.resources~sql_prolog_sqlite~makestring
     otherwise    -- default
            prolog=.resources~sql_prolog~makestring
  end

  sfn~lineout(prolog~changeStr("%dbname%",dbName) crlf)

      -- write create statements
  sfn~lineout(.resources~sql_create_tables)
  sfn~lineout(.resources~sql_create_views)

      -- write statements
  sfn~lineout(mbTO     ~~append(";",crlf)~string)

  if sfAddComma then    -- if stackframes got inserted
     sfn~lineout(mbSF  ~~append(";",crlf)~string)

  if csfAddComma then   -- if callerStackframes got inserted
     sfn~lineout(mbCSF ~~append(";",crlf)~string)

  if varAddComma then   -- if variables got inserted
     sfn~lineout(mbVars~~append(";",crlf)~string)

  sfn~lineout(mbExecs  ~~append(";",crlf)~string)
  sfn~lineout(mbInvocs ~~append(";",crlf)~string)

      -- write epilog
  .error~say
  select case sqlSwitch
     when '-sl' then    -- SQLite
            epilog=.resources~sql_epilog_sqlite~makestring
     otherwise    -- default
            epilog=.resources~sql_epilog~makestring
  end
  sfn~lineout(epilog crlf)
  sfn~close

  return

-------------------------------------------------
-- for both, stackFrame and callerStackFrame
process_stackFrame: procedure expose sf_fields count_sf_fields sf_fields_break tab3 crlf
  use strict arg mb, stackFrame, _fields, _fields_break, _count_fields, bAddComma, bLastTraceObj

  if bAddComma then mb~append(",", crlf) -- not the first stackframe record
  mb~append(tab3,"(")
  do counter csf field over _fields
     if wordpos(field,_fields_break)>0 then   -- field first on next line?
        mb~append(crlf, tab3)

     val=stackFrame~send(field)
     if val==.nil then
        mb~append("NULL")
     else
     do
        if wordpos(field, "NUMBER INVOCATION LINE THREAD")>0 then
           mb~append(val)
        else
           mb~append(enquote2(val,"'"))
     end
     if csf<_count_fields then mb~append(",") -- if not the last field
  end
  mb~append(")")
  return

-------------------------------------------------
process_vars: procedure       expose var_fields count_var_fields tab3 crlf
  use strict arg mb, var, bAddComma, bLastTraceObj
  if \bAddComma then mb~append(",") -- not the first stackframe record
  mb~append(crlf, tab3,"(")
  do counter csv field over sf_fields
     val=var~send(field)
     if val==.nil then
        mb~append("NULL")
     else
     do
        if wordpos(field, "NUMBER ASSIGNMENT")>0 then
           mb~append(val)                 -- unquoted
        else
           mb~append(enquote2(val,"'"))   -- quoted
     end
     if csv<count_var_fields then mb~append(",") -- if not the last field
  end
  mb~append(")")
  return

-------------------------------------------------
process_execs: procedure      expose tab3 crlf
  use strict arg mb, allExecs
-- executablePK,executableId,name,type,executablePackage,line,duration,usDuration,timesCalled,avgDuration,usAvgDuration
  allFields="EXECUTABLEID","NAME","TYPE","EXECUTABLEPACKAGE","LINE","DURATION","USDURATION", -
            "TIMESCALLED","AVGDURATION","USAVGDURATION","NUMBER"
  countExecs=allExecs~items

  do counter ce executablePK over allExecs
     exec=allExecs[executablePK]
     mb~append(tab3, "(", enquote2(executablePK,"'"))
     do field over allFields
        if wordpos(field, "USDURATION USAVGDURATION")>0 then -- already processed
           iterate

        val=exec~send(field)
        if val==.nil then
           mb~append(",NULL")
        else
           select case field
              when "EXECUTABLEID", "NAME", "TYPE", "EXECUTABLEPACKAGE" then
                  mb~append(",",enquote2(val,"'"))

              when "DURATION" then
                   do
                      mb~append(",",enquote2(val,"'"))
                      mb~append(",",val~totalMicroseconds)  -- usDuration value
                   end

              when "LINE", "TIMESCALLED", "NUMBER" then
                  mb~append(",",val)

              when "AVGDURATION" THEN
                   do
                      mb~append(",",enquote2(val,"'"))
                      mb~append(",",val~totalMicroseconds)  -- usDuration value
                   end

              otherwise nop
           end
     end
     mb~append(")")
     if ce<countExecs then mb~append(",", crlf)
  end
  return

-------------------------------------------------
process_invocs: procedure     expose tab3 crlf
  use strict arg mb, allInvocs

   -- enter, exit: TraceObject     (number)
   -- runby, createdby: Executable (executablePK)
  allFields="INVOCATIONKEY","DURATION","USDURATION","RUNBY","CREATEDBY","ENTER","EXIT"
  countInvocs=allInvocs~items

  do counter ci invocationId over allInvocs
     invocation=allInvocs[invocationId]
     mb~append(tab3, "(", invocation~invocationId)
     do field over allFields
        if field="USDURATION" then iterate   -- already handled
        val=invocation~send(field)
        if val==.nil then
           mb~append(",NULL")
        else
           select case field
              when "RUNBY", "CREATEDBY", "INVOCATIONKEY" then
                  mb~append(",",enquote2(val,"'"))

              when "DURATION" then
                   do
                      mb~append(",",enquote2(val,"'"))
                      mb~append(",",val~totalMicroseconds)  -- usDuration value
                   end

              when "ENTER", "EXIT" then   -- refer to TraceObject, use number as FK
              do
                  mb~append(",",val~number)
              end

              otherwise nop
           end
     end
     mb~append(")")
     if ci<countInvocs then mb~append(",", crlf)
  end
  return


/* ======================================================================== */
/* Create a primary key (PK) for the executable such that also internal calls
   (labels) can be represented on their own, despite not having a callerStackFrame
   revealing the executable that includes the invoked label.

      executable: ROUTINE or METHODCALL - return executableId
      executable: INTERNALCALL - return (label) name"@"executableId

   @param  traceObj the trace object to use
   @return trace object's executableId, or, if an internal call (a label) the
                 concatenation of name'@'executableId

*/
::routine getExecPK
  use strict arg stackFrame
  execID=stackFrame~executableId
  if stackFrame~type="INTERNALCALL" then
     return execID"/"stackFrame~name
     -- return stackFrame~name"@"execID
  return execID


/* ======================================================================== */
/** This class represents an executable ROUTINE, METHOD or INTERNALLCALL (label
 * invocations), where the latter is contained in ROUTINE and METHOD executables.
 *
*/
::class Executable private

/** An attribute that will hold a primary key for this exec which by default is
*   the value of the "executableID" attribute. In the case of an INTERNALLCALL
*   (label invocation) the "executableID" value will get '@' appended as well
*   as the "name" of the the invoked label.
*/
::attribute executablePK            -- primary key
::attribute executableId            -- ooRexx identifier value
::attribute executablePackage       -- ooRexx package name
::attribute duration                -- duration (total of all invocations run by this exec)
::attribute timesCalled             -- number of invocations
::attribute avgDuration             -- average duration (duration/timesCalled)
::attribute setOfCalledExecs        -- set of executables that get called by this executable
::attribute profiler                -- Profiler instance used to create this executable

/** By default objects of this type get sorted by the value of this string attribute.
 * It will be formatted as:
 <br>
   NAME[@CONTAINERNAME-or-EXECUTABLEID] TYPE LINE~right(max(6,LINE~length) EXECUTABLEPACKAGE)
   */
::attribute executableSortField     -- ease meaningful sorting
::attribute number                  -- from TraceObject (allow for establishing a sequence)
::attribute line                    -- from caller|stackFrame
::attribute name                    -- from caller|stackFrame
::attribute type                    -- from caller|stackFrame

::attribute containerName     -- .nil or name of executable containing invoked label

/* ------------------------------------------------------------------------ */
::method init
  expose executablePK executableId executablePackage executableSortField -
         line name type containerName  profiler duration timesCalled setOfCalledExecs -
         avgDuration number
  use strict arg profiler, stackFrame, executablePK, number

--  executablePK     =getExecPK(stackFrame)    -- assign generated primary key
  executableId     =stackFrame~executableId
  -- executablePackage=stackFrame~executablePackage   -- unedited package name
  executablePackage=editPath(stackFrame~executablePackage,"currDir")   -- unedited package name
  line             =nz(stackFrame~line)              -- REXX package returns .nil for its executables
  name             =stackFrame~name
  type             =stackFrame~type
  duration         =.TimeSpan~new(0,0)
  timesCalled      =0
  avgDuration      =.TimeSpan~new(0,0)
  setOfCalledExecs =.set~new
  containername    =.nil

  self~makeExecutableSortField               -- create value for sortfield

  -- .allExecutables~setEntry(executablePK,self)   -- add this executable
  profiler~allExecutables~setEntry(executablePK,self)   -- add this executable
  return


nz: procedure
  if arg(1)==.nil then return 0
  return arg(1)


/* ------------------------------------------------------------------------ */
/** Defines the value of the attribute "executableSortField". This method may
*   be also used in the "QA" class method, if executables got created for which
*   at creation time the name of the containing executable could not be determined
*   (because the executable was not yet created).
*
 * It will be formatted as:
 <br>
   NAME[@CONTAINERNAME-or-EXECUTABLEID] TYPE LINE~right(max(6,LINE~length) EXECUTABLEPACKAGE)
*/
::method makeExecutableSortField
  expose executableId executablePackage executableSortField -
         line name type containerName  profiler

  tmpName=name
  if type="INTERNALCALL" then -- this is an invoked label, add container's name
  do
     tmpName="/"name
     if containerName==.nil then -- try to locate it, if the executable got created in the meantime
     do
         containerExec=profiler~allExecutables~entry(executableId) -- try to get exec containing this label
         if containerExec\==.nil then
         do
            containerName=containerExec~name
            tmpName=containerName || tmpName
         end
         else
         do
            tmpName="(n/a)/" || tmpName
         end
     end
     else
     do
        tmpName=containerName || tmpName
     end
  end
  executableSortField=tmpName "("type 'L#' line "in" executablePackage")"


/* ------------------------------------------------------------------------ */
::method string
  expose executablePK executableId executablePackage executableSortField -
         line name traceObject type containerName duration

  -- return "Executable"pp(executableSortField)
  return "Executable"pp('duration='pp(duration)",executablePK="pp(executableSortField))


/* ------------------------------------------------------------------------ */
::method exec2string1   /* for debugging     */
  expose executablePK executableId executablePackage executableSortField    -
         line name traceObject type containerName duration timesCalled -
         setOfCalledExecs avgDuration
  use strict arg profiler=.nil   -- fetch profiler instance

  allInvocations="n/a"
  if profiler\==.nil then
  do
     allInvocations=profiler~execCreatesInvocation~allAt(executablePK)
     if allInvocations==.nil then
       allInvocations=""
     else
       allInvocations=allInvocations~makeArray~sortWith(.SortByInvocationKey~new)~toString(,',')
  end

  return duration",timesCalled="timesCalled                          || -
         ",avgDuration="avgDuration                                  || -
         ",calledExecs="setOfCalledExecs~items"->"pp(allInvocations) || -
         ",exec="pp(executableSortField)

/* ------------------------------------------------------------------------ */
::method exec2string2   /* for profile report   */
  expose executablePK executableId executablePackage executableSortField    -
         line name traceObject type containerName duration timesCalled -
         setOfCalledExecs avgDuration

  return duration "called" pp(adjRight(timesCalled,6,"_")) "times" pp(executableSortField)

/* ------------------------------------------------------------------------ */
::method exec2string2avg   /* for profile report   */
  expose executablePK executableId executablePackage executableSortField    -
         line name traceObject type containerName duration timesCalled -
         setOfCalledExecs avgDuration

  return duration "called" pp(adjRight(timesCalled,6,"_")) "times" avgDuration pp(executableSortField)

/* ------------------------------------------------------------------------ */
::method exec2string3   /* for profile report   */
  expose executablePK executableId executablePackage executableSortField    -
         line name traceObject type containerName duration timesCalled -
         setOfCalledExecs avgDuration

  return duration "called" adjRight(timesCalled,6) "times" || -
                  "/calling" adjRight(setOfCalledExecs~items,3) "execs" pp(executableSortField)

/* ------------------------------------------------------------------------ */
::method exec2string3avg   /* for profile report   */
  expose executablePK executableId executablePackage executableSortField    -
         line name traceObject type containerName duration timesCalled -
         setOfCalledExecs avgDuration

  return duration "called" adjRight(timesCalled,6) "times" avgDuration || -
                  "/calling" adjRight(setOfCalledExecs~items,3) "execs" pp(executableSortField)


/* ------------------------------------------------------------------------ */
::method compareTo   -- sort descendingly by executableSortField
  expose executableSortField
  use arg other
  return  executableSortField~caselessCompareTo(other~executableSortField)




/* ======================================================================== */
/** For each invocation keep the invocation start and invocation end TraceObject,
*   calculate duration (a TimeInterval).
*
*
*/
-- 20250214: new "key" attribute to cater for REPLY which has two invocations
--           with the same invocationId
::class Invocation   private
::attribute invocationKey        -- "invocationId" + " " + counter="1" (a REPLY causes two invocations with the same Id)
::attribute duration             -- a TimeSpan: exit~timespan - enter~timespan
::attribute invocationId         -- invocationID of this instance
-- ::attribute executablePK         -- executable that runs (executes) this instance
::attribute runBy                -- executable that runs (executes) this instance
::attribute createdBy            -- executable that caused this invocation to be created
/* ------------------------------------------------------------------------ */
::method compareTo
  expose invocationId invocationKey
  use arg other
  parse var invocationKey               selfNum1 "_" selfNum2
  parse value other~invocationKey with otherNum1 "_" otherNum2
  val=selfNum1-otherNum1
  if val=0 then
     val=selfNum2-otherNum2
  return sign(val)


::attribute enter get   -- getter for enter TraceObject
::attribute enter set   -- setter for enter TraceObject
  expose enter exit duration invocationId
  use strict arg enter
-- say .line":" "... enter~class:"  pp(enter~class)
  .Validate~classType("enter", enter,.TraceObject)
  if enter\==.nil, exit\==.nil then
     duration=exit~timeStamp - enter~timeStamp

if .bDebug=.true then
do
   if enter~isNil then enterStr="enter["enter"]"
                  else enterStr="enter[nr="enter~number","enter~timeStamp"]"
   if exit~isNil then exitStr="exit["exit"]"
                 else exitStr="exit[nr="exit~number","exit~timeStamp"]"
   .error~say("--- 2" pp(invocationId) ":" enterStr exitStr "duration="pp(duration))
end


::attribute exit  get   -- getter for exit TraceObject
::attribute exit  set   -- setter for exit TraceObject
  expose enter exit duration invocationId
  use strict arg exit
  .Validate~classType("exit", exit,.TraceObject)
  if enter\==.nil, exit\==.nil then
     duration=exit~timeStamp - enter~timeStamp

if .bDebug=.true then
do
   if enter~isNil then enterStr="enter["enter"]"
                  else enterStr="enter[nr="enter~number","enter~timeStamp"]"
   if exit~isNil then exitStr="exit["exit"]"
                 else exitStr="exit[nr="exit~number","exit~timeStamp"]"
   .error~say("--- 3" pp(invocationId) ":" enterStr exitStr "duration="pp(duration))
end

/* ------------------------------------------------------------------------ */
::method init
  expose invocationKey enter exit duration invocationId runBy createdBy
  use strict arg invocationKey, enter, exit=.nil

  .Validate~classType("enter", enter,.TraceObject)
  invocationId=enter~invocation

  if \exit~isNil then
     .Validate~classType("exit", exit,.TraceObject)

  if \enter~isNil, \exit~isNil then
     duration=exit~timeStamp - enter~timeStamp
  else
     duration=.TimeSpan~new(0,0)

  executablePK         =.nil     -- executable that runs this invocation
  createdBy            =.nil     -- executable that causd this invocation to be created

if .bDebug=.true then
do
   if enter~isNil then enterStr="enter["enter"]"
                  else enterStr="enter[nr="enter~number","enter~timeStamp"]"
   if exit~isNil then exitStr="exit["exit"]"
                  else exitStr="exit[nr="exit~number","exit~timeStamp"]"

   .error~say("--- 1" pp(invocationId) ":" enterStr exitStr "duration="pp(duration))
end


/* ------------------------------------------------------------------------ */
::method string
  expose invocationKey invocationId duration enter exit runBy createdBy

  enterStr="| enter={"traceObj2str(enter)"}"
  exitStr="| exit={"traceObj2str(exit)"}"

  return pp("invocationKey="invocationKey",duration="duration",execPK="runBy",creatorPK="createdBy || enterStr","exitStr)


/* ======================================================================== */
/** For debugging show all TraceObject entries
 *  totalDuration.
*/
::routine dumpTraceObject public
  use strict arg tobj
  leadin="***" "09"x
  w=19   -- maximum index name width
  do idx over tobj~allIndexes~sort
     o=tobj~send(idx)
     -- o=tobj~entry(idx)
     .error~say( .line":" "idx="pp(idx~left(w)) pp(o~class) pp(o) )
     if wordpos(idx, "STACKFRAME CALLERSTACKFRAME")>0 then
     do
        if o~isNil then
          .error~say( leadin "panic! STACKFRAME is .NIL ! ***" )
        else
        do idx2 over o~allIndexes~sort
           -- o2=o~send(idx2)
           o2=o~entry(idx2)
           .error~say( leadin "idx2="pp(idx2~left(w)) pp(o2~class) pp(o2) )
        end
     end
  end
  .error~say


/* ========================================================================= */
::routine traceObj2str public   -- a function
  use strict arg tobj
  if tobj~isNil then return nz(tobj)
  str="nr="tObj~number",ID="tObj~invocation",l#="tObj~linenr
  str=str || ",timeStamp="tObj~timestamp~longTime
  str=str || ",name="nz(tobj~stackFrame~name)",type="nz(tobj~stackFrame~type)",traceline="nz(tobj~traceline)~left(15)
  return str

nz: procedure
  if arg(1)~isNil then return ".nil"
  return arg(1)



/* ========================================================================= */

/* ========================================================================== */

/* Developed with SQLite which is very tolerant, e.g. does not need size for N|VARCHAR.
 *
 * Tested with MariaDB which mandates sizes and is itch picking with wrong numer of
 * dashes in line comment, hence tried to adapt the SQL statements accordingly. N|VARCHAR
 * columns must have a size. "exit" is a reserved word, even using the literal quotes
 * does not allow their use (would have to rename it to e.g. "exitTraceObj" or the like).
 * As the purpose of this application can be achieved with SQLite, any further work
 * for other RDBMS is stalled as each RDBMS seems to have its own unique constraints,
 * not worth to be honored by a person with too much time constraints. :)
 * Therefore removed the N|VARCHAR changes (removing size info).
 *
*/

-- note: SQLite does not need size vor N|VARCHAR, MariaDB enforces them

::resource sql_create_tables


-- section create structures

/* ------------------------------------------------------------------------------ */

/* define tables for representing TraceObject instances, field order according to
*  traceutil.cls' .field.order.annotated; structures variable, stackFrame,
*  callerStackFrame are offloaded to proper dependent tables (see view
*  fullTraceObject below);
*  field usTimeStamp gets added, rendering the timestamp (a DateTime object)
*  as microseconds
*/
CREATE TABLE traceObject (
            option                  VARCHAR,    -- TraceObject
            number                  INTEGER NOT NULL PRIMARY KEY,   -- TraceObject
            timestamp               DATETIME,   -- TraceObject -- as per 202501 SQL supports only 1/1000 of a second
            usTimestamp             BIGINT,     -- by traceutil: represent 1/1 000 000 of a second (microsecond)
            interpreter             INTEGER,    -- TraceObject
            thread                  INTEGER,    -- TraceObject
            invocation              INTEGER,    -- TraceObject
            lineNr                  INTEGER,    -- by tracetool: from stackframe
            receiver                NVARCHAR,   -- by tracetool: object related, from stackframe
            receiverCanonicalName   NVARCHAR,   -- by tracetool: object related, from stackframe
            receiverId              VARCHAR,    -- by tracetool: object related, from stackframe
            attributePool           INTEGER,    -- object related
            scopeLockCount          INTEGER,    -- object related
            isGuarded               BOOL,       -- object related
            hasScopeLock            BOOL,       -- object related
            isWaiting               BOOL,       -- object related, added by -a (analyze) switch
            isBlocked               BOOL,       -- object related, added by -a (analyze) switch
            traceLine               NVARCHAR    -- TraceObject
           );



/* ------------------------------------------------------------------------------ */

/* field order according to traceutil.cls' .entry.names.stackframe */

CREATE TABLE stackFrame (
            number                  INTEGER NOT NULL PRIMARY KEY, -- by traceutil
            arguments               NVARCHAR,   -- TraceObject
            executablePackage       NVARCHAR,   -- traceutil
            executableId            VARCHAR,    -- traceutil
            invocation              INTEGER,    -- TraceObject
            line                    INTEGER,    -- TraceObject
            name                    NVARCHAR,   -- TraceObject -- routine/method name
            package                 NVARCHAR,   -- traceutil  -- package name
            scope                   NVARCHAR,   -- TraceObject -- object related
            scopeId                 VARCHAR ,   -- by traceutil -- object related
            scopePackage            NVARCHAR,   -- by traceutil -- object related
            target                  NVARCHAR,   -- TraceObject -- object related
            targetCanonicalName     NVARCHAR,   -- TraceObject -- object related
            targetId                VARCHAR,    -- by traceutil -- object related
            targetPackage           NVARCHAR,   -- by traceutil -- object related
            targetPackageId         VARCHAR,    -- by traceutil -- object related
            traceLine               NVARCHAR,   -- TraceObject
            type                    VARCHAR     -- TraceObject

            , FOREIGN KEY (number) REFERENCES traceObject (number)
           );

/* ------------------------------------------------------------------------------ */

/* field order according to traceutil.cls' .entry.names.stackframe */

CREATE TABLE callerStackFrame (
            number                  INTEGER NOT NULL PRIMARY KEY, -- by traceutil
            arguments               NVARCHAR,   -- TraceObject
            executablePackage       NVARCHAR,   -- traceutil
            executableId            VARCHAR,    -- traceutil
            invocation              INTEGER,    -- TraceObject
            line                    INTEGER,    -- TraceObject
            name                    NVARCHAR,   -- TraceObject -- routine/method name
            package                 NVARCHAR,   -- by traceutil -- package name
            scope                   NVARCHAR,   -- TraceObject -- object related
            scopeId                 VARCHAR,    -- by traceutil -- object related
            scopePackage            NVARCHAR,   -- by traceutil -- object related
            target                  NVARCHAR,   -- TraceObject -- object related
            targetCanonicalName     NVARCHAR,   -- TraceObject -- object related
            targetId                VARCHAR,    -- by traceutil -- object related
            targetPackage           NVARCHAR,   -- by traceutil -- object related
            targetPackageId         VARCHAR,    -- by traceutil -- object related
            traceLine               NVARCHAR,   -- TraceObject
            thread                  INTEGER,    -- TraceObject
            type                    VARCHAR     -- TraceObject

            , FOREIGN KEY (number) REFERENCES traceObject (number)
           );

/* ------------------------------------------------------------------------------ */

/* field order according to traceutil.cls' .entry.names.variables */

CREATE TABLE variable (
            number                  INTEGER NOT NULL PRIMARY KEY, -- by traceutil
            name                    VARCHAR,    -- TraceObject
            value                   NVARCHAR,   -- TraceObject
            valueType               VARCHAR,    -- TraceObject
            valueId                 VARCHAR,    -- by traceutil
            assignment              BOOL        -- TraceObject

            , FOREIGN KEY (number) REFERENCES traceObject (number)
           );


/* ------------------------------------------------------------------------------ */

/* define table for representing the profiled data, cf. traceutil.cls' class "executable" */

CREATE TABLE executable (
            executablePK            NVARCHAR NOT NULL PRIMARY KEY,
            executableId            VARCHAR,
            name                    NVARCHAR,
            type                    VARCHAR,
            number                  INTEGER,    -- TraceObject's sequence number
            executablePackage       NVARCHAR,
            line                    INTEGER,
            duration                DATETIME,   -- as per 202501 SQL supports only 1/1000 of a second
            usDuration              BIGINT,     -- represent 1/1 000 000 of a second (microsecond)
            timesCalled             INTEGER,
            avgDuration             DATETIME,   -- as per 202501 SQL supports only 1/1000 of a second
            usAvgDuration           BIGINT      -- represent 1/1 000 000 of a second (microsecond)
           );

/* ------------------------------------------------------------------------------ */

/* define table for representing the profiled data, cf. traceutil.cls' class "invocation" */

CREATE TABLE invocation (
            invocationKey           VARCHAR NOT NULL PRIMARY KEY,
            invocationId            INTEGER NOT NULL,
            duration                DATETIME,   -- as per 202501 SQL supports only 1/1000 of a second
            usDuration              BIGINT,     -- represent 1/1 000 000 of a second (microsecond)
            runBy                   INTEGER,
            createdBy               INTEGER,
            enter                   INTEGER,
            exit                    INTEGER

            , FOREIGN KEY (invocationId) REFERENCES traceObject (invocation)  -- note target is not a PK, works with SQLite
            , FOREIGN KEY (runBy       ) REFERENCES executable  (executablePK)
            , FOREIGN KEY (createdBy   ) REFERENCES executable  (executablePK)
            , FOREIGN KEY (enter       ) REFERENCES traceObject (number      )
            , FOREIGN KEY (exit        ) REFERENCES traceObject (number      )
           );

::END



/* ========================================================================== */

-- TODO: add "number" to executable, "invocationKey" to invocation

::resource sql_create_views

/* ------------------------------------------------------------------------------ */

/* create full view on traceobject (recombine structures with traceObject) */

DROP VIEW IF EXISTS fullTraceObject;

CREATE VIEW fullTraceObject AS
    SELECT  traceObject.*,
            sf.number               AS sfNumber              ,
            sf.arguments            AS sfArguments           ,
            sf.executablePackage    AS sfExecutablePackage   ,
            sf.executableId         AS sfExecutableId        ,
            sf.invocation           AS sfInvocation          ,
            sf.line                 AS sfLine                ,
            sf.name                 AS sfName                ,
            sf.package              AS sfPackage             ,
            sf.scope                AS sfScope               ,
            sf.scopeId              AS sfScopeId             ,
            sf.scopePackage         AS sfScopePackage        ,
            sf.target               AS sfTarget              ,
            sf.targetCanonicalName  AS sfTargetCanonicalName ,
            sf.targetId             AS sfTargetId            ,
            sf.targetPackage        AS sfTargetPackage       ,
            sf.targetPackageId      AS sfTargetPackageId     ,
            sf.traceLine            AS sfTraceLine           ,
            sf.type                 AS sfType                ,

           csf.number               AS csfNumber             ,
           csf.arguments            AS csfArguments          ,
           csf.executablePackage    AS csfExecutablePackage  ,
           csf.executableId         AS csfExecutableId       ,
           csf.invocation           AS csfInvocation         ,
           csf.line                 AS csfLine               ,
           csf.name                 AS csfName               ,
           csf.package              AS csfPackage            ,
           csf.scope                AS csfScope              ,
           csf.scopeId              AS csfScopeId            ,
           csf.scopePackage         AS csfScopePackage       ,
           csf.target               AS csfTarget             ,
           csf.targetCanonicalName  AS csfTargetCanonicalName,
           csf.targetId             AS csfTargetId           ,
           csf.targetPackage        AS csfTargetPackage      ,
           csf.targetPackageId      AS csfTargetPackageId    ,
           csf.traceLine            AS csfTraceLine          ,
           csf.thread               AS csfThread             ,
           csf.type                 AS csfType               ,

           var.number               AS varNumber             ,
           var.name                 AS varName               ,
           var.value                AS varValue              ,
           var.valueType            AS varValueType          ,
           var.valueId              AS varValueId            ,
           var.assignment           AS varAssignment

    FROM   traceObject
    LEFT JOIN stackFrame AS sf        ON sf.number =traceObject.number
    LEFT JOIN callerStackFrame AS csf ON csf.number=traceObject.number
    LEFT JOIN variable AS var         ON var.number=traceObject.number

    ORDER BY number;

/* ------------------------------------------------------------------------------ */

/* create the extended prefix view for traceObject */

DROP VIEW IF EXISTS prefixTraceObject;

CREATE VIEW prefixTraceObject AS
    SELECT CONCAT('[',  'R', interpreter, ' T', thread,
                       ' I', invocation,

                    CASE  WHEN isGuarded is NULL THEN ''
                          WHEN isGuarded=1 THEN ' G'
                          ELSE ' U'
				        END,

                    CASE WHEN isGuarded is NULL THEN ''
                         WHEN isGuarded=1 AND hasScopeLock=0 THEN 'u '
                         WHEN isGuarded=0 AND hasScopeLock=1 THEN 'g '
                         ELSE '  '
					     END,

                    CASE WHEN attributePool IS NULL THEN ''
                         ELSE CONCAT('A',attributePool,' ')
					     END,

                    CASE WHEN scopeLockCount IS NULL THEN ''
                         ELSE CONCAT('L',scopeLockCount,' ')
					     END,

                    CASE WHEN hasScopeLock is NULL THEN ''
                         ELSE '*'
				        END,

                    CASE WHEN attributePool IS NULL AND isBlocked=1 THEN '            B'
                         WHEN attributePool IS NULL AND isWaiting=1 THEN '            W'
                         WHEN isBlocked=1 THEN ' B'
                         WHEN isWaiting=1 THEN ' W'
                         ELSE ''
				        END,

					']') extPrefix,
            traceLine,
            number, interpreter, thread, invocation,
            isGuarded, attributePool, scopeLockCount, hasScopeLock, isBlocked, isWaiting,
            timeStamp, usTimeStamp

    FROM   traceObject

    ORDER BY number;


/* ------------------------------------------------------------------------------ */

/* create the extended view for invocation (activation),
   we use left outer joins to not lose invocations that have no
   valid enter, exit, runbBy or createdBy FK */

DROP VIEW IF EXISTS fullInvocation;

CREATE VIEW fullInvocation AS
    SELECT invocation.*,

           ent.option                      AS enterOption,
           ent.number                      AS enterNumber,
           ent.timestamp                   AS enterTimestamp,
           ent.usTimestamp                 AS enterUsTimestamp,
           ent.interpreter                 AS enterInterpreter,
           ent.thread                      AS enterThread,
           ent.invocation                  AS enterInvocation,
           ent.csfInvocation               AS enterCsfInvocation, -- determines invoker
           ent.csfThread                   AS enterCsfThread,     -- if spawned because of reply or start
           ent.csfTraceLine                AS enterCsfTraceLine,
           ent.lineNr                      AS enterLineNr,
           ent.receiver                    AS enterReceiver,
           ent.receiverCanonicalName       AS enterReceiverCanonicalName,
           ent.receiverId                  AS enterReceiverId,
           ent.attributePool               AS enterAttributePool,
           ent.scopeLockCount              AS enterScopeLockCount,
           ent.isGuarded                   AS enterIsGuarded,
           ent.hasScopeLock                AS enterHasScopeLock,
           ent.isWaiting                   AS enterIsWaiting,
           ent.isBlocked                   AS enterIsBlocked,
           ent.traceLine                   AS enterTraceLine,

           exi.option                      AS exitOption,
           exi.number                      AS exitNumber,
           exi.timestamp                   AS exitTimestamp,
           exi.usTimestamp                 AS exitUsTimestamp,
           exi.interpreter                 AS exitInterpreter,
           exi.thread                      AS exitThread,
           exi.invocation                  AS exitInvocation,
           exi.lineNr                      AS exitLineNr,
           exi.receiver                    AS exitReceiver,
           exi.receiverCanonicalName       AS exitReceiverCanonicalName,
           exi.receiverId                  AS exitReceiverId,
           exi.attributePool               AS exitAttributePool,
           exi.scopeLockCount              AS exitScopeLockCount,
           exi.isGuarded                   AS exitIsGuarded,
           exi.hasScopeLock                AS exitHasScopeLock,
           exi.isWaiting                   AS exitIsWaiting,
           exi.isBlocked                   AS exitIsBlocked,
           exi.traceLine                   AS exitTraceLine,

           runByExec.executablePK          AS runByExecutablePK,
           runByExec.executableId          AS runByExecutableId,
           runByExec.name                  AS runByName,
           runByExec.type                  AS runByType,
           runByExec.executablePackage     AS runByExecutablePackage,
           runByExec.line                  AS runByLine,
           runByExec.duration              AS runByDuration,
           runByExec.usDuration            AS runByUsDuration,
           runByExec.timesCalled           AS runByTimesCalled,
           runByExec.avgDuration           AS runByAvgDuration,
           runByExec.usAvgDuration         AS runByUsAvgDuration,

           createdByExec.executablePK      AS createdByExecutablePK,
           createdByExec.executableId      AS createdByExecutableId,
           createdByExec.name              AS createdByName,
           createdByExec.type              AS createdByType,
           createdByExec.executablePackage AS createdByExecutablePackage,
           createdByExec.line              AS createdByLine,
           createdByExec.duration          AS createdByDuration,
           createdByExec.usDuration        AS createdByUsDuration,
           createdByExec.timesCalled       AS createdByTimesCalled,
           createdByExec.avgDuration       AS createdByAvgDuration,
           createdByExec.usAvgDuration     AS createdByUsAvgDuration

    FROM   invocation
    LEFT JOIN fullTraceObject AS ent           ON enter    =ent.number
    LEFT JOIN traceObject     AS exi           ON exit     =exi.number
    LEFT JOIN executable      AS runByExec     ON runBy    =runByExec.executablePK
    LEFT JOIN executable      AS createdByExec ON createdBy=createdByExec.executablePK

    ORDER BY invocationKey;


/* ------------------------------------------------------------------------------ */

/* create a CTE view that calculates the call levels and call paths
*/

DROP VIEW IF EXISTS invocationWithLevels;

CREATE VIEW invocationWithLevels AS

   WITH RECURSIVE invocationTree AS (
      SELECT invocationKey, invocationId, runBy, runByName, createdBy, createdByName,
             enter, enterLineNr, enterCsfInvocation, enterCsfTraceline,
             exit, exitLineNr,
             enterUsTimestamp,
   	       0 AS level,
             '' AS path,
             '' AS pathByName,
             enterTraceLine, exitTraceLine
      FROM   fullInvocation
      WHERE  createdBy NOT IN (SELECT runBy FROM invocation)

      UNION ALL

      SELECT e.invocationKey, e.invocationId, e.runBy, e.runByName, e.createdBy, e.createdByName,
             e.enter, e.enterLineNr, e.enterCsfInvocation, e.enterCsfTraceline,
             e.exit, e.exitLineNr,
             e.enterUsTimestamp,
   		    rec.level+1,
             rec.path || ' -> ' || e.createdBy,
             rec.pathByName || ' -> ' || e.createdByName,
             e.enterTraceLine, e.exitTraceLine
      FROM   fullInvocation e
      -- INNER JOIN invocationTree rec ON e.createdBy=rec.runBy
      INNER JOIN invocationTree rec ON e.enterCsfInvocation=rec.invocationId

LIMIT 5000  -- safety belt (may need to be increased or commented out for very large tracelogs)
   )
    SELECT *
    FROM     invocationTree
    GROUP BY invocationKey
    ORDER BY invocationId, invocationKey
    ;

::END

/* ========================================================================== */
::resource sql_insert_traceobject

/* ------------------------------------------------------------------------------ */

-- section insert traceObject rows

INSERT INTO traceObject (
            option,number,timestamp,usTimestamp,interpreter,thread,invocation,lineNr,receiver,receiverCanonicalName,
            receiverId,attributePool,scopeLockCount,isGuarded,hasScopeLock,isWaiting,isBlocked,
            traceLine
            )
      VALUES

::END

/* ========================================================================== */
::resource sql_insert_stackFrame       -- traceObject related

/* ------------------------------------------------------------------------------ */

-- section insert stackFrame rows

INSERT INTO stackFrame (
            number,arguments,executablePackage,executableId,invocation,line,name,
            package,scope,scopeId,scopePackage,target,targetCanonicalName,targetId,
            targetPackage,targetPackageId,traceLine,type
            )
      VALUES

::END



/* ========================================================================== */
::resource sql_insert_callerStackFrame -- traceObject related

/* ------------------------------------------------------------------------------ */

-- section insert callerStackFrame rows

INSERT INTO callerStackFrame (
            number,arguments,executablePackage,executableId,invocation,line,name,
            package,scope,scopeId,scopePackage,target,targetCanonicalName,targetId,
            targetPackage,targetPackageId,traceLine,thread,type
            )
      VALUES

::END

/* ========================================================================== */
::resource sql_insert_variable         -- traceObject related

/* ------------------------------------------------------------------------------ */

-- section insert variable rows

INSERT INTO variable (
            number,name,value,valueType,valueId,assignment
            )
      VALUES

::END


/* ========================================================================== */
::resource sql_insert_executable       -- profiling related

/* ------------------------------------------------------------------------------ */

-- section insert executable rows

INSERT INTO executable (
            executablePK,executableId,name,type,executablePackage,line,duration,usDuration,timesCalled,avgDuration,usAvgDuration,number
            )
      VALUES

::END


/* ========================================================================== */
::resource sql_insert_invocation       -- profiling related

------------------------------------------------------------------------------

-- section insert invocation rows

INSERT INTO invocation (
            invocationId,invocationKey,duration,usDuration,runBy,createdBy,enter,exit
            )
      VALUES

::END


/* ========================================================================== */
::resource sql_prolog                  -- generic SQL

/* if database exists, then uncomment the following statement */
-- DROP   DATABASE %dbname%;

CREATE DATABASE %dbname%;
USE %dbname%;
/*
    URLs for related information (as of 2025-02-18):

       - Rexx symposium presenation on the introduction of the TraceObject class (new in 5.1):
         <https://www.rexxla.org/presentations/2024/202403-03_debugging_MT_programming.pdf>

         search for all RexxLA symposium presentations: <https://www.rexxla.org/events/presentation.rsp>

       - article "Devising a TraceObject Class for Improved Runtime Monitoring of ooRexx Applications"
         <https://research.wu.ac.at/en/publications/devising-a-traceobject-class-for-improved-runtime-monitoring-of-o>

       - article "Debugging Multithreaded ooRexx Programs":
         <https://research.wu.ac.at/en/publications/debugging-multithreaded-oorexx-programs>
*/

::END

-- TODO: create constraints after filling the tables for performance reasons?
--       if so, create some sql_epilog resource

/* ========================================================================== */
::resource sql_epilog                  -- generic SQL


::END


/* ========================================================================== */
::resource sql_prolog_sqlite           -- SQLite specific

/*  SQLite SQL script

    - a quick guide

      tracetool -tr some.rex  ... runs "some.rex" using trace result and
                                  creates tracelog "some.rex_trace.xml"

      tracetool -p -sl some.rex_trace.xml ... analyzes the tracelog, shows some
                                  profile data and creates a SQLite sql file
                                  "some.rex_trace.sql"

      sqlite3 some_rex_trace.db < some.rex_trace.sql ... creates the sqlite database
                                  file "some_rexx_trace.db", applies all of
                                  "some.rex_trace.sql" and awaits user input (.help
                                  or .exit)

      .help
      .www              -- next sqlite3 command outputs to browser
      select * from prefixTraceObject; -- execute query, show results in browser
      select * from prefixTraceObject; -- execute query, show results in sqlite3
      .exit             -- exit sqlite3


    URLs (as of 2025-02-18):

       - sqlite: <https://www.sqlite.org/download.html>
                 - look for the bundle, sqlite3 includes SQLite
                 - tutorial for the command shell sqlite3: <https://sqlite.org/cli.html>
                 - documentation: <https://sqlite.org/docs.html>

       - DB Browser for SQLite (a free and portable SQLite GUI interface):
         <https://sqlitebrowser.org/dl/>

       - Rexx symposium presentation on the introduction of the TraceObject class (new in 5.1):
         <https://www.rexxla.org/presentations/2024/202403-03_debugging_MT_programming.pdf>

         search for all RexxLA symposium presentations: <https://www.rexxla.org/events/presentation.rsp>

       - article "Devising a TraceObject Class for Improved Runtime Monitoring of ooRexx Applications"
         <https://research.wu.ac.at/en/publications/devising-a-traceobject-class-for-improved-runtime-monitoring-of-o>

       - article "Debugging Multithreaded ooRexx Programs":
         <https://research.wu.ac.at/en/publications/debugging-multithreaded-oorexx-programs>
*/

::END


/* ========================================================================== */
::resource sql_epilog_sqlite           -- SQLite specific

-- configure SQLite to force foreign key rules
PRAGMA foreign_keys = ON;        -- make sure foreign keys get honored from now on

-- demonstrate sqlite3, the command line shell for SQLite
.echo on
.mode box --wrap 120

/* ------------------------------------------------------------------------- */
-- show the first 10 traceLines

SELECT traceLine
FROM   traceObject
ORDER BY number
LIMIT 10;


/* ------------------------------------------------------------------------- */
-- show number, extPrefix, traceLine

SELECT extPrefix, traceLine
FROM   prefixTraceObject
ORDER BY number
LIMIT 10;


/* ------------------------------------------------------------------------- */
-- show the ten longest running executables in descending order (box output mode)
.mode box --wrap 30

SELECT   type, name, line, executablePackage, duration,
         timesCalled, avgDuration, executablePK
FROM     executable
ORDER BY duration DESC, name
LIMIT    10;


/* ------------------------------------------------------------------------- */
-- show the first 10 traceLines (list output mode)
.echo on
.mode list --wrap 100
.mode

SELECT FORMAT('%6d', number) AS 'number', traceLine
FROM   traceObject
ORDER BY number
LIMIT 10;


/* ------------------------------------------------------------------------- */
-- show number, extPrefix, traceLine, limit output to 10 records (column output mode)
-- .mode column
.mode table --wrap 100

.mode

SELECT FORMAT('%6d', number) AS 'number', extPrefix, traceLine
FROM   prefixTraceObject
ORDER BY number
LIMIT 10;


/* ------------------------------------------------------------------------- */
-- show the ten longest running executables in descending order (markdown output mode)
.mode markdown
.mode

SELECT   type, name, FORMAT('%5d',line) AS 'line', executablePackage, duration,
         FORMAT('%11d',timesCalled) AS 'timesCalled', avgDuration, executablePK
FROM     executable
ORDER BY duration DESC, name
LIMIT    10;

/* ------------------------------------------------------------------------- */
-- now add the percentage, limit output to 10 records (box output mode)
.mode box
.mode

WITH sumTable (usSumDuration) AS (
    SELECT SUM(usDuration) AS usSumDuration
    FROM executable
    )
SELECT   type, name, FORMAT('%5d',line) AS 'line', executablePackage, duration,
         FORMAT('%6.2f%',(CAST(usDuration AS FLOAT)*100/sumTable.usSumDuration)) AS '%',
         FORMAT('%11d',timesCalled) AS 'timesCalled', executablePK
FROM     executable, sumTable
ORDER BY duration DESC, name
LIMIT    10;

/* ------------------------------------------------------------------------- */
-- demonstrate the invocationWithLevels view, limit output to 30 records
.mode box --width=35
SELECT   printf('%13s',invocationKey) as invocationKey,
         runByName, FORMAT('%9d',enterCsfInvocation) AS invokedBy,
         pathByName, FORMAT('%5d',level) AS level,
         enterCsfTraceLine AS csfTraceLine
FROM     invocationWithLevels
WHERE    pathByName <> ''
ORDER BY invocationid, invocationKey
LIMIT    30;


/* ------------------------------------------------------------------------- */
-- demonstrate the invocationWithLevels view
-- this time show output in www browser
.www
SELECT   printf('%13s',invocationKey) as invocationKey,
         runByName, FORMAT('%9d',enterCsfInvocation) AS invokedBy,
         pathByName, FORMAT('%5d',level) AS level,
         enterCsfTraceLine AS csfTraceLine
FROM     invocationWithLevels
WHERE    pathByName <> ''
ORDER BY invocationid, invocationKey;

-- you are all set!

::END


