import db_sqlite, sequtils, strutils
import models, ../telegram/controller

type
    QuizSearchModel* = object
        name: string
        grade: int
        lesson: string
        questions_number: int

    QuizInfoModel* = tuple
        quiz: QuizModel
        part: PartModel
        questions_number: int

    RecordInfoModel* = tuple
        record: RecordModel
        quiz: QuizModel

using db: DbConn

template dbworks*(path: string, body): untyped =
    block:
        let db{.inject.} = open(path, "", "", "")
        body
        db.close()

template transaction(db, body): untyped =
    db.exec sql"BEGIN"
    body
    db.exec sql"COMMIT"

# member ----------------------------------------

proc addMember*(db; name: string): int64 =
    db.insertID(
        sql"INSERT INTO member (name) VALUES (?)",
        name)

proc getNember*(db): MemberModel =
    let row = db.getRow(sql"SELECT id, name FROM member")
    MemberModel(id: parseint row[0], name: row[1])

# quiz -------------------------------------------

proc addPart*(db;
    name: string, grade: int, lesson: string, chapter: int
): int64 =
    db.insertID(
        sql"INSERT INTO part (name, grade, lesson, chapter) VALUES (?, ?, ?, ?)",
        name, grade, lesson, chapter)

proc addQuiz*(db;
    name, description: string, time: int, part_id: int,
    questions: seq[QuestionModel]
): int64 =

    transaction(db):
        let quizId = db.insertID(
            sql"INSERT INTO quiz (name, description, time, part_id) VALUES (?, ?, ?, ?)",
            name, description, time, partid)

        for q in questions:
            db.exec(
                sql"INSERT INTO question (quiz_id, photo_path, description, answer) VALUES (?, ?, ?, ?)",
                quizId, q.photo_path, q.description, q.answer)

    quizid


proc findQuiz*(db; qq: QuizQuery, pageIndex, pageSize: int): seq[
        QuizSearchModel] =
    discard

proc getQuizInfo*(db): QuizInfoModel =
    result

proc getQuestions*(db): seq[QuestionModel] =
    result

proc deleteQuiz*(db) =
    # remove quiz + questions + records + part
    transaction(db):
        discard

# quiz -------------------------------------------

proc addRecord*(db; quizId, memberId: int64,
    precent: float, questionsOrder: seq[int], answers: seq[int]
) =
    discard

proc getRecords*(db; memberId: int64, pageIndex, pageSize: int
): seq[RecordInfoModel] =
    result
