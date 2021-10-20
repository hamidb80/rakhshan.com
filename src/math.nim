func getPercent*(userAnswers, correctAnswers: seq[int]): float =
    var
        corrects = 0
        wrongs = 0
        empties = 0 

    for i in 0..userAnswers.high:
        if userAnswers[i] == 0: empties.inc
        elif userAnswers[i] == correctAnswers[i]: corrects.inc
        else: wrongs.inc

    (corrects * 3 - wrongs) / (userAnswers.len * 3)
