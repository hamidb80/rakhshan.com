import db_sqlite, sequtils, strutils
import models

template dbworks*(path: string, body): untyped =
    block:
        let db{.inject.} = open(path, "", "", "")
        body
        db.close()

proc getMembers*(db: DbConn): seq[MembersModel] =
    db.getAllRows(
        sql"SELECT id, name FROM members"
    )
    .mapIt MembersModel(id: parseint it[0], name: it[1])

proc insertMember*(db: DbConn, name: string): int64 =
    db.insertID(
        sql"INSERT INTO members (name) VALUES (?)",
        name
    )
