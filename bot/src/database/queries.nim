import db_sqlite, sequtils, strutils, options
import models, ../telegram/controller

type
    QuizSearchModel* = object
        name*: string
        grade*: int
        lesson*: string
        time*: int
        questions_number*: int

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
        let db {.inject.} = open(path, "", "", "")
        body
        db.close()

template transaction(db, body): untyped =
    db.exec sql"BEGIN"
    body
    db.exec sql"COMMIT"

proc getSingleRow*(db: DbConn, query: SqlQuery, args: varargs[string,
        `$`]): Option[Row] =
    for r in getAllRows(db, (query.string & " LIMIT 1").sql, args):
        return some r

# member ----------------------------------------

proc getAllTables*(db; ): seq[string] =
    (db.getAllRows "SELECT name FROM sqlite_master WHERE type='table';".sql).mapIt:
        it[0]

proc getMember*(db; chatId: int64): Option[MemberModel] =
    let row = db.getSingleRow(
        sql"SELECT chat_id, name, phone_number, is_admin FROM member WHERE chat_id = ? LIMIT 1",
        chatId)

    if row.issome:
        some MemberModel(
            chatid: row.get[0].parseBiggestInt,
            name: row.get[1],
            phone_number: row.get[2],
            isAdmin: row.get[3].parseInt)

    else:
        none MemberModel

proc addMember*(db;
     chatId: int64, name, phone_number: string, isAdmin: int,
): MemberModel =
    discard db.insertID(
        sql"INSERT INTO member (chat_id, name, phone_number, is_admin) VALUES (?, ?, ?, ?)",
        chatId, name, phone_number, isAdmin)

    get db.getMember chatId

# quiz -------------------------------------------

proc addTag*(db;
    name: string, grade: int, lesson: string, chapter: int
): int64 =
    db.insertID(
        sql"INSERT INTO tag (name, grade, lesson, chapter) VALUES (?, ?, ?, ?)",
        name, grade, lesson, chapter)

proc addQuiz*(db;
    name, description: string, time: int, tag_id: int,
    questions: openArray[QuestionModel]
): int64 =
    transaction db:
        result = db.insertID(
            sql"INSERT INTO quiz (name, description, time, tag_id) VALUES (?, ?, ?, ?)",
            name, description, time, tagid)

        for q in questions:
            db.exec(
                sql"INSERT INTO question (quiz_id, photo_path, description, answer) VALUES (?, ?, ?, ?)",
                result, q.photo_path, q.description, q.answer)

const quizInfoQuery = """
    SELECT 
        quiz.id as qid,
        quiz.name as qname,
        quiz.description,
        quiz.time,
        tag.id as tid,
        tag.name as tname,
        tag.grade,
        tag.lesson,
        tag.chapter,
        (
            SELECT COUNT(*) 
            FROM QUESTION
            WHERE QUIZ_ID = ?
        ) AS qcount
    FROM 
        quiz
    INNER JOIN tag
        ON quiz.tag_id = tag.id
"""

proc findQuizzes*(db;
    qq: QuizQuery, pageIndex, pageSize: int
): seq[QuizSearchModel] =
    discard

proc getQuizInfo*(db; quizid: int64): QuizInfoModel =
    let row = db.getSingleRow(
        (quizInfoQuery & "WHERE qid = ?").sql, quizid, quizid)

    if issome row:
        let tmp = row.get
        result.quiz = QuizModel(
            id: quizid,
            name: tmp[1],
            description: tmp[2],
            time: tmp[3].parseInt,
            tag_id: tmp[4].parseInt)

        result.tag = TagModel(
            id: tmp[4].parseInt,
            name: tmp[5],
            grade: tmp[6].parseInt,
            lesson: tmp[7],
            chapter: tmp[8].parseInt)

        result.questions_number = parseInt tmp[^1]

proc getQuestions*(db; quizid: int64): seq[QuestionModel] =
    let rows = db.getAllRows(
        "SELECT photo_path, description, answer FROM question WHERE quiz_id = ?".sql,
        quizid)

    rows.mapIt:
        QuestionModel(
            quiz_id: quizid,
            photo_path: it[0],
            description: it[1],
            answer: it[2])

proc deleteQuiz*(db; quizid: int64) =
    # remove quiz + questions + records + part
    transaction db:
        discard

# quiz -------------------------------------------

proc addRecord*(db;
    quizId, member_chatId: int64,
    answers: openArray[int], precent: float
): int64 =
    db.insertID(
        sql"INSERT INTO record (quiz_id, member_chatid, answer_list, percent) VALUES (?, ?, ?, ?)",
        quizId, member_chatId, answers.join, precent)

proc getRecords*(db;
    memberId: int64, pageIndex, pageSize: int
): seq[RecordInfoModel] =
    result
