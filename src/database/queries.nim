import db_sqlite, sequtils, strutils
import models

template dbworks*(path: string, body): untyped =
    block:
        let db{.inject.} = open(path, "", "", "")
        body
        db.close()

# member ----------------------------------------

proc getMembers*(db: DbConn): seq[MemberModel] =
    db.getAllRows(
        sql"SELECT id, name FROM member"
    )
    .mapIt MemberModel(id: parseint it[0], name: it[1])

proc addMember*(db: DbConn, name: string): int64 =
    db.insertID(
        sql"INSERT INTO member (name) VALUES (?)",
        name
    )

# member ----------------------------------------
