--- lf.yazi: make yazi look like lf with its default settings.
--
--   user@host:~/some/dir/file          <- promptfmt
--    parent  current       preview     <- ratios 1:2:3, one blank column between panes
--   -rw-r--r-- 1 user group 4.2K ...   1/42  <- ruler.default
--
-- Usage, in ~/.config/yazi/init.lua:
--
--   require("lf"):setup()
--   require("lf"):setup { ratio = { 1, 2, 3 } }  -- optional, lf's `set ratios`

local USER = ya.user_name and ya.user_name() or os.getenv("USER") or ""
local HOST = ya.host_name and ya.host_name() or ""

-- lf's promptfmt: "\033[32;1m%u@%h\033[0m:\033[34;1m%d\033[0m\033[1m%f\033[0m"
local PROMPT_HOST = ui.Style():fg("green"):bold()
local PROMPT_PATH = ui.Style():fg("blue"):bold()
local PROMPT_FILE = ui.Style():bold()
-- lf's cursoractivefmt/cursorparentfmt "\033[7m" and cursorpreviewfmt "\033[4m"
local CURSOR = ui.Style():reverse()
local CURSOR_PREVIEW = ui.Style():underline()
-- lf's selectfmt "\033[7;35m", copyfmt "\033[7;33m", cutfmt "\033[7;31m", visualfmt "\033[7;36m"
local SELECT = ui.Style():fg("magenta")
local COPY = ui.Style():fg("yellow")
local CUT = ui.Style():fg("red")
local VISUAL = ui.Style():fg("cyan")
-- lf's ruler.default uses "\033[36m" for permissions and "\033[7;34m" for the filter
local RULER_PERM = ui.Style():fg("cyan")
local RULER_FILTER = ui.Style():fg("blue"):reverse()

