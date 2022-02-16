
import std/[db_sqlite, strutils, sequtils, unittest, options, os, times, json, algorithm]
import database/[models, queries], controller

# init
const dbPath = "./play.db"

type
  QuestionIR = tuple[quizId: int, description, why: string, answer: int]

func toQuestion(q: QuestionIR): QuestionModel =
  QuestionModel(
    quiz_id: q[0],
    description: q[1],
    why: q[2],
    answer: q[3])

template id(rawRow): untyped = rawRow[0]

proc pt(s: string): int64 =
  parseTime(s, "yyyy/MM/dd'T'HH:mm", local()).toUnix

let
  membersRaw = [
    (118721, "ali site", "ali tg", "0912", 0, pt("2021/06/05T08:07")),
    (81321257, "mahdi site", "mahdi tg", "0913", 1, pt("2021/01/05T14:27")),
    (98312873, "hamid site", "hamid tg", "0914", 1, pt("2022/01/02T15:03")),
    (53622231, "maher site", "maher tg", "0915", 0, pt("2020/07/22T23:43")),
    (96820231, "Hadi sit", "Emami tg", "0917", 0, pt("2019/04/20T06:51")),
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
    (1, "Qz1", "math q for g-11 ch-1", 100,
      tagsRaw[0].id, pt("2021/06/05T08:07"), @[
      (1, "q1 for Qz1", "1 :: q1 for Qz1", 1),
      (2, "q2 for Qz1", "3 :: q2 for Qz1", 3),
      (3, "q3 for Qz1", "2 :: q3 for Qz1", 2),
    ].map toQuestion),
    (2, "Qz2", "math q for g-11 ch-2", 50,
      tagsRaw[1].id, pt("2021/06/05T08:07"), @[
      (4, "q1 for Qz2", "4 :: q1 for Qz2", 4),
      (5, "q2 for Qz2", "4 :: q2 for Qz2", 4),
    ].map toQuestion),
    (3, "Qz3", "math q for g-11 ch-4", 20,
      tagsRaw[2].id, pt("2021/06/05T08:07"), @[
      (6, "q1 for Qz3", "3 :: q1 for Qz3", 3),
      (7, "q2 for Qz3", "2 :: q2 for Qz3", 2),
      (8, "q3 for Qz3", "1 :: q3 for Qz3", 1),
      (9, "q4 for Qz3", "4 :: q4 for Qz3", 4),
      (10, "q5 for Qz3", "1 :: q5 for Qz3", 1),
    ].map toQuestion),
    (4, "Qz4", "PHYZ q for g-11 ch-1", 80,
      tagsRaw[3].id, pt("2021/06/05T08:07"), @[
      (11, "q1 for Qz4", "3 :: q1 for Qz4", 3),
      (12, "q2 for Qz4", "2 :: q2 for Qz4", 2),
      (13, "q3 for Qz4", "1 :: q3 for Qz4", 1),
      (14, "q4 for Qz4", "4 :: q4 for Qz4", 4),
    ].map toQuestion),
    (5, "Qz5", "PHYZ q for g-11 ch-1", 30,
      tagsRaw[4].id, pt("2021/06/05T08:07"), @[
      (15, "q1 for Qz5", "1 :: q1 for Qz5", 1),
      (16, "q2 for Qz5", "1 :: q2 for Qz5", 1),
      (17, "q3 for Qz5", "2 :: q3 for Qz5", 2),
      (18, "q4 for Qz5", "2 :: q4 for Qz5", 2),
      (19, "q5 for Qz5", "2 :: q5 for Qz5", 2),
      (20, "q6 for Qz5", "2 :: q6 for Qz5", 2),
      (21, "q7 for Qz5", "4 :: q7 for Qz5", 4),
    ].map toQuestion),
    (6, "blah blah", "stupid quiz", 120,
      tagsRaw[5].id, pt("2021/06/05T08:07"), @[
      (22, "q1 for Qz6", "1 :: q1 for Qz", 1),
    ].map toQuestion),
  ]

  recordsRaw = [
    (1, 1, membersRaw[0].id, "012", $[1, 2, 3],
      25.6, pt("2021/06/05T08:07")),
    (2, 1, membersRaw[1].id, "132", $[1, 2, 3],
      48.5, pt("2021/06/05T08:07")),
    (3, 1, membersRaw[2].id, "132", $[1, 2, 3],
      78.2, pt("2021/06/05T08:07")),
    (4, 1, membersRaw[3].id, "132", $[1, 2, 3],
      12.3, pt("2021/06/05T08:07")),
    (5, 1, membersRaw[4].id, "132", $[1, 2, 3],
      48.5, pt("2021/06/05T08:07")),
    (6, 2, membersRaw[1].id, "00", $[1, 2],
      15.7, pt("2021/06/05T08:07")),
    (7, 3, membersRaw[1].id, "21334", $[1, 2, 3, 4, 5],
      100.0, pt("2021/06/05T08:07")),
    (8, 4, membersRaw[2].id, "22", $[1, 2],
      10.4, pt("2021/06/05T08:07")),
    (9, 3, membersRaw[3].id, "22021", $[1, 2, 3, 4, 5],
      7.8, pt("2021/06/05T08:07")),
  ]

  plans = [
    (pkConsulting, "c1", "", "desc 1", "http://l1.com/"),
    (pkConsulting, "c2", "", "desc 2", "http://l2.com/"),
    (pkEducational, "c3", "", "desc 1", "http://l3.com/"),
    (pkEducational, "c4", "", "desc 1", "http://l4.com/"),
    (pkEducational, "c5", "", "desc 1", "http://l5.com/"),
  ]

  forms = [
    (fkRegisterInPlans, membersRaw[0][0], some 1'i64, "alizz", "0914",
      11, some "math", none string, pt("2021/06/05T08:07")),
    (fkRegisterInPlans, membersRaw[2][0], some 2'i64, "ajad", "0911",
      10, some "ensani", none string, pt("2021/06/05T08:07")),
    (fkReportProblem, membersRaw[1][0], none int64, "mahdid", "0915",
      8, none string, some "some arbitary complain", pt("2021/06/05T08:07")),
    (fkReportProblem, membersRaw[3][0], none int64, "qawsem", "0917",
      7, none string, some "you're shit", pt("2022/01/05T08:00")),
  ]


