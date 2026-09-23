-- Chess Daily Puzzle Lua Application for CrossPoint Reader
-- Features: Lichess daily puzzle, move validation, opponent reply, hint, reset, sleep screen

local pieces = {}
local json = nil

-- Board state: 64 squares (0 = a1, 7 = h1, 56 = a8, 63 = h8)
local board = {}
local selectedSq = -1
local hintSq = -1
local statusMsg = "Daily Puzzle - Loading..."
local puzzleRating = 1500
local puzzleThemes = "tactics"
local solution = {}
local moveIndex = 1
local isPlayerWhite = true
local isSolved = false
local initialFen = ""

local function initModules()
    if not json then
        local jsonSrc = storage.readFile("json.lua")
        if jsonSrc then
            local chunk = load(jsonSrc)
            if chunk then json = chunk() end
        end
    end
    if not pieces or not pieces["P"] then
        local pSrc = storage.readFile("pieces.lua")
        if pSrc then
            local chunk = load(pSrc)
            if chunk then pieces = chunk() end
        end
    end
end

local function squareToFileRank(sq)
    local f = sq % 8
    local r = math.floor(sq / 8)
    return f, r
end

local function squareToNotation(sq)
    local f, r = squareToFileRank(sq)
    local fileChar = string.char(97 + f)
    local rankChar = string.char(49 + r)
    return fileChar .. rankChar
end

local function notationToSquare(notStr)
    if not notStr or #notStr < 2 then return -1 end
    local f = string.byte(notStr, 1) - 97
    local r = string.byte(notStr, 2) - 49
    if f < 0 or f > 7 or r < 0 or r > 7 then return -1 end
    return r * 8 + f
end

local function clearBoard()
    for i = 0, 63 do
        board[i] = "."
    end
end

local function loadFen(fen)
    clearBoard()
    if not fen then return end
    local parts = {}
    for p in fen:gmatch("%S+") do table.insert(parts, p) end
    local boardPart = parts[1] or ""

    local rank = 7
    local file = 0
    for i = 1, #boardPart do
        local c = boardPart:sub(i, i)
        if c == '/' then
            rank = rank - 1
            file = 0
        elseif c:match("%d") then
            file = file + tonumber(c)
        else
            if file < 8 and rank >= 0 then
                board[rank * 8 + file] = c
                file = file + 1
            end
        end
    end

    -- Determine player turn from FEN active color
    if parts[2] == "b" then
        isPlayerWhite = false
    else
        isPlayerWhite = true
    end
end

local function applyMove(moveStr)
    if not moveStr or #moveStr < 4 then return false end
    local fromSq = notationToSquare(moveStr:sub(1, 2))
    local toSq = notationToSquare(moveStr:sub(3, 4))
    if fromSq < 0 or toSq < 0 then return false end

    local piece = board[fromSq]
    if not piece or piece == "." then return false end

    -- Castling Rook moves
    if piece == "K" and fromSq == 4 then
        if toSq == 6 then
            board[5] = board[7]
            board[7] = "."
        elseif toSq == 2 then
            board[3] = board[0]
            board[0] = "."
        end
    elseif piece == "k" and fromSq == 60 then
        if toSq == 62 then
            board[61] = board[63]
            board[63] = "."
        elseif toSq == 58 then
            board[59] = board[56]
            board[56] = "."
        end
    end

    -- En passant capture
    local fromFile, fromRank = squareToFileRank(fromSq)
    local toFile, toRank = squareToFileRank(toSq)
    if (piece == "P" or piece == "p") and fromFile ~= toFile and board[toSq] == "." then
        if piece == "P" then
            board[toSq - 8] = "."
        else
            board[toSq + 8] = "."
        end
    end

    board[fromSq] = "."

    -- Pawn promotion
    if #moveStr >= 5 then
        local prom = moveStr:sub(5, 5)
        board[toSq] = (piece == piece:upper()) and prom:upper() or prom:lower()
    else
        board[toSq] = piece
    end

    return true
