local status, roslyn = pcall(require, "roslyn")
if not status then
    return
end

roslyn.setup({
    exe = {
        "dotnet",
        vim.fn.stdpath("data") .. "/mason/packages/roslyn/libexec/Microsoft.CodeAnalysis.LanguageServer.dll",
    },
    -- Das Plugin sucht standardmäßig nach .sln und .csproj Dateien
    config = {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
        settings = {
            ["csharp|solution"] = {
                include_installed_runtime_extensions = true,
            },
        },
    },
})

