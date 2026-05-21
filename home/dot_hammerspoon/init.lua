require("hs.ipc")

hs.loadSpoon("HyperKey")
spoon.HyperKey:init():start()

hs.loadSpoon("ShiftIt")

spoon.ShiftIt:bindHotkeys({})

hs.loadSpoon("GitHubRepoChooser")

spoon.GitHubRepoChooser:init()
spoon.GitHubRepoChooser:bindHotkeys({
  show = {{"ctrl", "alt", "shift", "cmd"}, "space"}
})
