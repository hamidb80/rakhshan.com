import db_sqlite, sequtils, strutils, options, strformat
import models, ../telegram/controller

type
    QuizInfoModel* = tuple
        quiz: QuizModel
        tag: TagModel
        questions_number: int

using db: DbConn

template dbworks*(path: string, body): untyped =
    let db {.inject.} = open(path, "", "", "")
    body
    db.close()

template dbworksCapture*(path: string, body): untyped =
    let
        db {.inject.} = open(path, "", "", "")
        result = body

    db.close()
    result

template transaction(db, body): untyped =
    db.exec sql"BEGIN"
    body
    db.exec sql"COMMIT"

proc getSingleRow*(db: DbConn, query: SqlQuery, args: varargs[string,
        `$`]): Option[Row] =
    for r in getAllRows(db, (query.string & " LIMIT 1").sql, args):
        return some r

proc getAllTables*(db; ): seq[string] =
    db.getAllRows("SELECT name FROM sqlite_master WHERE type='table';".sql).mapIt:
        it[0]

template limit(s: string, n: int): untyped =
    s.substr(0, n)

# member ----------------------------------------

proc getMember*(db; chatId: int64): Option[MemberModel] =
    let row = db.getSingleRow(
        sql"SELECT chat_id, site_name, tg_name, phone_number, is_admin FROM member WHERE chat_id = ?",
        chatId)

    if row.issome:
        result = some MemberModel(
            chatid: row.get[0].parseBiggestInt,
            site_name: row.get[1],
            tg_name: row.get[2],
            phone_number: row.get[3],
            isAdmin: row.get[4].parseInt)

proc addMember*(db; chatId: int64, site_name, tg_name, phone_number: string,
        isAdmin: int) =
    # add site_name + tg_name
    discard db.insertID(
        sql"INSERT INTO member (chat_id, site_name, tg_name, phone_number, is_admin) VALUES (?, ?, ?, ?, ?)",
        chatId, site_name.limit(255), tg_name.limit(255), phone_number.limit(15), isAdmin)

# quiz -------------------------------------------

proc addTag*(db;
    name: string, grade: int, lesson: string, chapter: int
): int64 =
    db.insertID(
        sql"INSERT INTO tag (name, grade, lesson, chapter) VALUES (?, ?, ?, ?)",
        name.limit(120), grade, lesson.limit(120), chapter)

proc addQuiz*(db;
    name, description: string, time: int, tag_id: int,
    questions: openArray[QuestionModel]
): int64 =
    transaction db:
        result = db.insertID(
            sql"INSERT INTO quiz (name, description, time, tag_id) VALUES (?, ?, ?, ?)",
            name.limit(255), description, time, tagid)

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
            WHERE quiz_id = quiz.id
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

    if issome qq.grade:
        conditions.add fmt"tgrade = {qq.grade.get}"
    if issome qq.lesson:
        # TODO security checks
        conditions.add fmt "tlesson = \"{qq.lesson.get}\""
    if issome qq.name:
        # TODO security checks
        conditions.add fmt "qname LIKE \"%{qq.name.get}%\""

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

proc getQuizItself*(db; quizid: int64): Option[QuizModel] =
    let row = db.getSingleRow("""
        SELECT name, description, time, tag_id
        FROM quiz
        WHERE id = ?
    """.sql, quizid)

    if issome row:
        result = some QuizModel(
            id: quizid,
            name: row.get[0],
            description: row.get[1],
            time: parseint row.get[2],
            tag_id: parseint row.get[3])

proc getQuestions*(db; quizid: int64): seq[QuestionModel] =
    let rows = db.getAllRows(
        "SELECT photo_path, description, answer FROM question WHERE quiz_id = ?".sql,
        quizid)

    rows.mapIt QuestionModel(
        quiz_id: quizid,
        photo_path: it[0],
        description: it[1],
        answer: parseint it[2])

proc deleteQuiz*(db; quizid: int64) =
    transaction db:
        db.exec("DELETE FROM record WHERE quiz_id = ?".sql, quizid)
        db.exec("DELETE FROM question WHERE quiz_id = ?".sql, quizid)
        db.exec("DELETE FROM quiz WHERE id = ?".sql, quizid)

# TODO get quiz by id

# quiz -------------------------------------------

proc addRecord*(db;
    quizId, member_chatId: int64,
    answers: string, precent: float
): int64 =
    db.insertID(
        sql"INSERT INTO record (quiz_id, member_chatid, answer_list, percent) VALUES (?, ?, ?, ?)",
        quizId, member_chatId, answers.limit(255), precent)

proc getRecordFor*(db; memberId, quizId: int64): Option[RecordModel] =
    let row = db.getSingleRow(sql"""
        SELECT id, answer_list, percent 
        FROM record 
        WHERE member_chatid = ? AND quiz_id = ? 
    """, memberid, quizid)

    if issome row:
        result = some RecordModel(
            id: row.get[0].parseInt,
            quiz_id: quizid,
            member_chatid: memberId,
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
            quiz_id: it[2].parseint,
            percent: it[1].parseFloat))
