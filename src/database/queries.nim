import db_sqlite, sequtils, strutils 
import models

using db: DbConn

template dbworks*(path: string, body): untyped =
    block:
        let db{.inject.} = open(path, "", "", "")
        body
        db.close()

# member ----------------------------------------

proc getMembers*(db): seq[MemberModel] =
    db.getAllRows(sql"SELECT id, name FROM member")
    .mapIt MemberModel(id: parseint it[0], name: it[1])

proc getNember*(db): MemberModel =
    let row = db.getRow(sql"SELECT id, name FROM member")
    MemberModel(id: parseint row[0], name: row[1])

proc addMember*(db; name: string): int64 =
    db.insertID(
        sql"INSERT INTO member (name) VALUES (?)",
        name
    )

# member ----------------------------------------
