import strutils
import easydb

var initQuery: seq[string]

Blueprint [queryHolder: initQuery, postfix: "Model"]:
    Table member:
        chat_id: int {.primary.}
        name: char[255]
        phone_number: char[15]
        is_admin: int # fake bool

    Table tag:
        id: int {.primary.}
        name: char[120]
        grade: int {.index.} # 10 | 11 | 12
        lesson: char[60]
        chapter: int

    Table quiz:
        id: int {.primary.}
        tag_id: int[ref tag.id]
        name: char[255]
        description: string
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
        member_chatid: int[ref members.chat_id] {.index.}
        questions_order: string
        answer_list: char[255]
        percent: float


when isMainModule:
    writefile "src/database/init.sql", initQuery.join "\n"

when defined(test):
    export initQuery