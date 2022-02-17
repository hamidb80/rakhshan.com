import std/[db_sqlite {.all.}, sequtils, strutils, options, strformat, algorithm]
import models, ../controller

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
    ortsd: array[SearchDirection, SortOrder] = [Ascending, Descending]

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

proc initDatabase*(path: string) =
    dbworks path:
        for q in initQuery:
            db.exec q.sql

proc getSingleRow*(db;
    query: SqlQuery, args: varargs[string, `$`]
): Option[Row] =
    for r in getAllRows(db, sql(query.string & " LIMIT 1"), args):
        return some r

proc getAllTables*(db; ): seq[string] =
    db.getAllRows(sql"SELECT name FROM sqlite_master WHERE type='table';").mapIt:
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

func `$`(so: SortOrder): string =
    case so:
    of Ascending: "ASC"
    of Descending: "DESC"

func wrapWith(s: string, c: char): string =
    fmt"{c}{s}{c}"

func toNillableString[N: SomeInteger](i: Option[N]): string =
    if issome i: $i.get
    else: ""

func toNillableString(s: string): Option[string] =
    if s == "":
        none string
    else:
        some s

func parseNillableInt(s: string): Option[int64] =
    if s == "": none int64
    else: some parseBiggestInt s

template keepOrder(result, dir, order): untyped =
    if (dir == saMore and order == Descending) or (dir == saLess and order == Ascending):
        result.reverse

