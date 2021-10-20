import easydb

var initQuery: string

Blueprint [queryHolder: initQuery, postfix: "Model"]:
    Table member:
        id: int {.primary.}
        name: char[255]
        phone_number: char[15]
        is_admin: int # fake bool
        tg_chat_id: int

    Table part:
        id: int {.primary.}
        name: char[120]
        grade: int # 10 | 11 | 12
        lesson: char[60]
        chapter: int

    Table quiz:
        id: int {.primary.}
        name: char[255]
        part_id: int[ref part.id]
        time: int

    Table question:
        id: int {.primary.}
        quiz_id: int[ref quiz.id]
        photo_path: string
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