end

local function loadPuzzle()
    initModules()
    local data = storage.readFile("daily.json")
    if not data or not json then
        initialFen = "r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5"
        loadFen(initialFen)
        solution = {"d2d4"}
        moveIndex = 1
        puzzleRating = 1500
        puzzleThemes = "tactics"
        statusMsg = "Sample puzzle loaded. White to move"
        return
    end

    local parsed = json.decode(data)
    if parsed and parsed.puzzle then
        puzzleRating = parsed.puzzle.rating or 1500
        puzzleThemes = (parsed.puzzle.themes and table.concat(parsed.puzzle.themes, ", ")) or "tactics"
        solution = parsed.puzzle.solution or {}
        moveIndex = 1
        isSolved = false

        if parsed.puzzle.fen and parsed.puzzle.fen ~= "" then
            initialFen = parsed.puzzle.fen
        else
            initialFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        end

        loadFen(initialFen)

        if #solution > 0 then
            statusMsg = isPlayerWhite and "White to move - Find the best move!" or "Black to move - Find the best move!"
        else
            statusMsg = "Puzzle loaded - Free play"
        end
    else
        initialFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        loadFen(initialFen)
        statusMsg = "Standard board loaded"
    end
end

local function resetPuzzle()
    if initialFen and initialFen ~= "" then
        loadFen(initialFen)
        moveIndex = 1
        selectedSq = -1
        hintSq = -1
        isSolved = false
        statusMsg = isPlayerWhite and "Puzzle reset. White to move" or "Puzzle reset. Black to move"
        crosspoint.requestUpdate()
    end
end

local function showHint()
    if isSolved or moveIndex > #solution then return end
    local nextMove = solution[moveIndex]
    if nextMove and #nextMove >= 2 then
        hintSq = notationToSquare(nextMove:sub(1, 2))
        statusMsg = "Hint: move the highlighted piece"
        crosspoint.requestUpdate()
    end
end

local function fetchDaily()
    if not crosspoint.isWifiConnected() then
        statusMsg = "Wi-Fi disconnected. Connect in Settings."
        crosspoint.requestUpdate()
        return
    end

    statusMsg = "Downloading daily puzzle..."
    crosspoint.requestUpdate()

    local online = crosspoint.httpGet("https://lichess.org/api/puzzle/daily")
    if online and online ~= "" then
        storage.writeFile("daily.json", online)
        loadPuzzle()
        statusMsg = "New puzzle loaded! " .. (isPlayerWhite and "White" or "Black") .. " to move"
    else
        statusMsg = "Failed to download puzzle"
    end
    crosspoint.requestUpdate()
end

local function toggleSleep()
    local current = crosspoint.getSleepApp()
    if current == "chess" then
        crosspoint.clearSleepApp()
        statusMsg = "Sleep screen: Default"
    else
        crosspoint.setSleepApp("chess")
        statusMsg = "Sleep screen set to Chess!"
    end
    crosspoint.requestUpdate()
end

local function isWhitePiece(p)
    return p ~= nil and p ~= "." and p:match("[PNBRQK]") ~= nil
end

local function isBlackPiece(p)
    return p ~= nil and p ~= "." and p:match("[pnbrqk]") ~= nil
end

local function isOwnPiece(p)
    if isPlayerWhite then
        return isWhitePiece(p)
    else
        return isBlackPiece(p)
    end
end