# member ----------------------------------------
proc getMember*(db; chatId: int64): Option[MemberModel] =
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
) =
    db.exec(sql"""
        INSERT INTO member (chat_id, site_name, tg_name, phone_number, is_admin, joined_at) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, chatId, site_name.limit(LongStrLimit), tg_name.limit(LongStrLimit),
        phone_number.limit(PhoneNumberLimit), isAdmin, joined_at)

# tag --------------------------------------
proc totag*(s: seq[string]): TagModel =
    TagModel(
        id: s[0].parseint,
        grade: s[1].parseint,
        lesson: s[2],
        chapter: s[3].parseint)

proc addTag*(db;
    grade: int64, lesson: string, chapter: int64
): int64 =
    db.insertID(
        sql"INSERT INTO tag (grade, lesson, chapter) VALUES (?, ?, ?)",
        grade, lesson.limit(LessonNameLimit), chapter)

const getTagQuery = "SELECT id, grade, lesson, chapter FROM tag "

proc getTag(db;
grade: int64, lesson: string, chapter: int64
): Option[TagModel] =
    let row = db.getSingleRow(sql(getTagQuery &
        "WHERE grade = ? AND lesson = ? AND chapter = ?"
    ), grade, lesson, chapter)

    if issome row:
        result = some totag row.get

proc getOrInsertTag*(db;
    grade: int64, lesson: string, chapter: int64
): TagModel =
    let tag = db.getTag(grade, lesson, chapter)

    if issome tag:
        tag.get
    else:
        TagModel(
            id: db.addTag(grade, lesson, chapter),
            grade: grade,
            lesson: lesson,
            chapter: chapter)

# quiz --------------------------------------
proc addQuiz*(db;
    name: string, description: string, time: int64, tag_id: int64,
    created_at: int64, questions: openArray[QuestionModel],
) =
    transaction db:
        let qid = db.insertID(sql"""
            INSERT INTO quiz (name, description, time, tag_id, questions_count, created_at) 
            VALUES (?, ?, ?, ?, ?, ?)
        """, name.limit(LongStrLimit), description, time, tagid, questions.len, created_at)

        for q in questions:
            db.exec(
                sql"INSERT INTO question (quiz_id, photo_path, description, why, answer) VALUES (?, ?, ?, ?, ?)",
                qid, q.photo_path, q.description, q.why, q.answer)

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
    dir: SearchDirection, order: SortOrder
): seq[QuizInfo] =
    var conditions = @[fmt"qid {dop[dir]} {pinnedIndex}"]

    if issome qq.grade:
        conditions.add dbFormat(sql"tgrade = ?", $qq.grade.get)
    if issome qq.lesson:
        conditions.add dbFormat(sql"tlesson LIKE ?", wrapWith(qq.lesson.get, '%'))
    if issome qq.name:
        conditions.add dbFormat(sql"qname LIKE ?", wrapWith(qq.name.get, '%')) # FIXM not used

    let query =
        quizInfoQueryGen(
            if conditions.len == 0: ""
            else: "WHERE " & conditions.join" AND "
            , dir
        ) & fmt"LIMIT {limit}"

    result = db.getAllRows(sql query).map(toQuizInfo)
    result.keepOrder(dir, order)

proc getQuizInfo*(db; quizid: int64): Option[QuizInfo] =
    let row = db.getSingleRow(quizInfoQueryGen("WHERE qid = ?").sql, quizid, quizid)

    if issome row:
        result = some row.get.toQuizInfo

proc getQuizItself*(db; quizid: int64): Option[QuizModel] =
    let row = db.getSingleRow(sql"""
        SELECT name, description, time, tag_id
        FROM quiz
        WHERE id = ?
    """, quizid)

    if issome row:
        result = some QuizModel(
            id: quizid,
            name: row.get[0],
            description: row.get[1],
            time: parseint row.get[2],
            tag_id: parseint row.get[3])

proc getQuestions*(db; quizid: int64): seq[QuestionModel] =
    let rows = db.getAllRows(sql"""
        SELECT id, photo_path, description, why, answer 
        FROM question 
        WHERE quiz_id = ?
        ORDER by id ASC
    """, quizid)

    rows.mapIt QuestionModel(
        id: it[0].parseInt,
        quiz_id: quizid,
        photo_path: it[1],
        description: it[2],
        why: it[3],
        answer: parseint it[4])

proc deleteQuiz*(db; quizid: int64): bool =
    transaction db:
        db.exec(sql"DELETE FROM record WHERE quiz_id = ?", quizid)
        db.exec(sql"DELETE FROM question WHERE quiz_id = ?", quizid)
        db.exec(sql"DELETE FROM quiz WHERE id = ?", quizid)

# record -------------------------------------------
proc addRecord*(db;
    quizId: int64, member_chatId: int64, answers: string,
    questions_order: string, precent: float, created_at: int64,
) =
    db.exec(sql"""
        INSERT INTO record (quiz_id, member_chatid, answer_list, percent, created_at, questions_order) 
        VALUES (?, ?, ?, ?, ?, ?)
    """, quizId, member_chatId, answers.limit(LongStrLimit), precent,
            created_at, questions_order)

proc isRecordExistsFor*(db;
    memberId: int64, quizId: int64
): bool =
    db.getValue(
        sql"SELECT COUNT(id) FROM record WHERE member_chatid = ? AND quiz_id = ?",
        memberid, quizid) != "0"

proc getRecordFor*(db;
    memberId: int64, quizId: int64
): Option[RecordModel] =
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
    dir: SearchDirection, order: SortOrder
): seq[RecordInfo] =
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

    result = rows.mapIt (
        QuizModel(
            id: it[3].parseInt,
            name: it[4],
            description: it[5]),
        RecordModel(
            id: it[0].parseint,
            percent: it[1].parseFloat,
            createdAt: it[2].parseInt,
            quiz_id: it[3].parseint))

    result.keepOrder(dir, order)

proc getRank*(db;
    member_id: int64, quizid: int64,
): Option[int] =
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

# post -------------------------------
proc getPost*(db; kind: PostKinds): Option[PostModel] =
    let t = db.getSingleRow(sql"""
        SELECT kind, video_path, description
        FROM post
        WHERE kind = ?
    """, kind.ord)

    if isSome t:
        result = some PostModel(
            kind: parseint t.get[0],
            video_path: t.get[1],
            description: t.get[2])

proc upsertPost*(db; p: PostModel) =
    db.exec(sql"""
        INSERT INTO post (kind, video_path, description)
        VALUES (?, ?, ?)
        ON CONFLICT(kind) DO UPDATE SET
            video_path = excluded.video_path,
            description = excluded.description
    """, p.kind.ord, p.video_path, p.description)

# plan -------------------------------
proc addPlan*(db; p: PlanModel) =
    db.exec(sql"""
        INSERT INTO plan (kind, title, video_path, description, link) 
        VALUES (?, ?, ?, ?, ?)
    """, p.kind, p.title.limit(LongStrLimit),
    p.videoPath, p.description, p.link)

proc isPlanExists*(db; title: string): bool =
    db.getValue(sql"""
        SELECT COUNT(id) 
        FROM plan
        WHERE is_deleted = 0 AND title = ?
    """, title) == "1"

func toPlan(s: seq[string]): PlanModel =
    PlanModel(id: parseBiggestInt s[0], kind: parseInt s[1], title: s[2],
        video_path: s[3], description: s[4], link: s[5])

proc getPlan*(db; title: string): Option[PlanModel] =
    let t = db.getSingleRow(sql"""
        SELECT id, kind, title, video_path, description, link
        FROM plan
        WHERE is_deleted = 0 AND title = ?
    """, title)

    if issome t:
        result = some toPlan t.get

proc getPlan*(db; id: int64): Option[PlanModel] =
    let t = db.getSingleRow(sql"""
        SELECT id, kind, title, video_path, description, link
        FROM plan
        WHERE AND id = ?
    """, id)

    if issome t:
        result = some toPlan(t.get)

proc getPlansTitles*(db; kind: PlanKinds): seq[string] =
    db.getAllRows(sql"""
        SELECT title FROM plan
        WHERE is_deleted = 0 AND kind = ?
        ORDER BY id DESC
    """, kind.ord).mapIt it[0]

proc deletePlan*(db; kind: PlanKinds, title: string) =
    db.exec(sql"""
        UPDATE plan 
        SET is_deleted = 1
        WHERE kind = ? AND title = ?
    """, kind.ord, title)

# form -------------------------------
proc addForm*(db; f: FormModel) =
    db.exec(sql"""
        INSERT INTO form (
            kind, plan_id, chat_id, created_at,
            full_name, phone_number, grade, major, 
            content
        ) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, f.kind.ord, f.plan_id.toNillableString,
        f.chatid, f.createdAt, f.fullname,
        f.phone_number.limit(PhoneNumberLimit), f.grade, f.major.get(""),
        f.content.get(""))

