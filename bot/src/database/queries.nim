import db_sqlite, sequtils, strutils, options, strformat
import models, ../telegram/controller

type
    QuizInfoModel* = tuple
        quiz: QuizModel
        tag: TagModel
        questions_number: int

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
        result = some MemberModel(
            chatid: row.get[0].parseBiggestInt,
            name: row.get[1],
            phone_number: row.get[2],
            isAdmin: row.get[3].parseInt)

proc addMember*(db; chatId: int64, name, phone_number: string, isAdmin: int) =
    discard db.insertID(
        sql"INSERT INTO member (chat_id, name, phone_number, is_admin) VALUES (?, ?, ?, ?)",
        chatId, name, phone_number, isAdmin)

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
        tag.grade as tgrade,
        tag.lesson as tlesson,
        tag.chapter as tchapter,
        (
            SELECT COUNT(*) 
            FROM question
            WHERE quiz_id = {lookfor}
        ) AS qscount
    FROM 
        quiz
    INNER JOIN tag
        ON quiz.tag_id = tag.id
"""

func toQuizInfoModel(row: Row): QuizInfoModel =
    doAssert row.len == 10

    result.quiz = QuizModel(
        id: row[0].parseInt,
        name: row[1],
        description: row[2],
        time: row[3].parseInt,
        tag_id: row[4].parseInt)

    result.tag = TagModel(
        id: row[4].parseInt,
        name: row[5],
        grade: row[6].parseInt,
        lesson: row[7],
        chapter: row[8].parseInt)

    result.questions_number = parseInt row[^1]

proc findQuizzes*(db;
    qq: QuizQuery, pageIndex, pageSize: int
): seq[QuizInfoModel] =
    var conditions: seq[string]

    if issome qq.name:
        # TODO security checks
        conditions.add fmt"qname = %{qq.name.get}%"
    if issome qq.grade:
        conditions.add fmt"tgrade = {qq.grade.get}"
    if issome qq.lesson:
        conditions.add fmt"tlesson = {qq.lesson.get}"

    let query = quizInfoQuery & (
        if conditions.len == 0: ""
        else: "WHERE " & join(conditions, " AND ")
    )

    # TODO add limit & offset
    db.getAllRows(query.sql).map(toQuizInfoModel)

proc getQuizInfo*(db; quizid: int64): Option[QuizInfoModel] =
    let row = db.getSingleRow(
        (quizInfoQuery & "WHERE qid = ?").sql, quizid, quizid)

    if issome row:
        result = some row.get.toQuizInfoModel

proc getQuestions*(db; quizid: int64): seq[QuestionModel] =
    let rows = db.getAllRows(
        "SELECT photo_path, description, answer FROM question WHERE quiz_id = ?".sql,
        quizid)

    rows.mapIt QuestionModel(
        quiz_id: quizid,
        photo_path: it[0],
        description: it[1],
        answer: it[2])

proc deleteQuiz*(db; quizid: int64) =
    transaction db:
        db.exec("DELETE FROM record WHERE quiz_id = ?".sql, quizid)
        db.exec("DELETE FROM question WHERE quiz_id = ?".sql, quizid)
        db.exec("DELETE FROM quiz WHERE id = ?".sql, quizid)

# quiz -------------------------------------------

proc addRecord*(db;
    quizId, member_chatId: int64,
    answers: openArray[int], precent: float
): int64 =
    db.insertID(
        sql"INSERT INTO record (quiz_id, member_chatid, answer_list, percent) VALUES (?, ?, ?, ?)",
        quizId, member_chatId, answers.join, precent)

proc getRecordFor*(db; memberId, quizId: int64): Option[RecordModel] =
    let row = db.getSingleRow(sql"""
        SELECT id, answer_list, precent 
        FROM record 
        WHERE member_chatid = ? AND quiz_id = ? 
    """)

    if issome row:
        result = some RecordModel(
            id: row.get[0].parseInt,
            quiz_id: quizid,
            memberchatid: memberId,
            answerlist: row.get[1],
            percent: row.get[2].parseFloat)

proc getMyRecords*(db;
    memberId: int64, pageIndex, pageSize: int
): seq[tuple[quiz: QuizModel, record: RecordModel]] =
    # TODO add limit and offset
    let rows = db.getAllRows(sql"""
        SELECT  
            r.id,
            r.percent,
            q.id as qid,
            q.name as qname,
            q.description as qinfo
        FROM  record r
        INNER JOIN quiz q 
            ON q.id = r.quiz_id
        WHERE r.member_chatid = ?
    """, memberid)

    rows.mapIt (
        QuizModel(
            id: it[2].parseInt,
            name: it[3],
            description: it[4]),
        RecordModel(
            id: it[0].parseint,
            quiz_id: it[3].parseint,
            percent: it[2].parseFloat))
