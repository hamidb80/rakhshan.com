import std/[sqlite3, os]

proc progress(a, b: cint) = discard

proc backupDB*(source, dest: string,
  delay: int = 100, xProgress: proc(a, b: cint) = progress) =
  ## code from: https://www.sqlite.org/backup.html

  var
    pDb: PSqlite3
    pFile: PSqlite3

  doAssert open(source, pDb) == SQLITE_OK
  doAssert open(dest, pFile) == SQLITE_OK

  let pBackup = backup_init(pFile, "main", pDb, "main")
  doAssert pBackup != nil

  while true:
    let r = backup_step(pBackup, 5)

    xProgress(
        backup_remaining(pBackup),
        backup_pagecount(pBackup)
    )

    if r in [SQLITE_OK, SQLITE_BUSY, SQLITE_LOCKED]:
      sleep delay
    else:
      break

  discard backup_finish(pBackup)

  doAssert errcode(pFile) == SQLITE_OK
  discard close(pFile)
