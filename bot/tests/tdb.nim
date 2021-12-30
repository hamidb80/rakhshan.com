import 
    unittest, db_sqlite,
    strutils, sequtils, os, re, sets
import database/[models, queries]

suite "general":
    test "valid init query":
        dbworks "play.db":
            let tables = (initQuery.findAll re"CREATE TABLE \w+").mapIt it[13..^1]

            for command in initQuery.split ";\n":
                db.exec (command & ";").sql

            
            let insertedTables =
                (db.getAllRows "SELECT name FROM sqlite_master WHERE type='table';".sql)
                .mapIt it[0]

            check insertedTables.toHashSet == tables.toHashSet

    removeFile "play.db"
