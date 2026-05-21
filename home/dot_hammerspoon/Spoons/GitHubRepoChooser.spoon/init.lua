--- GitHubRepoChooser.spoon
--- Search and open GitHub repositories via hs.chooser

local obj = {}
obj.__index = obj

obj.name = "GitHubRepoChooser"
obj.version = "1.0"
obj.author = "jack.jennings"

obj.hotkey = nil
obj.chooser = nil
obj._repos = {}
obj._loading = false

local GH_PATH = "/opt/homebrew/bin/gh"

local function getAccounts(callback)
  hs.task.new(GH_PATH, function(code, stdout, stderr)
    if code ~= 0 then
      hs.notify.new({title="GitHubRepoChooser", informativeText="Failed to list accounts: " .. stderr}):send()
      callback({})
      return
    end
    local data = hs.json.decode(stdout)
    local accounts = {}
    if data and data.hosts then
      for host, entries in pairs(data.hosts) do
        for _, entry in ipairs(entries) do
          if entry.state == "success" then
            table.insert(accounts, {host = host, login = entry.login})
          end
        end
      end
    end
    callback(accounts)
  end, {"auth", "status", "--json", "hosts"}):start()
end

local function getToken(login, callback)
  hs.task.new(GH_PATH, function(code, stdout, stderr)
    if code == 0 then
      callback(stdout:match("^%s*(.-)%s*$"))
    else
      hs.notify.new({title="GitHubRepoChooser", informativeText="Failed to get token for " .. login .. ": " .. stderr}):send()
      callback(nil)
    end
  end, {"auth", "token", "--user", login}):start()
end

local function fetchRepos(token, callback)
  local results = {}
  local page = 1
  local perPage = 100

  local function fetchPage()
    local url = string.format(
      "https://api.github.com/user/repos?per_page=%d&page=%d&sort=updated&affiliation=owner,collaborator,organization_member",
      perPage, page
    )
    hs.http.asyncGet(url, {
      ["Authorization"] = "Bearer " .. token,
      ["Accept"] = "application/vnd.github+json",
      ["X-GitHub-Api-Version"] = "2022-11-28",
    }, function(status, body, _headers)
      if status ~= 200 then
        hs.notify.new({title="GitHubRepoChooser", informativeText="GitHub API error: " .. tostring(status)}):send()
        callback(results)
        return
      end

      local data = hs.json.decode(body)
      if not data or #data == 0 then
        callback(results)
        return
      end

      for _, repo in ipairs(data) do
        table.insert(results, {
          text = repo.full_name,
          subText = repo.description or "",
          url = repo.html_url,
          private = repo.private,
        })
      end

      if #data == perPage then
        page = page + 1
        fetchPage()
      else
        callback(results)
      end
    end)
  end

  fetchPage()
end

local function fetchAllRepos(accounts, callback)
  local allResults = {}
  local seen = {}
  local pending = #accounts

  local function onReposFetched(repos)
    for _, repo in ipairs(repos) do
      if not seen[repo.url] then
        seen[repo.url] = true
        table.insert(allResults, repo)
      end
    end
    pending = pending - 1
    if pending == 0 then
      callback(allResults)
    end
  end

  for _, account in ipairs(accounts) do
    getToken(account.login, function(token)
      if token then
        fetchRepos(token, onReposFetched)
      else
        pending = pending - 1
        if pending == 0 then
          callback(allResults)
        end
      end
    end)
  end
end

local iconColor = {red = 0xDD/255, green = 0x7B/255, blue = 0xDC/255, alpha = 1.0}

local function coloredIcon(imageName)
  -- Disable template so the image retains its native alpha (dark pixels on transparent bg),
  -- then overlay target color with sourceAtop to tint only opaque pixels.
  -- Canvas is 36×36 (the chooser's slot size) with the icon centered at 20×20,
  -- so the rendered icon is smaller than the full slot.
  local slotSize  = 36
  local iconSize  = 20
  local padding   = (slotSize - iconSize) / 2
  local iconFrame = {x = padding, y = padding, w = iconSize, h = iconSize}

  local img = hs.image.imageFromName(imageName)
  img:template(false)

  local canvas = hs.canvas.new({x=0, y=0, w=slotSize, h=slotSize})
  canvas:appendElements(
    { type = "image",     image = img, imageScaling = "scaleToFit", frame = iconFrame },
    { type = "rectangle", action = "fill", fillColor = iconColor,
      frame = iconFrame, compositeRule = "sourceAtop" }
  )
  local result = canvas:imageFromCanvas()
  canvas:delete()
  return result
end

local function repoToChoice(repo)
  local imageName = repo.private and "NSLockLockedTemplate" or "NSLockUnlockedTemplate"
  return {
    text    = repo.text,
    subText = repo.subText,
    url     = repo.url,
    image   = coloredIcon(imageName),
  }
end

local function repoName(fullName)
  return fullName:match("/(.+)$") or fullName
end

local function sortedChoices(repos, query)
  if not query or query == "" then
    return hs.fnutils.map(repos, repoToChoice)
  end

  local q = query:lower()
  local nameMatches, otherMatches = {}, {}

  for _, repo in ipairs(repos) do
    local name = repoName(repo.text):lower()
    local full = repo.text:lower()
    local desc = repo.subText:lower()
    if name:find(q, 1, true) then
      table.insert(nameMatches, repoToChoice(repo))
    elseif full:find(q, 1, true) or desc:find(q, 1, true) then
      table.insert(otherMatches, repoToChoice(repo))
    end
  end

  local results = {}
  for _, c in ipairs(nameMatches) do table.insert(results, c) end
  for _, c in ipairs(otherMatches) do table.insert(results, c) end
  return results
end

function obj:_showChooser()
  if not self.chooser then return end

  if #self._repos > 0 then
    self.chooser:show()
    return
  end

  self.chooser:choices({})
  self.chooser:placeholderText("Loading repositories…")
  self.chooser:show()

  if self._loading then return end
  self._loading = true

  getAccounts(function(accounts)
    if #accounts == 0 then
      self._loading = false
      hs.notify.new({title="GitHubRepoChooser", informativeText="No authenticated GitHub accounts found"}):send()
      return
    end

    fetchAllRepos(accounts, function(repos)
      self._loading = false
      self._repos = repos
      self.chooser:choices(function(query)
        return sortedChoices(self._repos, query)
      end)
      self.chooser:placeholderText("Search GitHub repos…")
    end)
  end)
end

function obj:init()
  self.chooser = hs.chooser.new(function(choice)
    if choice and choice.url then
      hs.urlevent.openURL(choice.url)
    end
  end)

  self.chooser:choices(function(query)
    return sortedChoices(self._repos, query)
  end)
  self.chooser:placeholderText("Search GitHub repos…")
  self.chooser:fgColor({red = 0xDD/255, green = 0x7B/255, blue = 0xDC/255, alpha = 1.0})
  self.chooser:width(60)
  self.chooser:rows(12)

  return self
end

function obj:bindHotkeys(mapping)
  local spec = mapping or {show = {{"ctrl", "alt", "cmd"}, "space"}}
  if spec.show then
    local mods, key = table.unpack(spec.show)
    if self.hotkey then self.hotkey:delete() end
    self.hotkey = hs.hotkey.bind(mods, key, function() self:_showChooser() end)
  end
  return self
end

--- Clears the cached repo list, forcing a refresh on next open
function obj:refresh()
  self._repos = {}
end

return obj
