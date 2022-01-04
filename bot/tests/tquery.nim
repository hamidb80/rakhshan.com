import db_sqlite, strutils, sequtils, unittest, options, os, times
import database/[models, queries], telegram/controller

# init
const dbPath = "./play.db"

func toQuestion(t: tuple[quizId: int, description, why: string,
    answer: int]): QuestionModel =
  QuestionModel(
    quiz_id: t[0],
    description: t[1],
    why: t[2],
    answer: t[3]
  )

template id(rawRow): untyped = rawRow[0]

proc pt(s: string): int64 =
  parseTime(s, "yyyy/MM/dd'T'HH:mm:ss", local()).toUnix

let
  membersRaw = [
    (118721, "ali site", "ali tg", "0912",       0,  pt("2021/06/05T08:07:54")),
    (81321257, "mahdi site", "mahdi tg", "0913", 1,  pt("2021/01/05T14:27:43")),
    (98312873, "hamid site", "hamid tg", "0914", 1,  pt("2022/01/02T15:03:11")),
    (53622231, "maher site", "maher tg", "0915", 0,  pt("2020/07/22T23:43:28")),
    (96820231, "Hadi sit", "Emami tg", "0917", 0,  pt("2019/04/20T06:51:41")),
  ]

  tagsRaw = [
    (1, 11, "math", 1),
    (2, 11, "math", 2),
    (3, 11, "math", 4),
    (4, 12, "phyz", 1),
    (5, 10, "phyz", 4),
    (6, 12, "economic", 2),
  ]

  quizzesRaw = [
    (1, "Qz1", "math q for g-11 ch-1", 100, tagsRaw[0].id, pt("2021/06/05T08:07:54"),@[
      (1, "q1 for Qz1", "cuz it's q1 for Qz1", 1),
      (1, "q2 for Qz1", "cuz it's q2 for Qz1", 3),
      (1, "q3 for Qz1", "cuz it's q3 for Qz1", 2),
    ].map toQuestion),
    (2, "Qz2", "math q for g-11 ch-2", 50, tagsRaw[1].id, pt("2021/06/05T08:07:54"), @[
      (2, "q1 for Qz2", "cuz it's q1 for Qz2", 4),
      (2, "q2 for Qz2", "cuz it's q2 for Qz2", 4),
    ].map toQuestion),
    (3, "Qz3", "math q for g-11 ch-4", 20, tagsRaw[2].id, pt("2021/06/05T08:07:54"), @[
      (3, "q1 for Qz3", "cuz it's q1 for Qz3", 3),
      (3, "q2 for Qz3", "cuz it's q2 for Qz3", 2),
      (3, "q3 for Qz3", "cuz it's q3 for Qz3", 1),
      (3, "q4 for Qz3", "cuz it's q4 for Qz3", 4),
      (3, "q5 for Qz3", "cuz it's q5 for Qz3", 1),
    ].map toQuestion),
    (4, "Qz4", "PHYZ q for g-11 ch-1", 80, tagsRaw[3].id, pt("2021/06/05T08:07:54"), @[
      (4, "q1 for Qz4", "cuz it's q1 for Qz4", 3),
      (4, "q2 for Qz4", "cuz it's q2 for Qz4", 2),
      (4, "q3 for Qz4", "cuz it's q3 for Qz4", 1),
      (4, "q4 for Qz4", "cuz it's q4 for Qz4", 4),
    ].map toQuestion),
    (5, "Qz5", "PHYZ q for g-11 ch-1", 30, tagsRaw[4].id, pt("2021/06/05T08:07:54"), @[
      (5, "q1 for Qz5", "cuz it's q1 for Qz5", 1),
      (5, "q2 for Qz5", "cuz it's q2 for Qz5", 1),
      (5, "q3 for Qz5", "cuz it's q3 for Qz5", 2),
      (5, "q4 for Qz5", "cuz it's q4 for Qz5", 2),
      (5, "q5 for Qz5", "cuz it's q5 for Qz5", 2),
      (5, "q6 for Qz5", "cuz it's q6 for Qz5", 2),
      (5, "q7 for Qz5", "cuz it's q7 for Qz5", 4),
    ].map toQuestion),
    (6, "blah blah", "stupid quiz", 120, tagsRaw[5].id, pt("2021/06/05T08:07:54"), @[
      (6, "q1 for Qz6", "cuz it's q1 for Qz", 1),
    ].map toQuestion),
  ]

  recordsRaw = [
    (1, 1, membersRaw[0].id, "012", 25.6, pt("2021/06/05T08:07:54")),
    (2, 1, membersRaw[1].id, "132", 48.5, pt("2021/06/05T08:07:54")),
    (3, 1, membersRaw[2].id, "132", 78.2, pt("2021/06/05T08:07:54")),
    (4, 1, membersRaw[3].id, "132", 12.3, pt("2021/06/05T08:07:54")),
    (5, 1, membersRaw[4].id, "132", 48.5, pt("2021/06/05T08:07:54")),
    (6, 2, membersRaw[1].id, "00", 15.7, pt("2021/06/05T08:07:54")),
    (7, 3, membersRaw[1].id, "21334", 100.0, pt("2021/06/05T08:07:54")),
    (8, 4, membersRaw[2].id, "22", 10.4, pt("2021/06/05T08:07:54")),
    (9, 3, membersRaw[3].id, "22021", 7.8, pt("2021/06/05T08:07:54")),
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
      discard db.addMember(m[0], m[1], m[2], m[3], m[4], m[5])

  test "add tag":
    for t in tagsRaw:
      discard db.addTag(t[1], t[2], t[3])

  test "add quiz":
    for q in quizzesRaw:
      discard db.addQuiz(q[1], q[2], q[3], q[4], q[5], q[6])

  test "add record":
    for r in recordsRaw:
      discard db.addRecord(r[1].int64, r[2].int64, r[3], r[4], r[5])

suite "SELECT":
  test "single member":
    let member = db.getMember(118721).get
    check:
      member.site_name == "ali site"
      member.tg_name == "ali tg"
      member.joined_at == membersRaw[0][5]

  test "single quiz info":
    let r = db.getQuizInfo(quizzesRaw[0].id.int64).get
    check:
      r.quiz.name == "Qz1"
      r.quiz.time == 100
      r.quiz.tagid == 1
      r.quiz.questions_count == 3
      r.quiz.created_at == quizzesRaw[0][5]

  test "get quiz itself with no join":
    let q = db.getQuizItself(4)

    check q.get.name == "Qz4"

  test "find quizzes":
    block by_grade:
      let qs = db.findQuizzes(QuizQuery(grade: some 11), 0, 5, saMore)
      check qs.mapIt(it.quiz.name) == @["Qz1", "Qz2", "Qz3"]

    block by_lesson:
      let qs = db.findQuizzes(QuizQuery(lesson: some "phyz"), 0, 10, saMore)
      check qs.mapIt(it.quiz.name) == @["Qz4", "Qz5"]

    block by_name:
      let qs = db.findQuizzes(QuizQuery(name: some "ah"), int64.high, 10, saLess)
      check qs.mapIt(it.quiz.name) == @["blah blah"]

    block paging:
      let qs = db.findQuizzes(QuizQuery(), 5, 2, saLess)
      check qs.mapIt(it.quiz.id) == @[4'i64, 3]

  test "get questions":
    let qs5 = db.getQuestions(5)
    check:
      qs5.len == 7

  test "get my records":
    let rs1 = db.getMyRecords(membersRaw[1].id, 7, 2, saLess)
    check rs1.mapIt(it.record.percent) == [15.7, 48.5]

    let rs2 = db.getMyRecords(membersRaw[1].id, 6, 1, saMore)
    check rs2.mapIt(it.record.percent) == [100.0]

  test "get record for":
    let res = db.getRecordFor(membersRaw[2].id, 4)
    check:
      res.get.percent == 10.4
      res.get.created_at == recordsRaw[4][5]

  test "get rank":
    let rnk1 = db.getrank(membersRaw[1].id, 1).get
    check rnk1 == 2

    let rnk2 = db.getrank(membersRaw[2].id, 1).get
    check rnk2 == 1

suite "UPSERT":
  test "new tag":
    let
      traw = (10, "chemistery", 2)
      tg = db.upsertTag(traw[0], traw[1], traw[2])

    check:
      tg.grade == traw[0]
      tg.lesson == traw[1]
      tg.chapter == traw[2]

  test "duplicated tag":
    let
      traw = tagsRaw[0]
      tg = db.upsertTag(traw[1], traw[2], traw[3])

    check:
      tg.grade == traw[1]
      tg.lesson == traw[2]
      tg.chapter == traw[3]

    check db.getValue("""
      SELECT COUNT(1) 
      FROM tag 
      WHERE grade = ? AND lesson = ? AND chapter = ?
    """.sql, tg.grade, tg.lesson, tg.chapter).parseint == 1

suite "DELETE":
  test "quiz":
    discard db.deleteQuiz(1)
    check:
      isNone db.getQuizInfo(1) # delete quiz
      db.getQuestions(1).len == 0 # delete question

      db.getMyRecords(membersRaw[1].id, 0, 10, saMore)
        .mapIt(it.quiz.id) == @[2'i64, 3] # delete records
