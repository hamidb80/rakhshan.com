import easydb

var initQuery: string

Blueprint [queryHolder: initQuery, postfix: "Model"]:
    Table member:
        id: int {.primary.}
        name: char[255]
        grade: int
        is_admin: bool
        phone_number: char[15]
        tg_chat_id: int

    Table part:
        id: int {.primary.}
        name: char[120]
        lesson: char[60]
        grade: int # 10 | 11 | 12
        chapter: int
        slice: int # -1 means all

    Table quiz:
        id: int {.primary.}
        name: char[255]
        part_id: int[ref part.id]
        time: int

    Table question:
        id: int {.primary.}
        quiz_id: int[ref quiz.id]
        photo_path: Option[string]
        description: string
        answer: char[1] # 1 | 2 | 3 | 4

    Table record:
        id: int {.primary.}
        quiz_id: int[ref quiz.id]
        member_id: int[ref members.id]
        questions_order: string
        answer_list: char[255]


when isMainModule:
    writefile "src/database/init.sql", initQuery

when defined(test):
    export initQuery