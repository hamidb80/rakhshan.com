import easydb

var initQuery*: seq[string]

# TODO add timestamp
Blueprint [queryHolder: initQuery, postfix: "Model"]:
    Table member:
        chat_id: int {.primary.}
        site_name: char[255]
        tg_name: char[255]
        phone_number: char[15]
        is_admin: int # fake bool
        joined_at: int

    Table tag:
        id: int {.primary.}
        grade: int {.index.} # 10 | 11 | 12
        lesson: char[120]
        chapter: int

    Table quiz:
        id: int {.primary.}
        tag_id: int[ref tag.id]
        name: char[255]
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
        # TODO questions_order: string # a json array containing ids of questions
        answer_list: char[255] # answer corresponding to 'questions_order'
        percent: float
        created_at: int


func hasPhoto*(q: QuestionModel): bool=
    q.photo_path != ""

when isMainModule:
    import strutils
    writefile "src/database/init.sql", initQuery.join "\n"