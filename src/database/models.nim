import macros, macroplus
import options, strutils, strformat, sequtils, tables

type
    SqliteColumnTypes {.pure.} = enum
        SCTint = "int"
        SCTtext = "string"
        SCTvarchar = "char"

    SqliteColumnFeatures {.pure.} = enum
        SCFNullable, SCFprimary

    SqliteTableFeatures = enum
        STFaddId, STFcreateDate, STFupdateDate

    DBTable = object
        name: string
        columns: seq[Column]
        features: set[SqliteTableFeatures]

    Column = object
        name: string
        `type`: SqliteColumnTypes
        typeLimit: int
        refrence: Option[tuple[tableName, fieldName: string]]
        features: set[SqliteColumnFeatures]

proc `$`(t: DBTable): string =
    fmt"table '{t.name}':" & "\n" & (
        t.columns.mapIt indent(fmt"{it.name}: {$ it.`type`}", 4)
    ).join("\n")

func nimType2SqliteType(ntype: string): string =
    discard

proc tableGen(rawTable: NimNode): DBTable =
    doAssert rawTable[CommandIdent].strVal == "Table", "Entity is not Valid"

    let tableName = rawTable[1].strVal
    result = DBTable(name: tableName)

    for rawColumn in rawTable[CommandBody]:
        let columnName = rawColumn[CommandIdent].strVal
        var params = rawColumn[CommandBody]

        if params[0].kind == nnkCommand: # for columns with featues
            params = params[0]

        var
            `type` = params[0]
            column = Column(name: columnName)

        # FIXME not working with Option[char[200]]
        if `type`.kind == nnkBracketExpr:
            if `type`[BracketExprIdent].strVal == "Option": # Option[string]
                column.features.incl SCFNullable
                `type` = `type`[1]

            else: # string[value] | int[ref anotherTable.field]
                let
                    args = `type`[BracketExprParams]
                    firstArg = args[0]
                `type` = `type`[BracketExprIdent]

                if firstArg.kind == nnkRefTy:
                    doassert firstArg[0].kind == nnkDotExpr

                    let
                        refTable = firstArg[0][0].strval
                        refField = firstArg[0][1].strval

                elif firstarg.allIt it.kind in [nnkIntLit, nnkStrLit]:
                    column.typeLimit = args[0].intVal.int

                else:
                    error "invalid type options"

        column.`type` = parseEnum[SqliteColumnTypes](`type`.strVal)

        if params.len == 2:
            for feature in params[1]:
                doAssert feature.strVal in ["primary"]

                column.features.incl:
                    case feature.strval:
                    of "primary": SCFprimary
                    else: raise newException(ValueError, "column feature is not defined")

        result.columns.add column

type Schema = Table[string, DBTable]

proc schemaGen(args, body: NimNode): Schema =
    for rawTable in body:
        let table = tableGen(rawTable)
        result[table.name] = table


macro Blueprint(features, body) =
    echo treeRepr body
    
    let schema = schemaGen(features, body)

    for (name, table) in schema.pairs:
        echo table


Blueprint [autoId]:
    Table test1:
        id: int[ref another.id]
        num: int {primary}
        name: char[255]

    # Table members:
    #     id: int {primary}
    #     name: string[255]

    # Table part:
    #     id: int {primary}
    #     name: string

    # Table quiz:
    #     id: int {primary}
    #     member_id: int[ref members.id]
    #     name: string[255]
    #     part_id: int[ref part.id]

    # Table question:
    #     id: int {primary}
    #     quiz_id: int[ref quiz.id]
    #     answer: int

    # Table record:
    #     id: int {primary}
    #     member_id: int[ref members.id] {update: restrict, delete: restric}
    #     date: DateTime {auto}

    # Table test:
    #     field: Option[string]
