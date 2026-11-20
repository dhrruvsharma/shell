import QtQuick

// What a sheet of newsprint (`sheet`, a Newsprint) does to the print on it,
// laid over the print: the ink starved in blotches and pinholes and cracked
// along the creases, the light across the sheet, its creases and its curl,
// and the tape holding it down. Fill the same rect as the sheet. It takes
// no input.
Newsprint {
    property Newsprint sheet: null

    visible: sheet !== null
    pass: 1
    seed: sheet?.seed ?? 1
    paper: sheet?.paper ?? Press.paper
    foldX: sheet?.foldX ?? -1
    foldY: sheet?.foldY ?? -1
    lift: sheet?.lift ?? 0
    liftCorner: sheet?.liftCorner ?? 2
    torn: sheet?.torn ?? Qt.vector4d(0, 0, 0, 0)
    wobble: sheet?.wobble ?? 1
    skew: sheet?.skew ?? 1.5
    tape: sheet?.tape ?? 0
}
