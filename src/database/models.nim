import easydb

var query: string

import macros

expandMacros:
    Blueprint [queryHolder: query, postfix: "Model"]:
        Table members:
            id: int {.primary.}
            name: char[255]

        Table part:
            id: int {.primary.}
            name: string

        Table question:
            id: int {.primary.}
            quiz_id: int[ref quiz.id]
            answer: int

        Table quiz:
            id: int {.primary.}
            name: char[255]
            member_id: int[ref members.id]
            part_id: int[ref part.id]

        Table record:
            id: int {.primary.}
            member_id: int[ref members.id]


when isMainModule:
    writefile "src/database/init.sql", query