local function handleSquareSelected(sq)
    if isSolved or sq < 0 or sq > 63 then return end

    local p = board[sq]

    -- Case 1: No piece currently selected
    if selectedSq == -1 then
        if isOwnPiece(p) then
            selectedSq = sq
            hintSq = -1
            crosspoint.requestUpdate()
        end
        return
    end

    -- Case 2: Tapped the already-selected square: deselect
    if sq == selectedSq then
        selectedSq = -1
        crosspoint.requestUpdate()
        return
    end

    -- Case 3: Tapped another piece of own color: switch selection
    if isOwnPiece(p) then
        selectedSq = sq
        hintSq = -1
        crosspoint.requestUpdate()
        return
    end

    -- Case 4: Attempting move from selectedSq to sq
    local uci = squareToNotation(selectedSq) .. squareToNotation(sq)
    local fromP = board[selectedSq]
    local toFile, toRank = squareToFileRank(sq)
    if fromP == "P" and toRank == 7 then uci = uci .. "q" end
    if fromP == "p" and toRank == 0 then uci = uci .. "q" end

    selectedSq = -1

    local expected = solution[moveIndex]
    if expected and uci == expected then
        -- Correct move!
        applyMove(uci)
        moveIndex = moveIndex + 1
        hintSq = -1

        if moveIndex > #solution then
            isSolved = true
            statusMsg = "Puzzle Solved! Excellent!"
        else
            -- Opponent response move
            local oppMove = solution[moveIndex]
            applyMove(oppMove)
            moveIndex = moveIndex + 1

            if moveIndex > #solution then
                isSolved = true
                statusMsg = "Puzzle Solved!"
            else
                statusMsg = "Opponent played " .. oppMove .. ". Your turn!"
            end
        end
    else
        -- Wrong move! DO NOT MOVE PIECE!
        statusMsg = "Not the best move. Try again!"
    end

    crosspoint.requestUpdate()
end

function onEnter()
    loadPuzzle()
end

function onTouch(x, y)
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    -- Button dimensions
    local col1X = 445
    local col2X = 620
    local btnW = 160
    local btnH = 44
    local row1Y = 290
    local row2Y = 346

    -- Hint button
    if x >= col1X and x <= col1X + btnW and y >= row1Y and y <= row1Y + btnH then
        showHint()
        return
    end

    -- Reset button
    if x >= col2X and x <= col2X + btnW and y >= row1Y and y <= row1Y + btnH then
        resetPuzzle()
        return
    end

    -- Update / Sync button
    if x >= col1X and x <= col1X + btnW and y >= row2Y and y <= row2Y + btnH then
        fetchDaily()
        return
    end

    -- Sleep toggle button
    if x >= col2X and x <= col2X + btnW and y >= row2Y and y <= row2Y + btnH then
        toggleSleep()
        return
    end

    -- Chessboard tap detection
    local boardSize = 400
    local boardX = 26
    local boardY = 50
    local sqSize = boardSize / 8
    local flipped = not isPlayerWhite

    if x >= boardX and x < boardX + boardSize and y >= boardY and y < boardY + boardSize then
        local dispFile = math.floor((x - boardX) / sqSize)
        local dispRank = math.floor((y - boardY) / sqSize)
        local file = flipped and (7 - dispFile) or dispFile
        local rank = flipped and dispRank or (7 - dispRank)
        local sq = rank * 8 + file
        handleSquareSelected(sq)
        return
    end
end

function onInput(button, isDown)
    if isDown and button == input.BTN_CONFIRM then
        resetPuzzle()
    end
end

