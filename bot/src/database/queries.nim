import db_sqlite, sequtils, strutils, options, strformat
import models, ../telegram/controller, ../concurrency

type
    QuizInfo* = tuple
        quiz: QuizModel
        tag: TagModel

    RecordInfo* = tuple
        quiz: QuizModel
        record: RecordModel

    SearchDirection* = enum
        saMore, saLess

const
    # direction operator
    dop: array[SearchDirection, char] = ['>', '<']
    # Order Respected To Search Direction
    ortsd: array[SearchDirection, string] = ["ASC", "DESC"]


using db: DbConn

template dbworks*(path: string, body): untyped =
    let db {.inject.} = open(path, "", "", "")
    body
    db.close()

template dbworksCapture*(path: string, body): untyped =
    block:
        let
            db {.inject.} = open(path, "", "", "")
            result = body

        db.close()
        result

template transaction*(db, body): untyped =
    db.exec sql"BEGIN"
    body
    db.exec sql"COMMIT"

proc getSingleRow*(db;
    query: SqlQuery, args: varargs[string, `$`]
): Option[Row] =
    for r in getAllRows(db, (query.string & " LIMIT 1").sql, args):
        return some r

proc getAllTables*(db; ): seq[string] =
    db.getAllRows("SELECT name FROM sqlite_master WHERE type='table';".sql).mapIt:
        it[0]

template limit(s: string, n: int): untyped =
    s.substr(0, n)

func toInt*(dir: SearchDirection): int =
    case dir:
    of saMore: +1
    of saLess: -1

func `[]`*[T](h: HSlice[T, T], dir: SearchDirection): T =
    case dir:
    of saLess: h.a
    of saMore: h.b


func `~`*(dir: SearchDirection): SearchDirection =
    case dir:
    of saLess: saMore
    of saMore: saLess

# member ----------------------------------------

proc getMember*(db; chatId: int64): Option[MemberModel] {.errorHandler.} =
    let row = db.getSingleRow(sql"""
        SELECT chat_id, site_name, tg_name, phone_number, is_admin, joined_at 
        FROM member 
        WHERE chat_id = ?
        """, chatId)

    if row.issome:
        result = some MemberModel(
            chatid: row.get[0].parseint,
            site_name: row.get[1],
            tg_name: row.get[2],
            phone_number: row.get[3],
            isAdmin: row.get[4].parseInt,
            joinedAt: row.get[5].parseint)

proc addMember*(db;
    chatId: int64, site_name: string, tg_name: string,
    phone_number: string, isAdmin: int, joined_at: int64
): int64 {.errorHandler.} =
    # add site_name + tg_name
    db.insertID(sql"""
        INSERT INTO member (chat_id, site_name, tg_name, phone_number, is_admin, joined_at) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, chatId, site_name.limit(255), tg_name.limit(255),
        phone_number.limit(15), isAdmin, joined_at)

# quiz -------------------------------------------

proc totag*(s: seq[string]): TagModel =
    TagModel(
        id: s[0].parseint,
        grade: s[1].parseint,
        lesson: s[2],
        chapter: s[3].parseint)

proc addTag*(db;
    grade: int64, lesson: string, chapter: int64
): int64 {.errorHandler.} =
    db.insertID(
        sql"INSERT INTO tag (grade, lesson, chapter) VALUES (?, ?, ?)",
        grade, lesson.limit(120), chapter)

const getTagQuery = "SELECT id, grade, lesson, chapter FROM tag "

proc getTag(db;
grade: int64, lesson: string, chapter: int64
): Option[TagModel] {.errorHandler.} =
    let row = db.getSingleRow((getTagQuery &
        "WHERE grade = ? AND lesson = ? AND chapter = ?"
    ).sql, grade, lesson, chapter)

    if issome row:
        result = some totag row.get

proc upsertTag*(db;
    grade: int64, lesson: string, chapter: int64
): TagModel {.errorHandler.} =
    let tag = db.getTag(grade, lesson, chapter)

    if issome tag:
        tag.get
    else:
        TagModel(
            id: db.addTag(grade, lesson, chapter),
            grade: grade,
            lesson: lesson,
            chapter: chapter)

proc addQuiz*(db;
    name: string, description: string, time: int64, tag_id: int64,
    created_at: int64, questions: openArray[QuestionModel],
): int64 {.errorHandler.} =
    transaction db:
        result = db.insertID(sql"""
            INSERT INTO quiz (name, description, time, tag_id, questions_count, created_at) 
            VALUES (?, ?, ?, ?, ?, ?)
        """, name.limit(255), description, time, tagid, questions.len, created_at)

        for q in questions:
            db.exec(
                sql"INSERT INTO question (quiz_id, photo_path, description, why, answer) VALUES (?, ?, ?, ?, ?)",
                result, q.photo_path, q.description, q.why, q.answer)

func quizInfoQueryGen(whereClause: string, dir = saMore): string =
    fmt """
    SELECT 
        quiz.id as qid,
        quiz.name as qname,
        quiz.description,
        quiz.created_at,
        quiz.time,
        tag.id as tid,
        tag.grade as tgrade,
        tag.lesson as tlesson,
        tag.chapter as tchapter,
        quiz.questions_count
    FROM 
        quiz
    INNER JOIN tag
        ON quiz.tag_id = tag.id
    {whereClause} ORDER BY qid {ortsd[dir]}
    """

func toQuizInfo(row: Row): QuizInfo =
    result.quiz = QuizModel(
        id: row[0].parseInt,
        name: row[1],
        description: row[2],
        time: row[4].parseInt,
        tag_id: row[5].parseInt,
        created_at: row[3].parseInt,
        questions_count: parseInt row[^1])

    result.tag = TagModel(
        id: row[5].parseInt,
        grade: row[6].parseInt,
        lesson: row[7],
        chapter: row[8].parseInt)

proc findQuizzes*(db;
    qq: QuizQuery, pinnedIndex: int64, limit: int,
    dir: SearchDirection,
): seq[QuizInfo] {.errorHandler.} =
    var conditions = @[fmt"qid {dop[dir]} {pinnedIndex}"]

    if issome qq.grade:
        conditions.add fmt"tgrade = {qq.grade.get}"
    if issome qq.lesson:
        # TODO security checks
        conditions.add fmt "tlesson = \"{qq.lesson.get}\""
    if issome qq.name:
        # TODO security checks
        conditions.add fmt "qname LIKE \"%{qq.name.get}%\""

    let query =
        quizInfoQueryGen(
            if conditions.len == 0: ""
            else: "WHERE " & conditions.join" AND "
            , dir
        ) & fmt"LIMIT {limit}"

    db.getAllRows(query.sql).map(toQuizInfo)

proc getQuizInfo*(db; quizid: int64): Option[QuizInfo] {.errorHandler.} =
    let row = db.getSingleRow(quizInfoQueryGen("WHERE qid = ?").sql, quizid, quizid)

    if issome row:
        result = some row.get.toQuizInfo

proc getQuizItself*(db; quizid: int64): Option[QuizModel] {.errorHandler.} =
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

proc getQuestions*(db; quizid: int64): seq[QuestionModel] {.errorHandler.} =
    let rows = db.getAllRows("""
        SELECT id, photo_path, description, why, answer 
        FROM question 
        WHERE quiz_id = ?
        ORDER by id ASC
    """.sql, quizid)

    rows.mapIt QuestionModel(
        id: it[0].parseInt,
        quiz_id: quizid,
        photo_path: it[1],
        description: it[2],
        why: it[3],
        answer: parseint it[4])

proc deleteQuiz*(db; quizid: int64): bool {.errorHandler.} =
    transaction db:
        db.exec("DELETE FROM record WHERE quiz_id = ?".sql, quizid)
        db.exec("DELETE FROM question WHERE quiz_id = ?".sql, quizid)
        db.exec("DELETE FROM quiz WHERE id = ?".sql, quizid)

# quiz -------------------------------------------

proc addRecord*(db;
    quizId: int64, member_chatId: int64, answers: string,
    questions_order: string, precent: float, created_at: int64,
): int64 {.errorHandler.} =
    db.insertID(sql"""
        INSERT INTO record (quiz_id, member_chatid, answer_list, percent, created_at, questions_order) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, quizId, member_chatId, answers.limit(255), precent, created_at, questions_order)

