import easydb

var query: string

Blueprint [queryHolder: query, postfix: "Model"]:
    Table member:
        id: int {.primary.}
        name: char[255]
        phone_number: char[15]

    Table part:
        id: int {.primary.}
        name: string

    Table quiz:
        id: int {.primary.}
        name: char[255]
        part_id: int[ref part.id]
        
    Table question:
        id: int {.primary.}
        quiz_id: int[ref quiz.id]
        answer: int

    Table record:
        id: int {.primary.}
        member_id: int[ref members.id]
        quiz_id: int[ref quiz.id]
        answer_list: char[255]
        questions_order: string


when isMainModule:
    writefile "src/database/init.sql", query