local function drawChessBoard(boardX, boardY, boardSize)
    local sqSize = boardSize / 8
    local pieceOffset = math.floor((sqSize - 40) / 2)
    local flipped = not isPlayerWhite

    -- Outer border
    gfx.drawRect(boardX - 2, boardY - 2, boardSize + 4, boardSize + 4, 2, true)

    for rank = 0, 7 do
        for file = 0, 7 do
            local dispFile = flipped and (7 - file) or file
            local dispRank = flipped and rank or (7 - rank)
            local sqX = boardX + dispFile * sqSize
            local sqY = boardY + dispRank * sqSize
            local sq = rank * 8 + file

            local isDark = ((file + rank) % 2 == 0)
            if isDark then
                gfx.fillRectDither(sqX, sqY, sqSize, sqSize, gfx.COLOR_LIGHT_GRAY)
            else
                gfx.fillRect(sqX, sqY, sqSize, sqSize, false)
            end

            -- Hint highlight
            if sq == hintSq then
                gfx.drawRect(sqX + 2, sqY + 2, sqSize - 4, sqSize - 4, 3, true)
            end

            -- Selection highlight
            if sq == selectedSq then
                gfx.drawRect(sqX + 1, sqY + 1, sqSize - 2, sqSize - 2, 4, true)
            end

            -- Draw piece
            local p = board[sq]
            if p and p ~= "." and pieces[p] then
                gfx.drawSprite(sqX + pieceOffset, sqY + pieceOffset, 40, 40, pieces[p].ink, pieces[p].mask)
            end
        end
    end

    -- Rank labels (1..8) on left side of board
    for r = 0, 7 do
        local dispRank = flipped and r or (7 - r)
        local lbl = tostring(r + 1)
        local ly = boardY + dispRank * sqSize + math.floor((sqSize - gfx.getLineHeight(gfx.FONT_SMALL)) / 2)
        gfx.drawText(gfx.FONT_SMALL, boardX - 16, ly, lbl, true)
    end

    -- File labels (a..h) below board
    for f = 0, 7 do
        local dispFile = flipped and (7 - f) or f
        local lbl = string.char(97 + f)
        local lw = gfx.getTextWidth(gfx.FONT_SMALL, lbl)
        local lx = boardX + dispFile * sqSize + math.floor((sqSize - lw) / 2)
        gfx.drawText(gfx.FONT_SMALL, lx, boardY + boardSize + 4, lbl, true)
    end
end

local function drawButton(x, y, w, h, label, isFilled)
    local lh = gfx.getLineHeight(gfx.FONT_SMALL)
    local lw = gfx.getTextWidth(gfx.FONT_SMALL, label)
    local lx = x + math.floor((w - lw) / 2)
    local ly = y + math.floor((h - lh) / 2)

    if isFilled then
        gfx.fillRoundedRect(x, y, w, h, 6, gfx.COLOR_BLACK)
        gfx.drawText(gfx.FONT_SMALL, lx, ly, label, false)
    else
        gfx.drawRoundedRect(x, y, w, h, 6, 2, true)
        gfx.drawText(gfx.FONT_SMALL, lx, ly, label, true)
    end
end

local function truncateText(font, text, maxW)
    if gfx.getTextWidth(font, text) <= maxW then return text end
    local str = text
    while #str > 3 and gfx.getTextWidth(font, str .. "...") > maxW do
        str = str:sub(1, -2)
    end
    return str .. "..."
end

function onDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    gfx.clearScreen(1)

    -- Top bar (36px high)
    gfx.fillRect(0, 0, w, 36, true)
    local titleText = "Daily Chess Puzzles (Lichess)"
    local th = gfx.getLineHeight(gfx.FONT_UI_10)
    local ty = math.floor((36 - th) / 2)
    gfx.drawText(gfx.FONT_UI_10, 20, ty, titleText, false)

    local turnBadge = isPlayerWhite and "Turn: White" or "Turn: Black"
    local bw = gfx.getTextWidth(gfx.FONT_UI_10, turnBadge)
    gfx.drawText(gfx.FONT_UI_10, w - bw - 20, ty, turnBadge, false)

    -- Draw Board (400x400)
    drawChessBoard(26, 50, 400)

    -- Side info panel
    local panelX = 445
    local panelW = w - panelX - 20

    -- Header
    gfx.drawText(gfx.FONT_UI_12, panelX, 50, "Daily Tactics", true)
    gfx.drawLine(panelX, 86, panelX + panelW, 86, 2, true)

    -- Metadata
    gfx.drawText(gfx.FONT_UI_10, panelX, 98, "Rating: " .. tostring(puzzleRating), true)
    local turnStr = isPlayerWhite and "White to move" or "Black to move"
    local tw = gfx.getTextWidth(gfx.FONT_UI_10, turnStr)
    gfx.drawText(gfx.FONT_UI_10, panelX + panelW - tw, 98, turnStr, true)

    local thmStr = truncateText(gfx.FONT_SMALL, "Themes: " .. puzzleThemes, panelW)
    gfx.drawText(gfx.FONT_SMALL, panelX, 126, thmStr, true)

    -- Status message box
    local boxY = 155
    local boxH = 110
    gfx.drawRoundedRect(panelX, boxY, panelW, boxH, 8, 2, true)
    local msgW = gfx.getTextWidth(gfx.FONT_SMALL, statusMsg)
    local msgH = gfx.getLineHeight(gfx.FONT_SMALL)
    local msgX = math.max(panelX + 8, panelX + math.floor((panelW - msgW) / 2))
    local msgY = boxY + math.floor((boxH - msgH) / 2)
    gfx.drawText(gfx.FONT_SMALL, msgX, msgY, statusMsg, true)

    -- Touch control buttons
    local col1X = 445
    local col2X = 620
    local btnW = 160
    local btnH = 44
    local row1Y = 290
    local row2Y = 346

    drawButton(col1X, row1Y, btnW, btnH, "Hint", false)
    drawButton(col2X, row1Y, btnW, btnH, "Reset", false)
    drawButton(col1X, row2Y, btnW, btnH, "Sync Daily", false)

    local isSleepActive = (crosspoint.getSleepApp() == "chess")
    drawButton(col2X, row2Y, btnW, btnH, isSleepActive and "Sleep: ON" or "Set Sleep", isSleepActive)

    -- Navigation hints at bottom
    gfx.drawText(gfx.FONT_SMALL, panelX, 415, "Tap piece to select, tap target to move.", true)
    gfx.drawText(gfx.FONT_SMALL, panelX, 435, "Use Hint or Reset if you get stuck.", true)
end

function onSleepDraw()
    local w = gfx.getWidth()
    local h = gfx.getHeight()

    initModules()
    loadPuzzle()

    gfx.clearScreen(1)

    -- Top bar (40px high)
    gfx.fillRect(0, 0, w, 40, true)
    local th = gfx.getLineHeight(gfx.FONT_UI_10)
    local ty = math.floor((40 - th) / 2)
    gfx.drawCenteredText(gfx.FONT_UI_10, ty, "DAILY CHESS PUZZLE", false)

    -- Draw board
    drawChessBoard(26, 50, 400)

    -- Sleep information panel
    local panelX = 445
    local panelW = w - panelX - 20

    gfx.drawText(gfx.FONT_UI_12, panelX, 55, "Daily Tactics", true)
    gfx.drawLine(panelX, 90, panelX + panelW, 90, 2, true)

    gfx.drawText(gfx.FONT_UI_10, panelX, 105, "Rating: " .. tostring(puzzleRating), true)
    local turnStr = isPlayerWhite and "White to move" or "Black to move"
    local tw = gfx.getTextWidth(gfx.FONT_UI_10, turnStr)
    gfx.drawText(gfx.FONT_UI_10, panelX + panelW - tw, 105, turnStr, true)

    local thmStr = truncateText(gfx.FONT_SMALL, "Themes: " .. puzzleThemes, panelW)
    gfx.drawText(gfx.FONT_SMALL, panelX, 135, thmStr, true)

    -- Objective Card on side panel
    local cardY = 175
    local cardH = 100
    gfx.drawRoundedRect(panelX, cardY, panelW, cardH, 8, 2, true)

    local function drawPanelCentered(font, y, text, color)
        local tLen = gfx.getTextWidth(font, text)
        local tx = panelX + math.floor((panelW - tLen) / 2)
        gfx.drawText(font, tx, y, text, color)
    end

    drawPanelCentered(gfx.FONT_UI_10, cardY + 22, "Winning Move Sequence", true)
    drawPanelCentered(gfx.FONT_SMALL, cardY + 54, "Solve when device wakes up!", true)

    -- Footer
    drawPanelCentered(gfx.FONT_SMALL, 430, "Press Power to Wake and Play", true)
end