proc getForms*(db;
    pinnedIndex: int64, limit: int,
    dir: SearchDirection, order: SortOrder
): seq[tuple[form: FormModel, planName: Option[string]]] =
    result =
        db.getAllRows(sql fmt"""
            SELECT 
                f.id, f.kind, f.plan_id, f.chat_id, f.created_at,
                f.full_name, f.phone_number, f.major, f.grade, f.content,
                p.title
            FROM form f
            LEFT JOIN plan p ON f.plan_id = p.id
            WHERE f.id {dop[dir]} {pinnedIndex}
            ORDER BY f.id {ortsd[dir]}
            LIMIT {limit}
        """).mapIt (
            form: FormModel(
                id: parseInt it[0],
                kind: parseInt it[1],
                plan_id: parseNillableInt it[2],
                chat_id: parseInt it[3],
                created_at: parseInt it[4],
                fullname: it[5],
                phone_number: it[6],
                major: toNillableString it[7],
                grade: parseint it[8],
                content: toNillableString(it[9])),

            planName: toNillableString it[10])

    result.keepOrder(dir, order)

# setting ---------------------------
proc getSetting*(db; field: string): Option[string] =
    let t = db.getSingleRow(sql"""
        SELECT value 
        FROM setting 
        WHERE field = ?
    """, field)

    if isSome t:
        result = some t.get[0]

proc putSetting*(db; field, value: string) =
    db.exec(sql"""
        INSERT INTO setting (field, value)
        VALUES(?, ?)
        ON CONFLICT(field) DO UPDATE SET
            value = excluded.value
    """, field, value)
