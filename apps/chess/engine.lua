-- Chess Engine for CrossPoint Apps (Pure Lua)
-- Full legal move generation, castling, en passant, promotion, check/checkmate/stalemate,
-- Piece-Square Tables (PST), Alpha-Beta Minimax search with configurable difficulty.

local Engine = {}

-- Square indices: 0 = a1, 7 = h1, 56 = a8, 63 = h8
-- Files: 0..7 (a..h), Ranks: 0..7 (1..8)
-- Pieces: "P", "N", "B", "R", "Q", "K" (White); "p", "n", "b", "r", "q", "k" (Black); "." (Empty)

local PIECE_VALUES = {
    P = 100, N = 320, B = 330, R = 500, Q = 900, K = 20000,
    p = 100, n = 320, b = 330, r = 500, q = 900, k = 20000
}

-- Piece-Square Tables (from White's perspective, index 0 = a1)
-- Higher value = better square for White piece
local PST_PAWN = {
      0,   0,   0,   0,   0,   0,   0,   0,
      5,  10,  10, -20, -20,  10,  10,   5,
      5,  -5, -10,   0,   0, -10,  -5,   5,
      0,   0,   0,  20,  20,   0,   0,   0,
      5,   5,  10,  25,  25,  10,   5,   5,
     10,  10,  20,  30,  30,  20,  10,  10,
     50,  50,  50,  50,  50,  50,  50,  50,
      0,   0,   0,   0,   0,   0,   0,   0
}

local PST_KNIGHT = {
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20,   0,   5,   5,   0, -20, -40,
    -30,   5,  10,  15,  15,  10,   5, -30,
    -30,   0,  15,  20,  20,  15,   0, -30,
    -30,   5,  15,  20,  20,  15,   5, -30,
    -30,   0,  10,  15,  15,  10,   0, -30,
    -40, -20,   0,   0,   0,   0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50
}

local PST_BISHOP = {
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10,   5,   0,   0,   0,   0,   5, -10,
    -10,  10,  10,  10,  10,  10,  10, -10,
    -10,   0,  10,  10,  10,  10,   0, -10,
    -10,   5,   5,  10,  10,   5,   5, -10,
    -10,   0,   5,  10,  10,   5,   0, -10,
    -10,   0,   0,   0,   0,   0,   0, -10,
    -20, -10, -10, -10, -10, -10, -10, -20
}

local PST_ROOK = {
      0,   0,   0,   5,   5,   0,   0,   0,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
     -5,   0,   0,   0,   0,   0,   0,  -5,
      5,  10,  10,  10,  10,  10,  10,   5,
      0,   0,   0,   0,   0,   0,   0,   0
}

local PST_QUEEN = {
    -20, -10, -10,  -5,  -5, -10, -10, -20,
    -10,   0,   5,   0,   0,   0,   0, -10,
    -10,   5,   5,   5,   5,   5,   0, -10,
      0,   0,   5,   5,   5,   5,   0,  -5,
     -5,   0,   5,   5,   5,   5,   0,  -5,
    -10,   0,   5,   5,   5,   5,   0, -10,
    -10,   0,   0,   0,   0,   0,   0, -10,
    -20, -10, -10,  -5,  -5, -10, -10, -20
}

local PST_KING_MID = {
     20,  30,  10,   0,   0,  10,  30,  20,
     20,  20,   0,   0,   0,   0,  20,  20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30
}

local PST = {
    P = PST_PAWN, N = PST_KNIGHT, B = PST_BISHOP, R = PST_ROOK, Q = PST_QUEEN, K = PST_KING_MID,
    p = PST_PAWN, n = PST_KNIGHT, b = PST_BISHOP, r = PST_ROOK, q = PST_QUEEN, k = PST_KING_MID
}

-- Directional tables & attack offsets pre-allocated once to eliminate heap/PSRAM churn
local KNIGHT_ATTACK_OFFSETS = {-17, -15, -10, -6, 6, 10, 15, 17}
local KNIGHT_OFFSETS = {{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2}, {1, -2}, {1, 2}, {2, -1}, {2, 1}}
local ORTH_DIRS = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
local DIAG_DIRS = {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}
local QUEEN_DIRS = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}}