-- Same rounding as lf's humanize() with binary units
local function humanize(size)
	if size < 1024 then
		return string.format("%dB", size)
	end
	local curr = size / 1024
	for _, prefix in ipairs({ "K", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q" }) do
		if curr < 99.95 then
			return string.format("%.1f%s", curr, prefix)
		elseif curr < 1023.5 then
			return string.format("%.0f%s", curr, prefix)
		end
		curr = curr / 1024
	end
	return "+999Q"
end

local function chip(s, style)
	return ui.Line({ "  ", ui.Span(" " .. s .. " "):style(style) })
end

-- File colors: lf's built-in dircolors, then $LS_COLORS, then $LF_COLORS

local COLORS = {
	[0] = "black",
	"red",
	"green",
	"yellow",
	"blue",
	"magenta",
	"cyan",
	"gray",
	"darkgray",
	"lightred",
	"lightgreen",
	"lightyellow",
	"lightblue",
	"lightmagenta",
	"lightcyan",
	"white",
}

local function sgr_color(toks, i)
	if toks[i] == "5" and tonumber(toks[i + 1]) then
		local n = tonumber(toks[i + 1])
		return COLORS[n] or tostring(n), 2
	elseif toks[i] == "2" and tonumber(toks[i + 3]) then
		return string.format("#%02x%02x%02x", toks[i + 1], toks[i + 2], toks[i + 3]), 4
	end
end

-- Same codes as lf's applySGR()
local function sgr_style(s)
	local toks, a = {}, {}
	for t in (s .. ";"):gmatch("([^;]*);") do
		toks[#toks + 1] = t
	end

	local i = 1
	while i <= #toks do
		local t = toks[i]:gsub("^0+", "")
		local n = tonumber(t)
		if t == "" then
			a = {}
		elseif t == "1" then
			a.bold = true
		elseif t == "2" then
			a.dim = true
		elseif t == "3" then
			a.italic = true
		elseif t == "4" or t:match("^4:[1-5]$") then
			a.underline = true
		elseif t == "4:0" or t == "24" then
			a.underline = nil
		elseif t == "5" or t == "6" then
			a.blink = true
		elseif t == "7" then
			a.reverse = true
		elseif t == "8" then
			a.fg = a.bg
		elseif t == "9" then
			a.crossed = true
		elseif t == "22" then
			a.bold, a.dim = nil, nil
		elseif t == "23" then
			a.italic = nil
		elseif t == "25" then
			a.blink = nil
		elseif t == "27" then
			a.reverse = nil
		elseif t == "29" then
			a.crossed = nil
		elseif n and n >= 30 and n <= 37 then
			a.fg = COLORS[n - 30]
		elseif n and n >= 90 and n <= 97 then
			a.fg = COLORS[n - 82]
		elseif n and n >= 40 and n <= 47 then
			a.bg = COLORS[n - 40]
		elseif n and n >= 100 and n <= 107 then
			a.bg = COLORS[n - 92]
		elseif t == "38" or t == "48" or t == "58" then
			local color, offset = sgr_color(toks, i + 1)
			if not color then
				break
			end
			if t == "38" then
				a.fg = color
			elseif t == "48" then
				a.bg = color
			end
			i = i + offset
		end
		i = i + 1
	end

	local st = ui.Style()
	st = a.fg and st:fg(a.fg) or st
	st = a.bg and st:bg(a.bg) or st
	for _, attr in ipairs({ "bold", "dim", "italic", "underline", "blink", "reverse", "crossed" }) do
		st = a[attr] and st[attr](st) or st
	end
	return st
end

local LS = { styles = {} }

function LS:parse(env)
	for entry in (env or ""):gmatch("[^:]+") do
		local key, val = entry:match("^([^=]*)=([^=]*)$")
		if key then
			key = key:gsub("^~", os.getenv("HOME") or "~")
			self.target = self.target or (key == "ln" and val == "target")
			self.styles[key] = sgr_style(val)
		end
	end
end

LS:parse(
	"fi=00:di=01;34:ln=01;36:pi=33:so=01;35:bd=33;01:cd=33;01:or=31;01:su=01;32:sg=01;32:tw=01;34:ow=01;34:st=01;34:ex=01;32"
)
LS:parse(os.getenv("LS_COLORS"))
LS:parse(os.getenv("LF_COLORS"))

-- Same lookup order as lf's styleMap.get()
function LS:get(file)
	local s, cha, name = self.styles, file.cha, file.name
	local st = s[tostring(file.url)] or (cha.is_dir and s[name .. "/"])
	if st then
		return st
	end

	local mode, key = cha.mode or 0, nil
	if cha.is_orphan then
		key = "or"
	elseif cha.is_link and not self.target then
		key = "ln"
	elseif cha.is_dir then
		local sticky, other = cha.is_sticky, mode & 2 ~= 0
		key = sticky and other and "tw" or other and "ow" or sticky and "st" or "di"
	elseif cha.is_fifo then
		key = "pi"
	elseif cha.is_sock then
		key = "so"
	elseif cha.is_char then
		key = "cd"
	elseif cha.is_block then
		key = "bd"
	elseif mode & 0x800 ~= 0 then
		key = "su"
	elseif mode & 0x400 ~= 0 then
		key = "sg"
	elseif cha.is_exec then
		key = "ex"
	end
	if key and s[key] then
		return s[key]
	end

	local ext = ""
	if not cha.is_dir and not name:match("^%.[^.]*$") then
		ext = name:match("(%.[^.]*)$") or ""
	end
	return s[name .. "*"] or s["*" .. name] or s[name .. ".*"] or s["*" .. ext:lower()] or s.fi or ui.Style()
end

local M = {}

function M:setup(opts)
	opts = opts or {}
	rt.mgr.ratio = opts.ratio or { 1, 2, 3 }

	-- Tab: lf's getWidths(), panes separated by a single blank column, no rails

	function Tab:layout()
		local a, r = self._area, rt.mgr.ratio
		local n, rtot = 0, 0
		for i = 1, 3 do
			if r[i] > 0 then
				n, rtot = n + 1, rtot + r[i]
			end
		end

		local wtot = math.max(0, a.w - math.max(0, n - 1))
		local x, rsum, wsum = a.x, 0, 0
		self._chunks = {}
		for i = 1, 3 do
			local w = 0
			if r[i] > 0 then
				rsum = rsum + r[i]
				w = (wtot * rsum + rtot // 2) // rtot - wsum
				wsum = wsum + w
			end
			self._chunks[i] = ui.Rect({ x = x, y = a.y, w = w, h = a.h })
			if w > 0 then
				x = x + w + 1
			end
		end
	end

	function Tab:build()
		local c = self._chunks
		-- Column 0 of each pane is the marker column
		self._children = {
			Parent:new(c[1]:pad(ui.Pad(0, 0, 0, 1)), self._tab),
			Current:new(c[2]:pad(ui.Pad(0, 0, 0, 1)), self._tab),
			Preview:new(c[3]:pad(ui.Pad(0, 0, 0, 1)), self._tab),
			Markers:new(c, self._tab),
		}
	end

	-- Entries: tag column, name, no icons, "~" as truncatechar

	function Entity:style()
		local s = LS:get(self._file)
		if not self._file.is_hovered then
			return s
		elseif self._file.in_current then
			return s:patch(CURSOR)
		elseif self._file.in_preview then
			return s:patch(CURSOR_PREVIEW)
		else
			return s:patch(CURSOR)
		end
	end

	function Entity:padding()
		return " "
	end

	function Entity:icon()
		return ""
	end

	local ellipsis = Entity.ellipsis
	function Entity:ellipsis(max)
		local e = ellipsis(self, max)
		return e and "~" .. e:sub(#"…" + 1) or "~"
	end

	function Linemode:padding()
		return " "
	end

	function Entity:symlink()
		return ""
	end

	-- Markers: a single colored cell in the pane's first column
	local function cell(style)
		return style:bg(style:fg())
	end
	function Marker:style(file)
		local marked = file:is_marked()
		if marked == 1 then
			return cell(VISUAL)
		elseif marked == 0 and file:is_selected() then
			return cell(SELECT)
		end

		local yanked = file:is_yanked()
		if yanked == 1 then
			return cell(COPY)
		elseif yanked == 2 then
			return cell(CUT)
		end
	end

	-- Tabs: lf has none, so keep them plain
	function Tabs:redraw()
		if self.height() < 1 then
			return {}
		end

		local spans, pos = {}, 0
		local max = math.floor(self._area.w / #cx.tabs)
		for i = 1, #cx.tabs do
			local name = ui.truncate(string.format(" %d %s ", i, cx.tabs[i].name), { max = max })
			spans[i] = ui.Span(name):style(i == cx.tabs.idx and CURSOR or ui.Style())
			self._offsets[i], pos = pos, pos + ui.width(name)
		end
		return ui.Line(spans):area(self._area)
	end

	function Current:empty()
		local s
		if self._folder.files.filter then
			s = "empty"
		else
			local done, err = self._folder.stage()
			if not done then
				s = "loading..."
			elseif not err then
				s = "empty"
			elseif tostring(err):find("ermission") then
				s = "permission denied"
			else
				s = tostring(err)
			end
		end

		return {
			ui.Line(ui.Span(s):reverse()):area(self._area),
			table.unpack(Dnd:new(self._area):redraw()),
		}
	end

	-- Header: lf's prompt line

	Header._right = {}

	function Header:cwd()
		local max = self._area.w
		if max <= 0 then
			return ""
		end

		local h = self._current.hovered
		local host = USER .. "@" .. HOST
		local file = h and ui.printable(h.name) or ""
		local path = ya.readable_path(tostring(self._current.cwd))

		-- Like lf, shorten leading path components to their first letter until it fits
		local fixed = ui.width(host) + 1 + ui.width(file)
		if fixed + ui.width(path) > max then
			local names = {}
			for s in (path .. "/"):gmatch("(.-)/") do
				names[#names + 1] = s
			end
			for i, s in ipairs(names) do
				if s ~= "" then
					names[i] = s:match("^[%z\1-\127\194-\244][\128-\191]*")
					if fixed + ui.width(table.concat(names, "/")) <= max then
						break
					end
				end
			end
			path = table.concat(names, "/")
		end
		if path:sub(-1) ~= "/" then
			path = path .. "/"
		end

		return ui.Line({
			ui.Span(host):style(PROMPT_HOST),
			":",
			ui.Span(path):style(PROMPT_PATH),
			ui.Span(file):style(PROMPT_FILE),
		})
	end

	-- Status: lf's ruler.default, file stat on the left, counters on the right

	Status._left = {
		{ "stat", id = 1, order = 1000 },
	}
	Status._right = {
		{ "progress", id = 2, order = 1000 },
		{ "counts", id = 3, order = 2000 },
		{ "filters", id = 4, order = 3000 },
		{ "position", id = 5, order = 4000 },
	}

	function Status:stat()
		local h = self._current.hovered
		if not h then
			return ""
		end

		local cha = h.cha
		local spans = { ui.Span(cha:perm() or ""):style(RULER_PERM) }
		if cha.nlink and cha.nlink > 0 then
			spans[#spans + 1] = " " .. cha.nlink
		end
		if ya.user_name and cha.uid then
			spans[#spans + 1] = " " .. (ya.user_name(cha.uid) or cha.uid)
		end
		if ya.group_name and cha.gid then
			spans[#spans + 1] = " " .. (ya.group_name(cha.gid) or cha.gid)
		end
		spans[#spans + 1] = string.format(" %5s", humanize(cha.len or 0))
		if cha.mtime then
			spans[#spans + 1] = " " .. os.date("%a %b %e %H:%M:%S %Y", math.floor(cha.mtime))
		end
		if h.link_to then
			spans[#spans + 1] = " -> " .. ui.printable(tostring(h.link_to))
		end
		return ui.Line(spans)
	end

	function Status:progress()
		local summary = cx.tasks.summary
		if summary.total == 0 then
			return ""
		elseif summary.percent then
			return string.format("  [%d%%]", math.floor(summary.percent))
		else
			return string.format("  [%d/%d]", summary.success, summary.total)
		end
	end

	function Status:counts()
		local lines = {}

		local yanked = #cx.yanked
		if yanked > 0 then
			lines[#lines + 1] = chip(yanked, (cx.yanked.is_cut and CUT or COPY):reverse())
		end

		local selected = #self._tab.selected
		if selected > 0 then
			lines[#lines + 1] = chip(selected, SELECT:reverse())
		end

		local mode = self._tab.mode
		if mode.is_select or mode.is_unset then
			local files, visual = self._current.files, 0
			for i = 1, #files do
				if files[i]:is_marked() ~= 0 then
					visual = visual + 1
				end
			end
			if visual > 0 then
				lines[#lines + 1] = chip(visual, VISUAL:reverse())
			end
		end

		return ui.Line(lines)
	end

	function Status:filters()
		local lines = {}
		local cwd, filter, finder = self._current.cwd, self._current.files.filter, self._tab.finder
		if cwd.spec.is_search then
			lines[#lines + 1] = chip("search: " .. cwd.spec.domain, RULER_FILTER)
		end
		if filter then
			lines[#lines + 1] = chip(tostring(filter), RULER_FILTER)
		end
		if finder then
			lines[#lines + 1] = chip("find: " .. tostring(finder), RULER_FILTER)
		end
		return ui.Line(lines)
	end

	function Status:position()
		local length = #self._current.files
		return string.format("  %d/%d", math.min(self._current.cursor + 1, length), length)
	end

	function Status:redraw()
		return {
			ui.Line(self:children_redraw(self.LEFT)):area(self._area),
			ui.Line(self:children_redraw(self.RIGHT)):area(self._area):align(ui.Align.RIGHT),
		}
	end
end

return M
