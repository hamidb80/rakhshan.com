import db_sqlite, strutils, sequtils, unittest, options, os, algorithm
import database/[models, queries], telegram/controller

# init
const dbPath = "./play.db"

func toQuestion(t: tuple[quizId: int, description,
    answer: string]): QuestionModel =
  QuestionModel(
    quiz_id: t[0],
    description: t[1],
    answer: t[2]
  )

template id(rawRow): untyped = rawRow[0]

let
  membersRaw = [
    (118721, "ali", "0912", 0),
    (81321257, "mahdi", "0913", 1),
    (98312873, "hamid", "0914", 1),
    (53622231, "maher", "0915", 0),
  ]

  tagsRaw = [
    (1, "Tmath-11-1", 11, "math", 1),
    (2, "Tmath-11-2", 11, "math", 2),
    (3, "Tmath-11-4", 11, "math", 4),
    (4, "Tphyz-12-1", 12, "phyz", 1),
    (5, "Tphyz-10-4", 10, "phyz", 4),
    (6, "Teconomic-12-2", 12, "economic", 2),
  ]

  quizzesRaw = [
    (1, "Qz1", "math q for g-11 ch-1", 100, tagsRaw[0].id, @[
      (1, "q1 for Qz1", "1"),
      (1, "q2 for Qz1", "3"),
      (1, "q3 for Qz1", "2"),
    ].map toQuestion),
    (2, "Qz2", "math q for g-11 ch-2", 120, tagsRaw[1].id, @[
      (2, "q1 for Qz2", "4"),
      (2, "q2 for Qz2", "4"),
    ].map toQuestion),
    (3, "Qz3", "math q for g-11 ch-4", 80, tagsRaw[2].id, @[
      (3, "q1 for Qz3", "3"),
      (3, "q2 for Qz3", "2"),
      (3, "q3 for Qz3", "1"),
      (3, "q4 for Qz3", "4"),
      (3, "q5 for Qz3", "1"),
    ].map toQuestion),
    (4, "Qz4", "PHYZ q for g-11 ch-1", 80, tagsRaw[3].id, @[
      (4, "q1 for Qz4", "3"),
      (4, "q2 for Qz4", "2"),
      (4, "q3 for Qz4", "1"),
      (4, "q4 for Qz4", "4"),
    ].map toQuestion),
    (5, "Qz5", "PHYZ q for g-11 ch-1", 80, tagsRaw[4].id, @[
      (5, "q1 for Qz5", "1"),
      (5, "q2 for Qz5", "1"),
      (5, "q3 for Qz5", "2"),
      (5, "q4 for Qz5", "2"),
      (5, "q5 for Qz5", "2"),
      (5, "q6 for Qz5", "2"),
      (5, "q7 for Qz5", "4"),
    ].map toQuestion),
    (6, "blah blah", "stupid quiz", 120, tagsRaw[5].id, @[
      (6, "q1 for Qz6", "1"),
    ].map toQuestion),
  ]

  recordsRaw = [
    (1, 1, membersRaw[0].id, "012", 25.6),
    (2, 1, membersRaw[1].id, "132", 48.5),
    (3, 2, membersRaw[1].id, "00", 12.4),
    (4, 3, membersRaw[1].id, "21334", 100.0),
    (5, 4, membersRaw[2].id, "22", 10.4),
    (6, 3, membersRaw[3].id, "22021", 7.8),
  ]


if fileExists dbPath:
  removeFile dbPath

let db = open(dbPath, "", "", "")

suite "INIT":
  for q in initQuery:
    db.exec q.sql

  let allTables = initQuery
    .filterit(it.startswith "CREATE TABLE")
    .mapit(it[13..^1].split('(')[0].strip)

  check db.getAllTables() == allTables

suite "INSERT":
  test "add member":
    for m in membersRaw:
      db.addMember(m[0], m[1], m[2], m[3])

  test "add tag":
    for t in tagsRaw:
      discard db.addTag(t[1], t[2], t[3], t[4])

  test "add quiz":
    for q in quizzesRaw:
      discard db.addQuiz(q[1], q[2], q[3], q[4], q[5])

  test "add record":
    for r in recordsRaw:
      discard db.addRecord(r[1].int64, r[2].int64, r[3], r[4])

suite "SELECT":
  test "single member":
    check db.getMember(118721).get.name == "ali"

  test "single quiz info":
    let r = db.getQuizInfo(quizzesRaw[0].id.int64).get
    check:
      r.quiz.name == "Qz1"
      r.quiz.time == 100
      r.quiz.tagid == 1

  test "get quiz itself with no join":
    let q = db.getQuizItself(4)

    check q.get.name == "Qz4"

  test "find quizzes":
    # TODO check multi filter or non filter

    block by_grade:
      let qs = db.findQuizzes(QuizQuery(grade: some 11), 0, 0)
      check qs.mapIt(it.quiz.name).sorted == @["Qz1", "Qz2", "Qz3"]

    block by_lesson:
      let qs = db.findQuizzes(QuizQuery(lesson: some "phyz"), 0, 0)
      check qs.mapIt(it.quiz.name).sorted == @["Qz4", "Qz5"]

    block by_name:
      let qs = db.findQuizzes(QuizQuery(name: some "ah"), 0, 0)
      check qs.mapIt(it.quiz.name).sorted == @["blah blah"]

  test "get questions":
    let qs5 = db.getQuestions(5)
    check:
      qs5.len == 7

  test "get my records":
    let rs = db.getMyRecords(membersRaw[1].id, 0, 0)
    check:
      rs.len == 3
      rs.mapIt(it.record.percent).sorted == [12.4, 48.5, 100.0]

  test "get record for":
    let res = db.getRecordFor(membersRaw[2].id, 4)
    check res.get.percent == 10.4

suite "DELETE":
  test "quiz":
    db.deleteQuiz(1)
    check:
      isNone db.getQuizInfo(1) # delete quiz

      db.getMyRecords(membersRaw[1].id, 0, 0)
        .mapIt(it.quiz.id).sorted == @[2'i64, 3] # delete records

      db.getQuestions(1).len == 0 # delete question
