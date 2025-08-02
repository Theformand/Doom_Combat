::robocopy "resources\shaders" "bin\resources\shaders" /E /NFL /NDL /NJH /NJS
odin run . -debug -subsystem:windows
