hs.loadSpoon("ShiftIt")

spoon.ShiftIt:bindHotkeys({})

hs.loadSpoon("GitHubRepoChooser")

spoon.GitHubRepoChooser:init()
spoon.GitHubRepoChooser:bindHotkeys({
  show = {{"ctrl", "alt", "cmd"}, "space"}
})
