import db_sqlite, sequtils, strutils, options
import models, ../telegram/controller

type
    QuizSearchModel* = object
        name: string
        grade: int
        lesson: string
        time: int
        questions_number: int

    QuizInfoModel* = tuple
        quiz: QuizModel
        tag: TagModel
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

proc getMember*(db; chatId: int64): Option[MemberModel] =
    let row = db.getRow(
        sql"SELECT chat_id, name, phone_number, is_admin FROM member WHERE chat_id = ?",
        chatId)

    if row.len == 0:
        none MemberModel

    else:
        some MemberModel(
            chatid: row[0].parseBiggestInt,
            name: row[1],
            phone_number: row[2],
            isAdmin: row[3].parseInt
        )

proc addMember*(db;
     chatId: int64, name, phone_number: string, isAdmin: bool,
): MemberModel =
    discard db.insertID(
        sql"INSERT INTO member (chat_id, name, phone_number, is_admin) VALUES (?, ?, ?, ?)",
        chatId, name, phone_number, isAdmin.int)

    get db.getMember chatId

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


proc findQuiz*(db;
    qq: QuizQuery, pageIndex, pageSize: int
): seq[QuizSearchModel] =
    discard

proc getQuizInfo*(db; quizid: int64): QuizInfoModel =
    result

proc getQuestions*(db; quizid: int64): seq[QuestionModel] =
    result

proc deleteQuiz*(db; quizid: int64) =
    # remove quiz + questions + records + part
    transaction(db):
        discard

# quiz -------------------------------------------

proc addRecord*(db;
    quizId, member_chatId: int64,
    precent: float, questionsOrder: seq[int], answers: seq[int]
) =
    discard

proc getRecords*(db;
    memberId: int64, pageIndex, pageSize: int
): seq[RecordInfoModel] =
    result
