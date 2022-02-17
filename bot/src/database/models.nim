import easydb

var initQuery*: seq[string]

const
    LongStrLimit* = 300
    ShortStrLimit* = 60
    LessonNameLimit* = 120
    PhoneNumberLimit* = 15

Blueprint [queryHolder: initQuery, postfix: "Model"]:
    Table member:
        chat_id: int {.primary.}
        site_name: char[300]
        tg_name: char[300]
        phone_number: char[15]
        is_admin: int {.index.}
        joined_at: int

    Table tag:
        id: int {.primary.}
        grade: int {.index.} # 10 | 11 | 12
        lesson: char[120]
        chapter: int

    Table quiz:
        id: int {.primary.}
        tag_id: int[ref tag.id]
        name: char[300]
        description: string
        time: int
        questions_count: int
        created_at: int

    Table question:
        id: int {.primary.}
        quiz_id: int[ref quiz.id]
        photo_path: string
        description: string
        why: string
        answer: int

    Table record:
        id: int {.primary.}
        quiz_id: int[ref quiz.id]
        member_chatid: int[ref members.chat_id] {.index.}
        questions_order: string # a json array containing ids of questions
        answer_list: char[300] # answer corresponding to 'questions_order'
        percent: float
        created_at: int

        Index [quiz_id, percent] as "rank"

    Table post:
        kind: int {.primary.}
        video_path: string
        description: string

    Table plan:
        id: int {.primary.}
        kind: int
        title: string[300]
        video_path: string
        description: string
        link: string
        is_deleted: int {.index, default: 0.}

    Table form:
        id: int {.primary.}
        kind: int
        chat_id: int
        plan_id: Option[int[ref plan.id]]
        full_name: string[300]
        phone_number: string[15]
        grade: int
        major: Option[string[60]]
        content: Option[string]
        created_at: int

    Table setting:
        field: string {.primary.}
        value: string

type
    PlanKinds* = enum
        pkConsulting
        pkEducational

    FormKinds* = enum
        fkRegisterInPlans
        fkReportProblem

    PostKinds* = enum
        pokIntroduction

    SettingFieldKinds* = enum
        sfkDefaultQuestionPhoto


func hasPhoto*(q: QuestionModel): bool =
    q.photo_path != ""

# -------------------------

when isMainModule:
    import strutils
    writefile "src/database/init.sql", initQuery.join "\n"