local IS_WHITE_PIECE = { P = true, N = true, B = true, R = true, Q = true, K = true }
local IS_BLACK_PIECE = { p = true, n = true, b = true, r = true, q = true, k = true }

function Engine.squareToFileRank(sq)
    local f = sq % 8
    local r = math.floor(sq / 8)
    return f, r
end

function Engine.squareToNotation(sq)
    local f, r = Engine.squareToFileRank(sq)
    return string.char(97 + f) .. string.char(49 + r)
end

function Engine.notationToSquare(notStr)
    if not notStr or #notStr < 2 then return -1 end
    local f = string.byte(notStr, 1) - 97
    local r = string.byte(notStr, 2) - 49
    if f < 0 or f > 7 or r < 0 or r > 7 then return -1 end
    return r * 8 + f
end

function Engine.moveToUci(m)
    local s = Engine.squareToNotation(m.from) .. Engine.squareToNotation(m.to)
    if m.promo then
        s = s .. m.promo:lower()
    end
    return s
end

function Engine.uciToMove(str)
    if not str or #str < 4 then return nil end
    local fromSq = Engine.notationToSquare(str:sub(1, 2))
    local toSq = Engine.notationToSquare(str:sub(3, 4))
    local promo = #str >= 5 and str:sub(5, 5):lower() or nil
    return {from = fromSq, to = toSq, promo = promo}
end

function Engine.isWhitePiece(p)
    return IS_WHITE_PIECE[p] == true
end

function Engine.isBlackPiece(p)
    return IS_BLACK_PIECE[p] == true
end

function Engine.isColorPiece(p, color)
    if color == "w" then return IS_WHITE_PIECE[p] == true end
    if color == "b" then return IS_BLACK_PIECE[p] == true end
    return false
end

