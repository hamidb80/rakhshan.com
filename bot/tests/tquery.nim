import db_sqlite, sequtils, strutils
import ./models, ./queries

# init

func toQuestion(t: tuple[quizId: int, description, answer: string,
    ]): QuestionModel =
  QuestionModel(
    quiz_id: t[0],
    description: t[1],
    answer: t[2]
  )

let db = open("./play.db", "", "", "")

for q in initQuery:
  db.exec q.sql

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
  ]

  quizzesRaw = [
    (1, "Qz1", "math q for g-11 ch-1", 100, tagsRaw[0].id, @[
      (1, "q1 for Qz1", "1"),
      (1, "q2 for Qz1", "3"),
      (1, "q3 for Qz1", "2"),
    ].map toQuestion),
    (2, "Qz2", "math q for g-11 ch-1", 120, tagsRaw[1].id, @[
      (2, "q1 for Qz2", "4"),
      (2, "q2 for Qz2", "4"),
    ].map toQuestion),
    (3, "Qz3", "math q for g-11 ch-1", 80, tagsRaw[2].id, @[
      (3, "q1 for Qz3", "3"),
      (3, "q2 for Qz3", "2"),
      (3, "q3 for Qz3", "1"),
      (3, "q4 for Qz3", "4"),
      (3, "q5 for Qz3", "1"),
    ].map toQuestion),
  ]

  recordsRaw = [
    (1, 1, membersRaw[0].id, "012", 25.6),
    (2, 1, membersRaw[1].id, "132", 100.0),
    (3, 2, membersRaw[2].id, "22", 0.0),
    (4, 3, membersRaw[3].id, "22021", 7.8),
  ]


# gen data
for u in membersRaw:
  discard db.addMember(u[0], u[1], u[2], u[3])

for t in tagsRaw:
  discard db.addTag(t[1], t[2], t[3], t[4])

for q in quizzesRaw:
  discard db.addQuiz(q[1], q[2], q[3], q[4], q[5])

for r in recordsRaw:
  discard db.addRecord(r[1].int64, r[2].int64, r[3].mapIt(parseint $it), r[4])
