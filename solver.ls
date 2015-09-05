
# Board is represented as dictionary keyed by [x, y] coords to
# {
#   possible: '123456789',
#   cols: [],
#   rows: [],
#   node: input node
# }
#
# The .rows and .cols properties are a list of the cell objects defined above
getBoard = ->
  cells = []
  board = {}
  boardNode = document.getElementById('CurrentKakuroBoard')

  # Since we scan the top most row left to right,
  # then the next row, and so on. We can just keep
  # track of the last column total for a particular column
  # and the last row total instead of keeping track of all of them.
  lastColumnTotals = {}
  for rowNode, y in boardNode.getElementsByTagName('tr')
    rowTotal = void

    for cellNode, x in rowNode.getElementsByTagName('td')
      switch cellNode.className 
      case 'cellTotal'
        for totalNode in cellNode.getElementsByTagName('input')
          switch
          case totalNode.name.indexOf('v') != -1
            lastColumnTotals[x] = Number(totalNode.value)
          case totalNode.name.indexOf('h') != -1
            rowTotal = Number(totalNode.value)
          default
            throw new Error "Don't know how to process this board @ #x, #y"

      case 'cellNumber'
        fallthrough
      case 'cellNumberError'
        if rowTotal == void
          throw new Error "Unknown row total @ #x, #y"
        if lastColumnTotals[x] == void
          throw new Error "Unknown column total @ #x, #y"

        row = board[[x - 1, y]]?.row or []
        col = board[[x, y - 1]]?.col or []

        row.total = rowTotal
        col.total = lastColumnTotals[x]

        possible = '123456789'
        if cellNode.children[0].value
          possible = String(cellNode.children[0].value)

        cell = board[[x, y]] =
          possible: possible
          row: row
          col: col
          node: cellNode.children[0]

        row.push(cell)
        col.push(cell)

  board

# Display board
setBoard = (board) ->
  for , cell of board
    cell.node.value = cell.possible

# Save board state for backtracking
saveBoardJson = (board) ->
  board2 = {}
  for coords, cell of board
    board2[coords] = { cell.possible }
  JSON.stringify(board2)

# Load board state for backtracking
loadBoardJson = (board, board2) ->
  for coords, cell of JSON.parse(board2)
    board[coords].possible = cell.possible

# Get related peers of cell
rowPeers = (cell) -> [c for c in cell.row when c != cell]
colPeers = (cell) -> [c for c in cell.col when c != cell]
peers = (cell) -> rowPeers(cell).concat(colPeers(cell))

# Get numbers in all combinations of left numbers that add up to total
getPossible = (total, length, left='123456789') ->
  switch length
  case 0
    return ''
  case 1
    if left.split('').join('.').indexOf(total) == -1
      return ''
    return String(total)

  if left.length == 0
    return ''

  possible = new Set()
  for i in left
    if possible.has(i) then continue

    rest = getPossible(total - i, length - 1, left.replace(i, ''))
    if rest == ''
      continue

    possible.add(i)
    for x in rest then possible.add(x)

  Array.from(possible).join('')

console.assert(getPossible(17, 2) == '89')
console.assert(getPossible(16, 2) == '79')
console.assert(getPossible(10, 4) == '1234')
console.assert(getPossible(7, 3) == '124')
console.assert(getPossible(7, 3) == '124')

# Add up an array of numbers
sum = (.reduce((a, b) -> (a + b), 0))

# Possible values string to binary value
str2bin = (str) ->
  [1 .<<. (Number(i) - 1) for i in str] |> sum

# Binary value to possible values string
bin2str = (binary) ->
  [index for index in [1 to 9] when (binary .&. (1 .<<. (index - 1))) != 0].join('')

# Set functions for possible values
intersection = (possible1, possible2) ->
  bin2str(str2bin(possible1) .&. str2bin(possible2))

console.assert(intersection('123', '345') == '3')
console.assert(intersection('1234', '345') == '34')

difference = (possible1, possible2) ->
  binary2 = str2bin(possible2)
  bin2str((str2bin(possible1) .|. binary2) - binary2)

console.assert(difference('123', '345') == '12')
console.assert(difference('1234', '345') == '12')

# Is cell solved
solved = (cell) ->
  if cell.possible.length == 0
    throw new Error("unsolvable board!")
  cell.possible.length == 1

# Get solved cells of row or column
solvedCells = (.filter solved)

# Get possible numbers for a row or column
getPossible2 = (rowcol) ->
  solvedNums = solvedCells(rowcol).map((c) -> Number(c.possible[0]))
  numsLeft = difference('123456789', solvedNums.join(''))
  getPossible(rowcol.total - sum(solvedNums),
              rowcol.length - solvedNums.length, numsLeft)

# Number of cells solved in board
numSolved = (board) -> [cell for , cell of board when solved(cell)].length

# Cell is assigned value. Check for conflicts
assign = (cell) ->
  if Number(cell.possible) < 1 or Number(cell.possible) > 9
    throw new Error("unsolvable board!")

  if solvedCells(cell.row).length == cell.row.length
    if sum(cell.row.map((c) -> Number(c.possible[0]))) != cell.row.total
      throw new Error("unsolvable board!")

  if solvedCells(cell.col).length == cell.col.length
    if sum(cell.col.map((c) -> Number(c.possible[0]))) != cell.col.total
      throw new Error("unsolvable board!")

# Final solution
solve = (board) !->
  do
    _numSolved = numSolved(board)

    # get possible values per row/col total
    for , cell of board
      if solved(cell) then continue
  
      rowPossible = getPossible2(cell.row)
      colPossible = getPossible2(cell.col)
      possible = intersection(rowPossible, colPossible)
      cell.possible = intersection(cell.possible, possible)
      if solved(cell)
        assign(cell)

      # test through each possible value and see if it invalidates
      # peers in the row or column
      impossible = ''
      possibleCopy = cell.possible
      for possibility in possibleCopy
        cell.possible = possibility
        foundImpossible = false
        newRowPossible = getPossible2(cell.row)
        for rowPeer in rowPeers(cell) when !solved(rowPeer)
          if intersection(rowPeer.possible, newRowPossible) == ''
            impossible += possibility
            foundImpossible = true
            break
        if foundImpossible
           continue
        newColPossible = getPossible2(cell.col)
        for colPeer in colPeers(cell) when !solved(colPeer)
          if intersection(colPeer.possible, newColPossible) == ''
            impossible += possibility
            break

      cell.possible = difference(possibleCopy, impossible)
      if solved(cell)
        assign(cell)
  while numSolved(board) != _numSolved

  # backtracking search
  for , cell of board
    if solved(cell) then continue

    boardJson = saveBoardJson(board)
    possibleCopy = cell.possible
    for possible in possibleCopy
      try
        cell.possible = possible
        assign(cell)
        solve(board)
        while Object.keys(board).length != numSolved(board)
          solve(board)
        break
      catch error
        loadBoardJson(board, boardJson)

    break

  setBoard(board)

solve(getBoard())