function Engine.newGame(fen)
    local game = {
        board = {},
        turn = "w",
        castling = {K = true, Q = true, k = true, q = true},
        ep = -1,
        halfmove = 0,
        fullmove = 1,
        history = {}
    }
    for i = 0, 63 do game.board[i] = "." end
    Engine.loadFen(game, fen or "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    return game
end

function Engine.loadFen(game, fen)
    for i = 0, 63 do game.board[i] = "." end
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
                game.board[rank * 8 + file] = c
                file = file + 1
            end
        end
    end

    game.turn = parts[2] == "b" and "b" or "w"

    game.castling = {K = false, Q = false, k = false, q = false}
    local castlingPart = parts[3] or "-"
    if castlingPart:find("K") then game.castling.K = true end
    if castlingPart:find("Q") then game.castling.Q = true end
    if castlingPart:find("k") then game.castling.k = true end
    if castlingPart:find("q") then game.castling.q = true end

    local epPart = parts[4] or "-"
    if epPart ~= "-" then
        game.ep = Engine.notationToSquare(epPart)
    else
        game.ep = -1
    end

    game.halfmove = tonumber(parts[5]) or 0
    game.fullmove = tonumber(parts[6]) or 1
    game.history = {}
end

function Engine.toFen(game)
    local fen = ""
    for r = 7, 0, -1 do
        local empty = 0
        for f = 0, 7 do
            local p = game.board[r * 8 + f]
            if p == "." then
                empty = empty + 1
            else
                if empty > 0 then
                    fen = fen .. empty
                    empty = 0
                end
                fen = fen .. p
            end
        end
        if empty > 0 then fen = fen .. empty end
        if r > 0 then fen = fen .. "/" end
    end

    fen = fen .. " " .. game.turn .. " "

    local cStr = ""
    if game.castling.K then cStr = cStr .. "K" end
    if game.castling.Q then cStr = cStr .. "Q" end
    if game.castling.k then cStr = cStr .. "k" end
    if game.castling.q then cStr = cStr .. "q" end
    if cStr == "" then cStr = "-" end
    fen = fen .. cStr .. " "

    if game.ep and game.ep >= 0 then
        fen = fen .. Engine.squareToNotation(game.ep)
    else
        fen = fen .. "-"
    end

    fen = fen .. " " .. tostring(game.halfmove) .. " " .. tostring(game.fullmove)
    return fen
end

-- Square attack check
function Engine.isSquareAttacked(board, sq, attackerColor)
    local f, r = Engine.squareToFileRank(sq)

    -- 1. Pawn attacks
    if attackerColor == "w" then
        if r > 0 then
            if f > 0 and board[(r - 1) * 8 + (f - 1)] == "P" then return true end
            if f < 7 and board[(r - 1) * 8 + (f + 1)] == "P" then return true end
        end
    else
        if r < 7 then
            if f > 0 and board[(r + 1) * 8 + (f - 1)] == "p" then return true end
            if f < 7 and board[(r + 1) * 8 + (f + 1)] == "p" then return true end
        end
    end

    -- 2. Knight attacks
    local knightChar = attackerColor == "w" and "N" or "n"
    for _, off in ipairs(KNIGHT_ATTACK_OFFSETS) do
        local target = sq + off
        if target >= 0 and target <= 63 then
            local tf, tr = Engine.squareToFileRank(target)
            if math.abs(tf - f) <= 2 and math.abs(tr - r) <= 2 and board[target] == knightChar then
                return true
            end
        end
    end

    -- 3. King attacks (adjacent king)
    local kingChar = attackerColor == "w" and "K" or "k"
    for df = -1, 1 do
        for dr = -1, 1 do
            if df ~= 0 or dr ~= 0 then
                local tf = f + df
                local tr = r + dr
                if tf >= 0 and tf <= 7 and tr >= 0 and tr <= 7 then
                    if board[tr * 8 + tf] == kingChar then return true end
                end
            end
        end
    end

    -- 4. Sliding pieces: Orthogonal (Rook / Queen)
    local rookChar = attackerColor == "w" and "R" or "r"
    local queenChar = attackerColor == "w" and "Q" or "q"
    for _, d in ipairs(ORTH_DIRS) do
        local df, dr = d[1], d[2]
        local tf, tr = f + df, r + dr
        while tf >= 0 and tf <= 7 and tr >= 0 and tr <= 7 do
            local p = board[tr * 8 + tf]
            if p ~= "." then
                if p == rookChar or p == queenChar then return true end
                break
            end
            tf, tr = tf + df, tr + dr
        end
    end

    -- 5. Sliding pieces: Diagonal (Bishop / Queen)
    local bishopChar = attackerColor == "w" and "B" or "b"
    for _, d in ipairs(DIAG_DIRS) do
        local df, dr = d[1], d[2]
        local tf, tr = f + df, r + dr
        while tf >= 0 and tf <= 7 and tr >= 0 and tr <= 7 do
            local p = board[tr * 8 + tf]
            if p ~= "." then
                if p == bishopChar or p == queenChar then return true end
                break
            end
            tf, tr = tf + df, tr + dr
        end
    end

    return false
end

function Engine.findKing(board, color)
    local target = color == "w" and "K" or "k"
    for i = 0, 63 do
        if board[i] == target then return i end
    end
    return -1
end

function Engine.isInCheck(board, color)
    local kingSq = Engine.findKing(board, color)
    if kingSq < 0 then return false end
    local attackerColor = color == "w" and "b" or "w"
    return Engine.isSquareAttacked(board, kingSq, attackerColor)
end

-- Generate pseudo-legal moves for a piece on sq
local function generatePieceMoves(game, sq, moves)
    local p = game.board[sq]
    if p == "." then return end
    local isWhite = Engine.isWhitePiece(p)
    local f, r = Engine.squareToFileRank(sq)

    if p == "P" then
        -- White pawn forward
        local fwd = sq + 8
        if fwd <= 63 and game.board[fwd] == "." then
            if r == 6 then
                -- Promotion
                table.insert(moves, {from = sq, to = fwd, promo = "q"})
                table.insert(moves, {from = sq, to = fwd, promo = "r"})
                table.insert(moves, {from = sq, to = fwd, promo = "b"})
                table.insert(moves, {from = sq, to = fwd, promo = "n"})
            else
                table.insert(moves, {from = sq, to = fwd})
                if r == 1 and game.board[sq + 16] == "." then
                    table.insert(moves, {from = sq, to = sq + 16})
                end
            end
        end
        -- White pawn captures
        for df = -1, 1, 2 do
            local tf = f + df
            if tf >= 0 and tf <= 7 and r < 7 then
                local target = (r + 1) * 8 + tf
                if Engine.isBlackPiece(game.board[target]) then
                    if r == 6 then
                        table.insert(moves, {from = sq, to = target, promo = "q"})
                        table.insert(moves, {from = sq, to = target, promo = "r"})
                        table.insert(moves, {from = sq, to = target, promo = "b"})
                        table.insert(moves, {from = sq, to = target, promo = "n"})
                    else
                        table.insert(moves, {from = sq, to = target})
                    end
                elseif target == game.ep and target >= 0 then
                    -- En passant
                    table.insert(moves, {from = sq, to = target, isEp = true})
                end
            end
        end

    elseif p == "p" then
        -- Black pawn forward
        local fwd = sq - 8
        if fwd >= 0 and game.board[fwd] == "." then
            if r == 1 then
                -- Promotion
                table.insert(moves, {from = sq, to = fwd, promo = "q"})
                table.insert(moves, {from = sq, to = fwd, promo = "r"})
                table.insert(moves, {from = sq, to = fwd, promo = "b"})
                table.insert(moves, {from = sq, to = fwd, promo = "n"})
            else
                table.insert(moves, {from = sq, to = fwd})
                if r == 6 and game.board[sq - 16] == "." then
                    table.insert(moves, {from = sq, to = sq - 16})
                end
            end
        end
        -- Black pawn captures
        for df = -1, 1, 2 do
            local tf = f + df
            if tf >= 0 and tf <= 7 and r > 0 then
                local target = (r - 1) * 8 + tf
                if Engine.isWhitePiece(game.board[target]) then
                    if r == 1 then
                        table.insert(moves, {from = sq, to = target, promo = "q"})
                        table.insert(moves, {from = sq, to = target, promo = "r"})
                        table.insert(moves, {from = sq, to = target, promo = "b"})
                        table.insert(moves, {from = sq, to = target, promo = "n"})
                    else
                        table.insert(moves, {from = sq, to = target})
                    end
                elseif target == game.ep and target >= 0 then
                    -- En passant
                    table.insert(moves, {from = sq, to = target, isEp = true})
                end
            end
        end

    elseif p == "N" or p == "n" then
        for _, d in ipairs(KNIGHT_OFFSETS) do
            local tf = f + d[1]
            local tr = r + d[2]
            if tf >= 0 and tf <= 7 and tr >= 0 and tr <= 7 then
                local target = tr * 8 + tf
                local tp = game.board[target]
                if tp == "." or (isWhite and Engine.isBlackPiece(tp)) or (not isWhite and Engine.isWhitePiece(tp)) then
                    table.insert(moves, {from = sq, to = target})
                end
            end
        end

    elseif p == "B" or p == "b" or p == "R" or p == "r" or p == "Q" or p == "q" then
        local dirs
        if p == "B" or p == "b" then
            dirs = DIAG_DIRS
        elseif p == "R" or p == "r" then
            dirs = ORTH_DIRS
        else
            dirs = QUEEN_DIRS
        end
        for _, d in ipairs(dirs) do
            local df, dr = d[1], d[2]
            local tf, tr = f + df, r + dr
            while tf >= 0 and tf <= 7 and tr >= 0 and tr <= 7 do
                local target = tr * 8 + tf
                local tp = game.board[target]
                if tp == "." then
                    table.insert(moves, {from = sq, to = target})
                else
                    if (isWhite and Engine.isBlackPiece(tp)) or (not isWhite and Engine.isWhitePiece(tp)) then
                        table.insert(moves, {from = sq, to = target})
                    end
                    break
                end
                tf, tr = tf + df, tr + dr
            end
        end

    elseif p == "K" or p == "k" then
        for df = -1, 1 do
            for dr = -1, 1 do
                if df ~= 0 or dr ~= 0 then
                    local tf = f + df
                    local tr = r + dr
                    if tf >= 0 and tf <= 7 and tr >= 0 and tr <= 7 then
                        local target = tr * 8 + tf
                        local tp = game.board[target]
                        if tp == "." or (isWhite and Engine.isBlackPiece(tp)) or (not isWhite and Engine.isWhitePiece(tp)) then
                            table.insert(moves, {from = sq, to = target})
                        end
                    end
                end
            end
        end

        -- Castling
        if isWhite and sq == 4 and not Engine.isInCheck(game.board, "w") then
            -- Kingside: e1 -> g1 (squares 5, 6 empty and not attacked)
            if game.castling.K and game.board[5] == "." and game.board[6] == "." and game.board[7] == "R" then
                if not Engine.isSquareAttacked(game.board, 5, "b") and not Engine.isSquareAttacked(game.board, 6, "b") then
                    table.insert(moves, {from = 4, to = 6, isCastle = "K"})
                end
            end
            -- Queenside: e1 -> c1 (squares 1, 2, 3 empty, 2, 3 not attacked)
            if game.castling.Q and game.board[1] == "." and game.board[2] == "." and game.board[3] == "." and game.board[0] == "R" then
                if not Engine.isSquareAttacked(game.board, 2, "b") and not Engine.isSquareAttacked(game.board, 3, "b") then
                    table.insert(moves, {from = 4, to = 2, isCastle = "Q"})
                end
            end
        elseif not isWhite and sq == 60 and not Engine.isInCheck(game.board, "b") then
            -- Kingside: e8 -> g8 (squares 61, 62 empty and not attacked)
            if game.castling.k and game.board[61] == "." and game.board[62] == "." and game.board[63] == "r" then
                if not Engine.isSquareAttacked(game.board, 61, "w") and not Engine.isSquareAttacked(game.board, 62, "w") then
                    table.insert(moves, {from = 60, to = 62, isCastle = "k"})
                end
            end
            -- Queenside: e8 -> c8 (squares 57, 58, 59 empty, 58, 59 not attacked)
            if game.castling.q and game.board[57] == "." and game.board[58] == "." and game.board[59] == "." and game.board[56] == "r" then
                if not Engine.isSquareAttacked(game.board, 58, "w") and not Engine.isSquareAttacked(game.board, 59, "w") then
                    table.insert(moves, {from = 60, to = 58, isCastle = "q"})
                end
            end
        end
    end
end

-- Make move (internal, returns undo state)
local function applyMoveInternal(game, m, undo)
    local fromSq, toSq = m.from, m.to
    local piece = game.board[fromSq]
    local captured = game.board[toSq]
    local isWhite = Engine.isWhitePiece(piece)

    if not undo then
        undo = {}
    end
    undo.from = fromSq
    undo.to = toSq
    undo.piece = piece
    undo.captured = captured
    undo.castlingK = game.castling.K
    undo.castlingQ = game.castling.Q
    undo.castlingk = game.castling.k
    undo.castlingq = game.castling.q
    undo.ep = game.ep
    undo.halfmove = game.halfmove
    undo.isCastle = m.isCastle
    undo.isEp = m.isEp
    undo.promo = m.promo
    undo.epCapturedSq = -1
    undo.epCapturedPiece = nil

    -- Clear from square
    game.board[fromSq] = "."

    -- En passant capture
    if m.isEp then
        local epCap = isWhite and (toSq - 8) or (toSq + 8)
        undo.epCapturedSq = epCap
        undo.epCapturedPiece = game.board[epCap]
        game.board[epCap] = "."
    end

    -- Castling rook movement
    if m.isCastle == "K" then
        game.board[5] = game.board[7]
        game.board[7] = "."
    elseif m.isCastle == "Q" then
        game.board[3] = game.board[0]
        game.board[0] = "."
    elseif m.isCastle == "k" then
        game.board[61] = game.board[63]
        game.board[63] = "."
    elseif m.isCastle == "q" then
        game.board[59] = game.board[56]
        game.board[56] = "."
    end

    -- Promotion
    if m.promo then
        local pChar = isWhite and m.promo:upper() or m.promo:lower()
        game.board[toSq] = pChar
    else
        game.board[toSq] = piece
    end

    -- Update Castling rights
    if piece == "K" then
        game.castling.K = false
        game.castling.Q = false
    elseif piece == "k" then
        game.castling.k = false
        game.castling.q = false
    elseif piece == "R" then
        if fromSq == 0 then game.castling.Q = false end
        if fromSq == 7 then game.castling.K = false end
    elseif piece == "r" then
        if fromSq == 56 then game.castling.q = false end
        if fromSq == 63 then game.castling.k = false end
    end

    -- If rook captured on home square
    if toSq == 0 then game.castling.Q = false
    elseif toSq == 7 then game.castling.K = false
    elseif toSq == 56 then game.castling.q = false
    elseif toSq == 63 then game.castling.k = false
    end

    -- Update en passant target
    if (piece == "P" or piece == "p") and math.abs(toSq - fromSq) == 16 then
        game.ep = isWhite and (fromSq + 8) or (fromSq - 8)
    else
        game.ep = -1
    end

    -- Halfmove clock
    if piece == "P" or piece == "p" or captured ~= "." then
        game.halfmove = 0
    else
        game.halfmove = game.halfmove + 1
    end

    if game.turn == "b" then
        game.fullmove = game.fullmove + 1
        game.turn = "w"
    else
        game.turn = "b"
    end

    return undo
end

-- Undo move (internal)
local function undoMoveInternal(game, undo)
    local fromSq, toSq = undo.from, undo.to
    game.board[fromSq] = undo.piece
    game.board[toSq] = undo.captured

    if undo.isEp and undo.epCapturedSq >= 0 then
        game.board[undo.epCapturedSq] = undo.epCapturedPiece
    end

    if undo.isCastle == "K" then
        game.board[7] = game.board[5]
        game.board[5] = "."
    elseif undo.isCastle == "Q" then
        game.board[0] = game.board[3]
        game.board[3] = "."
    elseif undo.isCastle == "k" then
        game.board[63] = game.board[61]
        game.board[61] = "."
    elseif undo.isCastle == "q" then
        game.board[56] = game.board[59]
        game.board[59] = "."
    end

    game.castling.K = undo.castlingK
    game.castling.Q = undo.castlingQ
    game.castling.k = undo.castlingk
    game.castling.q = undo.castlingq
    game.ep = undo.ep
    game.halfmove = undo.halfmove

    if game.turn == "w" then
        game.turn = "b"
        game.fullmove = game.fullmove - 1
    else
        game.turn = "w"
    end
end

-- Get all legal moves for current player (or for a specific square)
function Engine.getLegalMoves(game, fromSq)
    local pseudoMoves = {}
    local turn = game.turn

    if fromSq ~= nil then
        local p = game.board[fromSq]
        if Engine.isColorPiece(p, turn) then
            generatePieceMoves(game, fromSq, pseudoMoves)
        end
    else
        for sq = 0, 63 do
            local p = game.board[sq]
            if Engine.isColorPiece(p, turn) then
                generatePieceMoves(game, sq, pseudoMoves)
            end
        end
    end

    local legalMoves = {}
    local checkUndo = {}
    for _, m in ipairs(pseudoMoves) do
        local movingColor = turn
        local undo = applyMoveInternal(game, m, checkUndo)
        -- Check if moving side's king is left in check
        local inCheck = Engine.isInCheck(game.board, movingColor)
        undoMoveInternal(game, undo)
        if not inCheck then
            table.insert(legalMoves, m)
        end
    end

    return legalMoves
end

function Engine.isLegalMove(game, m)
    local legals = Engine.getLegalMoves(game, m.from)
    for _, lm in ipairs(legals) do
        if lm.from == m.from and lm.to == m.to then
            if not m.promo or (lm.promo and lm.promo:lower() == m.promo:lower()) then
                return true, lm
            end
        end
    end
    return false, nil
end

function Engine.makeMove(game, m)
    local isLegal, resolved = Engine.isLegalMove(game, m)
    if not isLegal then return false end
    local undo = applyMoveInternal(game, resolved)
    undo.uci = Engine.moveToUci(resolved)
    table.insert(game.history, undo)
    return true
end

function Engine.undoMove(game)
    if #game.history == 0 then return false end
    local undo = table.remove(game.history)
    undoMoveInternal(game, undo)
    return true
end

function Engine.getGameStatus(game)
    local legals = Engine.getLegalMoves(game)
    local inCheck = Engine.isInCheck(game.board, game.turn)

    if #legals == 0 then
        if inCheck then
            local winner = game.turn == "w" and "b" or "w"
            return true, winner, "checkmate"
        else
            return true, "draw", "stalemate"
        end
    end

    if game.halfmove >= 100 then
        return true, "draw", "50_moves"
    end

    -- Insufficient material check (K vs K, K+N vs K, K+B vs K)
    local pieces = {w = {}, b = {}}
    for sq = 0, 63 do
        local p = game.board[sq]
        if p ~= "." then
            local col = Engine.isWhitePiece(p) and "w" or "b"
            table.insert(pieces[col], p:upper())
        end
    end
    if #pieces.w == 1 and #pieces.b == 1 then
        return true, "draw", "insufficient_material"
    elseif (#pieces.w == 1 and #pieces.b == 2) or (#pieces.w == 2 and #pieces.b == 1) then
        local minorSide = #pieces.w == 2 and pieces.w or pieces.b
        for _, p in ipairs(minorSide) do
            if p == "N" or p == "B" then
                return true, "draw", "insufficient_material"
            end
        end
    end

    return false, nil, inCheck and "check" or "active"
end

-- Evaluation function: positive = White advantage, negative = Black advantage
function Engine.evaluate(game)
    local score = 0
    for sq = 0, 63 do
        local p = game.board[sq]
        if p ~= "." then
            local isWhite = Engine.isWhitePiece(p)
            local val = PIECE_VALUES[p] or 0

            local pstTable = PST[p]
            local pstVal = 0
            if pstTable then
                local pstIdx = isWhite and (sq + 1) or ((7 - math.floor(sq / 8)) * 8 + (sq % 8) + 1)
                pstVal = pstTable[pstIdx] or 0
            end

            if isWhite then
                score = score + val + pstVal
            else
                score = score - (val + pstVal)
            end
        end
    end
    return score
end

-- Move ordering score (captures & promotions first for alpha-beta cutoffs)
local function scoreMove(game, m)
    local victim = game.board[m.to]
    local aggressor = game.board[m.from]
    local s = 0
    if victim ~= "." then
        s = (PIECE_VALUES[victim] or 0) * 10 - (PIECE_VALUES[aggressor] or 0)
    end
    if m.promo then
        s = s + 900
    end
    return s
end

-- Reusable undo stack for minimax search to prevent allocations per node
local searchUndoStack = {}

-- Alpha-Beta Minimax search
local function minimax(game, depth, alpha, beta, isMaximizing)
    if depth <= 0 then
        return Engine.evaluate(game)
    end

    local legals = Engine.getLegalMoves(game)
    if #legals == 0 then
        if Engine.isInCheck(game.board, game.turn) then
            return isMaximizing and (-20000 - depth) or (20000 + depth)
        end
        return 0 -- Stalemate
    end

    -- Order moves
    table.sort(legals, function(a, b)
        return scoreMove(game, a) > scoreMove(game, b)
    end)

    searchUndoStack[depth] = searchUndoStack[depth] or {}
    local nodeUndo = searchUndoStack[depth]

    if isMaximizing then
        local maxEval = -100000
        for _, m in ipairs(legals) do
            applyMoveInternal(game, m, nodeUndo)
            local ev = minimax(game, depth - 1, alpha, beta, false)
            undoMoveInternal(game, nodeUndo)
            if ev > maxEval then maxEval = ev end
            if ev > alpha then alpha = ev end
            if beta <= alpha then break end
        end
        return maxEval
    else
        local minEval = 100000
        for _, m in ipairs(legals) do
            applyMoveInternal(game, m, nodeUndo)
            local ev = minimax(game, depth - 1, alpha, beta, true)
            undoMoveInternal(game, nodeUndo)
            if ev < minEval then minEval = ev end
            if ev < beta then beta = ev end
            if beta <= alpha then break end
        end
        return minEval
    end
end

-- Best move search for computer
-- difficulty: 1 = Easy (Depth 1 + candidate noise), 2 = Medium (Depth 2), 3 = Hard (Depth 3)
function Engine.getBestMove(game, difficulty)
    difficulty = difficulty or 2
    local depth = 2
    if difficulty == 1 then depth = 1
    elseif difficulty == 3 then depth = 3 end

    local legals = Engine.getLegalMoves(game)
    if #legals == 0 then return nil, 0 end
    if #legals == 1 then return Engine.moveToUci(legals[1]), 0 end

    -- Order moves
    table.sort(legals, function(a, b)
        return scoreMove(game, a) > scoreMove(game, b)
    end)

    local isMaximizing = (game.turn == "w")
    local bestMove = legals[1]
    local candidates = {}
    local alpha = -100000
    local beta = 100000
    local bestScore = isMaximizing and -100000 or 100000

    local rootUndo = {}
    if isMaximizing then
        for _, m in ipairs(legals) do
            applyMoveInternal(game, m, rootUndo)
            local score = minimax(game, depth - 1, alpha, beta, false)
            undoMoveInternal(game, rootUndo)

            table.insert(candidates, {move = m, score = score})
            if score > bestScore then
                bestScore = score
                bestMove = m
            end
            if score > alpha then alpha = score end
        end
    else
        for _, m in ipairs(legals) do
            applyMoveInternal(game, m, rootUndo)
            local score = minimax(game, depth - 1, alpha, beta, true)
            undoMoveInternal(game, rootUndo)

            table.insert(candidates, {move = m, score = score})
            if score < bestScore then
                bestScore = score
                bestMove = m
            end
            if score < beta then beta = score end
        end
    end

    -- Easy difficulty: inject controlled candidate variety within 40 centipawns
    if difficulty == 1 and #candidates > 1 then
        local threshold = 40
        local topCandidates = {}
        if isMaximizing then
            local maxScore = bestScore
            for _, c in ipairs(candidates) do
                if c.score >= maxScore - threshold then
                    table.insert(topCandidates, c.move)
                end
            end
        else
            local minScore = bestScore
            for _, c in ipairs(candidates) do
                if c.score <= minScore + threshold then
                    table.insert(topCandidates, c.move)
                end
            end
        end
        if #topCandidates > 0 then
            local seed = (crosspoint and crosspoint.millis and crosspoint.millis()) or (os.time() and os.time() * 1000) or 12345
            math.randomseed(seed + #game.history * 17)
            bestMove = topCandidates[math.random(#topCandidates)]
        end
    end

    return Engine.moveToUci(bestMove)
end

return Engine