proc isRecordExistsFor*(db;
    memberId: int64, quizId: int64
): bool {.errorHandler.} =
    isSome db.getSingleRow(
        sql"SELECT 1 FROM record WHERE member_chatid = ? AND quiz_id = ?",
        memberid, quizid)


proc getRecordFor*(db;
    memberId: int64, quizId: int64
): Option[RecordModel] {.errorHandler.} =
    let row = db.getSingleRow(sql"""
        SELECT id, answer_list, percent, created_at, questions_order
        FROM record
        WHERE member_chatid = ? AND quiz_id = ? 
    """, memberid, quizid)

    if issome row:
        result = some RecordModel(
            id: row.get[0].parseInt,
            quiz_id: quizid,
            member_chatid: memberId,
            answerlist: row.get[1],
            percent: row.get[2].parseFloat,
            createdAt: row.get[3].parseInt,
            questions_order: row.get[4])

proc getMyRecords*(db;
    memberId: int64, pinnedIndex: int64, limit: int,
    dir: SearchDirection
): seq[RecordInfo] {.errorHandler.} =
    let rows = db.getAllRows(sql fmt"""
        SELECT  
            r.id,
            r.percent,
            r.created_at,
            q.id as qid,
            q.name as qname,
            q.description as qinfo
        FROM  record r
        INNER JOIN quiz q 
            ON q.id = r.quiz_id
        WHERE 
            r.member_chatid = ? AND r.id {dop[dir]} ? 
        ORDER BY r.id {ortsd[dir]}
        LIMIT ?
    """, memberid, pinnedIndex, limit)

    rows.mapIt (
        QuizModel(
            id: it[3].parseInt,
            name: it[4],
            description: it[5]),
        RecordModel(
            id: it[0].parseint,
            percent: it[1].parseFloat,
            createdAt: it[2].parseInt,
            quiz_id: it[3].parseint))

proc getRank*(db;
    member_id: int64, quizid: int64,
): Option[int] {.errorHandler.} =
    let rec = db.getSingleRow(sql"""
        SELECT percent
        FROM record r
        WHERE r.quiz_id = ? AND r.member_chatid = ?
    """, quizid, member_id)

    if issome rec:
        let myPercent = rec.get[0].parseFloat

        result = some db.getSingleRow(sql"""
            SELECT COUNT(*)
            FROM record r
            WHERE r.quiz_id = ? AND r.percent - ? > 0.01
        """, quizid, myPercent).get[0].parseint + 1
