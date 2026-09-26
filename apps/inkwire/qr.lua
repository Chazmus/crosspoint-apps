-- QR code rendering module for InkWire
-- Uses native firmware / simulator C++ binding gfx.drawQrCode
local qr = {}

function qr.draw(x, y, w, h, text)
    if not text or text == "" then return end
    if gfx and gfx.drawQrCode then
        gfx.drawQrCode(x, y, w, h, text)
    end
end

return qr