if fileExists dbPath:
  removeFile dbPath

let db = open(dbPath, "", "", "")


suite "INIT":
  initDatabase(dbPath)

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
      discard db.addRecord(r[1].int64, r[2].int64, r[3], r[4], r[5], r[6])

  test "add plan":
    for p in plans:
      discard db.addPlan(PlanModel(kind: p[0].ord,
        title: p[1], video_path: p[2], description: p[3], link: p[4]))

  test "add form":
    for f in forms:
      discard db.addForm(FormModel(kind: f[0].ord,
        chatid: f[1], planId: f[2], fullname: f[3],
        phoneNumber: f[4], grade: f[5], major: f[6],
        content: f[7], createdAt: f[8]))

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
      let qs = db.findQuizzes(QuizQuery(grade: some 11), 0, 5, saMore, Descending)
      check qs.mapIt(it.quiz.name) == @["Qz3", "Qz2", "Qz1"]

    block by_lesson:
      let qs = db.findQuizzes(QuizQuery(lesson: some "phyz"), 0, 10, saMore, Descending)
      check qs.mapIt(it.quiz.name) == @["Qz5", "Qz4"]

    block by_name:
      let qs = db.findQuizzes(QuizQuery(name: some "ah"), int64.high, 10,
          saLess, Descending)
      check qs.mapIt(it.quiz.name) == @["blah blah"]

    block paging:
      let qs = db.findQuizzes(QuizQuery(), 5, 2, saLess, Ascending)
      check qs.mapIt(it.quiz.id) == @[3'i64, 4]

  test "get questions":
    let
      qs5 = db.getQuestions(5)
      ids = qs5.mapIt(it.id)

    check:
      qs5.len == 7
      ids == (15'i64 ..< (15+7).int64).toseq

  test "get my records":
    let rs1 = db.getMyRecords(membersRaw[1].id, 7, 2, saLess, Ascending)
    check rs1.mapIt(it.record.percent) == [48.5, 15.7]

    let rs2 = db.getMyRecords(membersRaw[1].id, 6, 1, saMore, Descending)
    check rs2.mapIt(it.record.percent) == [100.0]

  test "get record for":
    let res = db.getRecordFor(membersRaw[2].id, 4)
    check:
      res.get.percent == 10.4
      res.get.created_at == recordsRaw[4][6]

  test "get rank":
    let rnk1 = db.getrank(membersRaw[1].id, 1).get
    check rnk1 == 2

    let rnk2 = db.getrank(membersRaw[2].id, 1).get
    check rnk2 == 1

  test "get plan titles":
    let ts = db.getPlansTitles(pkConsulting)
    check ts == @["c2", "c1"]

  test "get single plan":
    let
      originalPlan = plans[2]
      p = db.getPlan(originalPlan[1])

    check:
      isSome p
      p.get.link == originalPlan[4]

  test "plan exists":
    check:
      db.isPlanExists(plans[0][1])
      not db.isPlanExists("some arbitary title")

  test "get forms":
    check db.getForms(0, 10, saMore, Ascending).mapIt(it.form.content) ==
        forms.mapIt(it[7])

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

  test "new post":
    discard db.upsertPost(PostModel(kind: pokIntroduction.ord))
    check isSome db.getPost(pokIntroduction)

  test "exsiting post":
    discard db.upsertPost(PostModel(kind: pokIntroduction.ord, description: "new desc"))
    let p = db.getPost(pokIntroduction)
    check:
      isSome p
      p.get.description == "new desc"

suite "DELETE":
  test "quiz":
    discard db.deleteQuiz(1)
    check:
      isNone db.getQuizInfo(1) # delete quiz
      db.getQuestions(1).len == 0 # delete question

      db.getMyRecords(membersRaw[1].id, 0, 10, saMore, Descending)
        .mapIt(it.quiz.id) == @[3'i64, 2] # delete records

  test "plan":
    db.deletePlan(plans[0][0], plans[0][1])
    check not db.isPlanExists(plans[0][1])
