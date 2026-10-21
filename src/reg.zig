const std = @import("std");
const win = @import("win32.zig");
const c = @import("constants.zig");

pub fn readPortName(out: []u16) ?[]const u16 {
    const path = std.unicode.utf8ToUtf16LeStringLiteral(c.PORT_KEY_PATH);
    var hkey: win.HKEY = null;
    if (win.RegOpenKeyExW(win.HKEY_LOCAL_MACHINE, path, 0, win.KEY_READ, &hkey) != 0) return null;
    defer _ = win.RegCloseKey(hkey);
    const name = std.unicode.utf8ToUtf16LeStringLiteral("PortName");
    var size_bytes: u32 = @intCast(out.len * 2);
    if (win.RegQueryValueExW(hkey, name, null, null, @ptrCast(out.ptr), &size_bytes) != 0) return null;
    const units = size_bytes / 2;
    var n: usize = 0;
    while (n < units and out[n] != 0) : (n += 1) {}
    if (n == 0) return null;
    return out[0..n];
}

pub fn ensurePortKey() ?win.HKEY {
    const path = std.unicode.utf8ToUtf16LeStringLiteral(c.PORT_KEY_PATH);
    var hkey: win.HKEY = null;
    if (win.RegOpenKeyExW(win.HKEY_LOCAL_MACHINE, path, 0, win.KEY_READ | win.KEY_WRITE, &hkey) != 0) {
        var disposition: u32 = 0;
        if (win.RegCreateKeyExW(win.HKEY_LOCAL_MACHINE, path, 0, null, win.REG_OPTION_NON_VOLATILE, win.KEY_READ | win.KEY_WRITE, null, &hkey, &disposition) != 0) return null;
    }
    ensurePortNameValue(hkey);
    return hkey;
}

fn ensurePortNameValue(hkey: win.HKEY) void {
    const name = std.unicode.utf8ToUtf16LeStringLiteral("PortName");
    var buf: [64]u8 = undefined;
    var size: u32 = buf.len;
    if (win.RegQueryValueExW(hkey, name, null, null, &buf, &size) == 0 and size >= 2) return;
    const value = std.unicode.utf8ToUtf16LeStringLiteral(c.PORT_NAME);
    _ = win.RegSetValueExW(hkey, name, 0, win.REG_SZ, @ptrCast(value), @intCast(value.len * 2 + 2));
}

/// 确保 HKLM\HARDWARE\DEVICEMAP\SERIALCOMM 中登记了接收器的端口名。
/// 应用会轮询该键，只接受其中列出的 COM 口；Wine 手动映射的端口不会被 mountmgr 登记。
/// HARDWARE 为易失键，子键必须以 REG_OPTION_VOLATILE 创建，会话结束后自动消失。
pub fn ensureSerialComm() bool {
    var port_buf: [64]u16 = undefined;
    const port: []const u16 = readPortName(port_buf[0..]) orelse std.unicode.utf8ToUtf16LeStringLiteral(c.PORT_NAME);
    var value: [65]u16 = undefined;
    @memcpy(value[0..port.len], port);
    value[port.len] = 0;

    const path = std.unicode.utf8ToUtf16LeStringLiteral(c.SERIALCOMM_PATH);
    var hkey: win.HKEY = null;
    var disposition: u32 = 0;
    if (win.RegCreateKeyExW(win.HKEY_LOCAL_MACHINE, path, 0, null, win.REG_OPTION_VOLATILE, win.KEY_SET_VALUE | win.KEY_WOW64_64KEY, null, &hkey, &disposition) != 0) return false;
    defer _ = win.RegCloseKey(hkey);
    const name = std.unicode.utf8ToUtf16LeStringLiteral(c.SERIALCOMM_VALUE);
    return win.RegSetValueExW(hkey, name, 0, win.REG_SZ, @ptrCast(&value), @intCast(port.len * 2 + 2)) == 0;
}
