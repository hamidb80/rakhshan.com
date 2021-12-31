import 
    unittest, db_sqlite, strutils, sequtils, os, sets
import database/[models, queries]

suite "general":
    test "valid init query":
        dbworks "play.db":
            let tables = 
                initQuery
                .filterIt(it.startsWith "CREATE TABLE")
                .mapIt it[13..^1].split({'('})[0]

            for command in initQuery:
                db.exec (command & ";").sql

            let insertedTables =
                (db.getAllRows "SELECT name FROM sqlite_master WHERE type='table';".sql)
                .mapIt it[0]

            check insertedTables.toHashSet == tables.toHashSet

    removeFile "play.db"
